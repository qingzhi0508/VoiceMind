import Foundation
import SharedCore
import CryptoKit

protocol ConnectionManagerDelegate: AnyObject {
    func connectionManager(_ manager: ConnectionManager, didChangePairingState state: PairingState)
    func connectionManager(_ manager: ConnectionManager, didChangeConnectionState state: ConnectionState)
    func connectionManager(_ manager: ConnectionManager, didUpdatePairingProgress message: String?)
    func connectionManager(
        _ manager: ConnectionManager,
        didRecordInboundEvent title: String,
        detail: String,
        category: InboundDataCategory,
        severity: InboundDataSeverity
    )
    func connectionManager(_ manager: ConnectionManager, didReceiveMessage envelope: MessageEnvelope)
}

class ConnectionManager: NSObject {
    static let keychainServiceName = "com.voicemind.mac"

    // MARK: - Rate Limiting Constants
    private struct RateLimitConfig {
        static let maxAttempts = 5              // 最大失败尝试次数
        static let windowSeconds: TimeInterval = 60      // 时间窗口（秒）
        static let cooldownSeconds: TimeInterval = 300    // 被锁定后的冷却时间（5分钟）
    }

    // MARK: - Rate Limiting State
    private var failedPairingAttempts: [String: [Date]] = [:]  // clientId -> 失败时间列表
    private var rateLimitedClients: [String: Date] = [:]        // clientId -> 锁定到期时间

    weak var delegate: ConnectionManagerDelegate?

    let server = WebSocketServer()
    var hmacValidator: HMACValidator?

    private let keychainService = ConnectionManager.keychainServiceName
    private let keychainAccount = "pairing"
    let deviceId = UUID().uuidString

    private(set) var pairingState: PairingState = .unpaired {
        didSet {
            delegate?.connectionManager(self, didChangePairingState: pairingState)
        }
    }

    private(set) var connectionState: ConnectionState = .disconnected

    private var pairingTimer: Timer?
    private(set) var pairingProgressMessage: String? {
        didSet {
            delegate?.connectionManager(self, didUpdatePairingProgress: pairingProgressMessage)
        }
    }

    // 语音识别管理器
    private let speechManager = SpeechRecognitionManager.shared
    private let remoteMicrophoneMonitorController = RemoteMicrophoneMonitorController()

    // 当前会话 ID（用于匹配识别结果）
    private var currentSessionId: String?

    override init() {
        super.init()
        server.delegate = self
        loadPairing()

        // 监听引擎切换通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEngineChange(_:)),
            name: .speechEngineDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleEngineChange(_ notification: Notification) {
        setupSpeechRecognition()
    }

    func start(port: UInt16) throws {
        // WebSocketServer now handles both TCP server and Bonjour advertising
        try server.start(port: port)
        print("✅ Connection manager started on port \(server.port)")
    }

    func stop() {
        remoteMicrophoneMonitorController.stopSession(sessionId: nil)
        server.stop()
        print("🛑 Connection manager stopped")
    }

    // MARK: - Rate Limiting Methods

    /// 检查客户端是否被锁定
    private func isClientRateLimited(_ clientId: String) -> Bool {
        if let cooldownEnd = rateLimitedClients[clientId] {
            if Date() < cooldownEnd {
                print("🚫 客户端 \(clientId) 处于锁定状态，剩余 \(Int(cooldownEnd.timeIntervalSinceNow)) 秒")
                return true
            } else {
                // 冷却已结束，清除锁定状态
                rateLimitedClients.removeValue(forKey: clientId)
                failedPairingAttempts.removeValue(forKey: clientId)
                print("✅ 客户端 \(clientId) 锁定已解除")
            }
        }
        return false
    }

    /// 记录一次失败的配对尝试
    private func recordFailedAttempt(_ clientId: String) {
        let now = Date()

        // 获取该客户端的失败尝试记录
        var attempts = failedPairingAttempts[clientId] ?? []

        // 清除时间窗口外的旧记录
        attempts = attempts.filter { now.timeIntervalSince($0) < RateLimitConfig.windowSeconds }

        // 添加新的失败记录
        attempts.append(now)
        failedPairingAttempts[clientId] = attempts

        let attemptCount = attempts.count
        print("⚠️ 客户端 \(clientId) 失败尝试次数: \(attemptCount)/\(RateLimitConfig.maxAttempts)")

        // 检查是否达到限制
        if attemptCount >= RateLimitConfig.maxAttempts {
            rateLimitedClients[clientId] = now.addingTimeInterval(RateLimitConfig.cooldownSeconds)
            print("🔒 客户端 \(clientId) 因多次失败尝试已被锁定 \(RateLimitConfig.cooldownSeconds) 秒")

            recordInboundEvent(
                title: "配对被锁定",
                detail: "客户端 \(clientId) 因 \(attemptCount) 次失败尝试被锁定 \(Int(RateLimitConfig.cooldownSeconds)) 秒",
                category: .pairing,
                severity: .warning
            )
        }
    }

    /// 获取剩余锁定时间
    private func remainingCooldown(_ clientId: String) -> TimeInterval? {
        guard let cooldownEnd = rateLimitedClients[clientId] else { return nil }
        let remaining = cooldownEnd.timeIntervalSinceNow
        return remaining > 0 ? remaining : nil
    }

    func setupSpeechRecognition() {
        speechManager.currentEngine?.delegate = self
        print("✅ 语音识别代理已设置 - 引擎: \(speechManager.currentEngine?.displayName ?? "nil")")
    }

    func startPairing() -> String {
        // Generate 6-digit code
        let code = String(format: "%06d", Int.random(in: 0...999999))

        // Set pairing state with 2-minute expiration
        let expiresAt = Date().addingTimeInterval(120)
        pairingState = .pairing(code: code, expiresAt: expiresAt)

        // Start expiration timer
        pairingTimer?.invalidate()
        pairingTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: false) { [weak self] _ in
            self?.cancelPairing()
        }

        print("🔐 开始配对")
        print("   配对码: \(code)")
        print("   有效期: 2分钟")
        print("   过期时间: \(expiresAt)")
        updatePairingProgress("已生成配对码，等待手机扫描二维码或输入配对码。")

        return code
    }

    func cancelPairing() {
        pairingTimer?.invalidate()
        pairingTimer = nil

        if case .pairing = pairingState {
            pairingState = .unpaired
        }
        updatePairingProgress(nil)
    }

    func unpair() {
        try? KeychainManager.delete(service: keychainService, account: keychainAccount)
        hmacValidator = nil
        pairingState = .unpaired
        updatePairingProgress(nil)
    }

    func send(_ envelope: MessageEnvelope) {
        server.send(envelope)
    }

    private func loadPairing() {
        do {
            let pairing = try KeychainManager.retrievePairing(service: keychainService, account: keychainAccount)
            hmacValidator = HMACValidator(sharedSecret: pairing.sharedSecret)
            pairingState = .paired(deviceId: pairing.deviceId, deviceName: pairing.deviceName)
            updatePairingProgress("已完成配对，可直接连接并开始使用。")
        } catch {
            pairingState = .unpaired
            updatePairingProgress(nil)
        }
    }

    private func handlePairConfirm(_ payload: PairConfirmPayload) {
        let clientId = payload.iosId

        // 检查客户端是否被速率限制锁定
        if isClientRateLimited(clientId) {
            if let remaining = remainingCooldown(clientId) {
                print("🚫 配对被拒绝: 客户端 \(clientId) 已被临时锁定，剩余 \(Int(remaining)) 秒")
                updatePairingProgress("配对被拒绝：检测到异常行为，请 \(Int(remaining)) 秒后重试。")
                sendError(code: "rate_limited", message: "Too many failed attempts, please try again later")
            }
            return
        }

        print("📱 收到配对确认")
        print("   iOS 设备: \(payload.iosName)")
        print("   iOS ID: \(payload.iosId)")
        print("   配对码: \(payload.shortCode)")
        updatePairingProgress("已收到来自 \(payload.iosName) 的配对请求。")
        recordInboundEvent(
            title: "收到配对请求",
            detail: "设备: \(payload.iosName)\n设备 ID: \(payload.iosId)\n配对码: \(payload.shortCode)",
            category: .pairing
        )

        guard case .pairing(let code, _) = pairingState else {
            print("❌ 配对失败: 不在配对模式")
            updatePairingProgress("收到配对请求，但当前不在配对模式。")
            recordInboundEvent(
                title: "配对失败",
                detail: "收到配对请求，但当前不在配对模式。",
                category: .pairing,
                severity: .error
            )
            sendError(code: "not_pairing", message: "Not in pairing mode")
            return
        }

        guard payload.shortCode == code else {
            print("❌ 配对失败: 配对码不匹配")
            print("   期望: \(code)")
            print("   收到: \(payload.shortCode)")

            // 记录失败尝试，用于暴力破解检测
            recordFailedAttempt(clientId)

            // 检查是否因失败次数过多而被锁定
            if isClientRateLimited(clientId) {
                if let remaining = remainingCooldown(clientId) {
                    updatePairingProgress("配对被拒绝：失败次数过多，请 \(Int(remaining)) 秒后重试。")
                    sendError(code: "rate_limited", message: "Too many failed attempts")
                }
            } else {
                updatePairingProgress("配对码校验失败，已拒绝此次请求。")
                sendError(code: "invalid_code", message: "Invalid pairing code")
            }
            recordInboundEvent(
                title: "配对失败",
                detail: "配对码校验失败。\n期望: \(code)\n收到: \(payload.shortCode)",
                category: .pairing,
                severity: .error
            )
            return
        }

        print("✅ 配对码验证通过")
        updatePairingProgress("配对码校验通过，正在生成共享密钥。")

        // Generate shared secret
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let sharedSecret = Data(bytes).base64EncodedString()

        print("🔑 生成共享密钥")

        // Save pairing
        let pairing = PairingData(
            deviceId: payload.iosId,
            deviceName: payload.iosName,
            sharedSecret: sharedSecret
        )

        do {
            updatePairingProgress("正在保存配对信息。")
            try KeychainManager.savePairing(pairing, service: keychainService, account: keychainAccount)
            hmacValidator = HMACValidator(sharedSecret: sharedSecret)
            pairingState = .paired(deviceId: payload.iosId, deviceName: payload.iosName)

            // 配对成功，清除该客户端的失败尝试记录
            failedPairingAttempts.removeValue(forKey: clientId)
            rateLimitedClients.removeValue(forKey: clientId)

            print("💾 配对信息已保存到 Keychain")
            updatePairingProgress("配对信息已保存，正在向手机返回成功结果。")

            // Send success
            let successPayload = PairSuccessPayload(sharedSecret: sharedSecret)
            let payloadData = try JSONEncoder().encode(successPayload)
            let envelope = MessageEnvelope(
                type: .pairSuccess,
                payload: payloadData,
                timestamp: Date(),
                deviceId: deviceId,
                hmac: nil
            )
            server.send(envelope)

            print("📤 发送配对成功消息")
            print("✅ 配对完成: \(payload.iosName)")
            updatePairingProgress("已返回配对成功结果，\(payload.iosName) 现在可以开始使用。")

            pairingTimer?.invalidate()
            pairingTimer = nil
        } catch {
            print("❌ 保存配对信息失败: \(error)")
            updatePairingProgress("保存配对信息失败：\(error.localizedDescription)")
            recordInboundEvent(
                title: "保存配对信息失败",
                detail: error.localizedDescription,
                category: .pairing,
                severity: .error
            )
            sendError(code: "pairing_failed", message: "Failed to save pairing: \(error)")
        }
    }

    private func updatePairingProgress(_ message: String?) {
        pairingProgressMessage = message
    }

    private func sendError(code: String, message: String) {
        recordInboundEvent(
            title: "发送错误消息",
            detail: "错误码: \(code)\n消息: \(message)",
            category: .connection,
            severity: .error
        )
        let payload = ErrorPayload(code: code, message: message)
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }

        let envelope = MessageEnvelope(
            type: .error,
            payload: payloadData,
            timestamp: Date(),
            deviceId: deviceId,
            hmac: nil
        )
        server.send(envelope)
    }
}

extension ConnectionManager: WebSocketServerDelegate {
    func server(_ server: WebSocketServer, didReceiveMessage message: MessageEnvelope) {
        // Handle pairing messages without HMAC
        if message.type == .pairConfirm {
            guard let payload = try? JSONDecoder().decode(PairConfirmPayload.self, from: message.payload) else {
                sendError(code: "invalid_payload", message: "Invalid pairConfirm payload")
                return
            }
            handlePairConfirm(payload)
            return
        }

        // Validate HMAC for all other messages
        guard let validator = hmacValidator else {
            sendError(code: "not_paired", message: "Device not paired")
            return
        }

        guard validator.validateEnvelopeHMAC(message) else {
            sendError(code: "invalid_hmac", message: "HMAC validation failed")
            return
        }

        // Handle Ping message
        if message.type == .ping {
            handlePing(message)
            return
        }

        // Handle audio stream messages
        if message.type == .audioStart {
            handleAudioStart(message)
            return
        }

        if message.type == .audioData {
            handleAudioData(message)
            return
        }

        if message.type == .audioEnd {
            handleAudioEnd(message)
            return
        }

        // Forward validated message to delegate
        delegate?.connectionManager(self, didReceiveMessage: message)
    }

    func server(_ server: WebSocketServer, didChangeState state: ConnectionState) {
        connectionState = state
        if case .connected = state {
            // Keep any active relay until the stream itself ends.
        } else {
            remoteMicrophoneMonitorController.stopSession(sessionId: nil)
        }
        delegate?.connectionManager(self, didChangeConnectionState: state)
    }

    private func handlePing(_ message: MessageEnvelope) {
        print("💓 收到心跳 Ping")
        guard let payload = try? JSONDecoder().decode(PingPayload.self, from: message.payload) else {
            print("⚠️ 无法解析 Ping 消息")
            return
        }
        recordInboundEvent(
            title: "收到心跳",
            detail: "Nonce: \(payload.nonce)",
            category: .connection
        )

        // Send Pong response
        let pongPayload = PongPayload(nonce: payload.nonce)
        guard let pongData = try? JSONEncoder().encode(pongPayload) else {
            print("❌ 无法编码 Pong 消息")
            return
        }

        let timestamp = Date()
        let hmac = hmacValidator?.generateHMACForEnvelope(
            type: .pong,
            payload: pongData,
            timestamp: timestamp,
            deviceId: deviceId
        )

        let envelope = MessageEnvelope(
            type: .pong,
            payload: pongData,
            timestamp: timestamp,
            deviceId: deviceId,
            hmac: hmac
        )

        server.send(envelope)
        print("💚 发送心跳 Pong 响应")
    }

    // MARK: - Audio Stream Handling

    private func handleAudioStart(_ message: MessageEnvelope) {
        print("🎤 收到音频流开始消息")
        guard let payload = try? JSONDecoder().decode(AudioStartPayload.self, from: message.payload) else {
            print("❌ 无法解析 AudioStart 消息")
            return
        }

        print("   Session ID: \(payload.sessionId)")
        print("   语言: \(payload.language)")
        print("   采样率: \(payload.sampleRate) Hz")
        print("   通道数: \(payload.channels)")
        print("   格式: \(payload.format)")
        print("   播放到 Mac 喇叭: \(payload.playThroughMacSpeaker)")
        recordInboundEvent(
            title: "语音流开始",
            detail: "Session: \(payload.sessionId)\n语言: \(payload.language)\n采样率: \(payload.sampleRate) Hz\n通道数: \(payload.channels)\n格式: \(payload.format)\n喇叭播放: \(payload.playThroughMacSpeaker ? "开启" : "关闭")",
            category: .voice
        )

        do {
            try remoteMicrophoneMonitorController.startSession(
                sessionId: payload.sessionId,
                sampleRate: payload.sampleRate,
                channels: payload.channels,
                format: payload.format,
                playThroughMacSpeaker: payload.playThroughMacSpeaker
            )
        } catch {
            print("⚠️ 启动远端麦克风播放失败，已降级为仅识别: \(error)")
        }

        do {
            try speechManager.startRecognition(
                sessionId: payload.sessionId,
                language: payload.language
            )
            currentSessionId = payload.sessionId
            print("✅ 语音识别已启动")
        } catch {
            remoteMicrophoneMonitorController.stopSession(sessionId: payload.sessionId)
            print("❌ 启动语音识别失败: \(error.localizedDescription)")
            sendError(code: "recognition_start_failed", message: error.localizedDescription)
        }
    }

    private func handleAudioData(_ message: MessageEnvelope) {
        guard let payload = try? JSONDecoder().decode(AudioDataPayload.self, from: message.payload) else {
            print("❌ 无法解析 AudioData 消息")
            return
        }

        print("📥 收到音频数据: \(payload.audioData.count) 字节 (seq: \(payload.sequenceNumber))")
        recordInboundEvent(
            title: "语音数据包",
            detail: "Session: \(payload.sessionId)\n序号: \(payload.sequenceNumber)\n字节数: \(payload.audioData.count)",
            category: .voice
        )

        do {
            try speechManager.processAudioData(payload.audioData)
        } catch {
            print("❌ 处理音频数据失败: \(error.localizedDescription)")
            sendError(code: "audio_processing_failed", message: error.localizedDescription)
        }

        try? remoteMicrophoneMonitorController.appendAudio(
            payload.audioData,
            sessionId: payload.sessionId
        )
    }

    private func handleAudioEnd(_ message: MessageEnvelope) {
        print("🛑 收到音频流结束消息")
        guard let payload = try? JSONDecoder().decode(AudioEndPayload.self, from: message.payload) else {
            print("❌ 无法解析 AudioEnd 消息")
            return
        }

        print("   Session ID: \(payload.sessionId)")
        recordInboundEvent(
            title: "语音流结束",
            detail: "Session: \(payload.sessionId)",
            category: .voice
        )

        remoteMicrophoneMonitorController.stopSession(sessionId: payload.sessionId)

        do {
            try speechManager.stopRecognition()
            currentSessionId = nil
            print("✅ 语音识别已停止")
        } catch {
            print("❌ 停止语音识别失败: \(error.localizedDescription)")
            sendError(code: "recognition_stop_failed", message: error.localizedDescription)
        }
    }

    private func recordInboundEvent(
        title: String,
        detail: String,
        category: InboundDataCategory,
        severity: InboundDataSeverity = .info
    ) {
        delegate?.connectionManager(
            self,
            didRecordInboundEvent: title,
            detail: detail,
            category: category,
            severity: severity
        )
    }
}

// MARK: - SpeechRecognitionEngineDelegate

extension ConnectionManager: SpeechRecognitionEngineDelegate {
    func engine(
        _ engine: SpeechRecognitionEngine,
        didRecognizeText text: String,
        sessionId: String,
        language: String
    ) {
        print("📝 识别结果: \(text)")
        recordInboundEvent(
            title: "语音转文字结果",
            detail: "Session: \(sessionId)\n语言: \(language)\n内容: \(text)",
            category: .voice
        )

        // 将识别结果发送给 delegate（MenuBarController）进行应用内展示和记录
        let payload = ResultPayload(sessionId: sessionId, text: text, language: language)
        guard let payloadData = try? JSONEncoder().encode(payload) else {
            print("❌ 无法编码识别结果")
            return
        }

        let timestamp = Date()
        let hmac = hmacValidator?.generateHMACForEnvelope(
            type: .result,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: deviceId
        )

        let envelope = MessageEnvelope(
            type: .result,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: deviceId,
            hmac: hmac
        )

        print("📤 调用 delegate.connectionManager(didReceiveMessage:)")
        // 通过 delegate 传递给 MenuBarController 进行应用内更新
        delegate?.connectionManager(self, didReceiveMessage: envelope)
        print("✅ delegate 调用完成")
    }

    func engine(
        _ engine: SpeechRecognitionEngine,
        didFailWithError error: Error,
        sessionId: String
    ) {
        print("❌ 语音识别错误: \(error.localizedDescription)")
        recordInboundEvent(
            title: "语音转写失败",
            detail: "Session: \(sessionId)\n错误: \(error.localizedDescription)",
            category: .voice,
            severity: .error
        )
        sendError(code: "recognition_error", message: error.localizedDescription)
    }

    func engine(
        _ engine: SpeechRecognitionEngine,
        didReceivePartialResult text: String,
        sessionId: String
    ) {
        // 处理部分结果，提供实时反馈
        print("📝 部分识别结果: \(text)")
        recordInboundEvent(
            title: "语音转文字部分结果",
            detail: "Session: \(sessionId)\n内容: \(text)",
            category: .voice
        )

        // 可选：将部分结果也发送给客户端，用于实时显示
        // 注意：这里不插入文字，只有最终结果才插入
        // 使用当前会话的语言（从 audioStart 时保存）
        guard sessionId == currentSessionId else {
            return
        }

        // 使用 "zh-CN" 作为默认语言，实际语言会在 audioStart 时确定
        let payload = PartialResultPayload(sessionId: sessionId, text: text, language: "zh-CN")
        guard let payloadData = try? JSONEncoder().encode(payload) else {
            print("❌ 无法编码部分识别结果")
            return
        }

        let timestamp = Date()
        let hmac = hmacValidator?.generateHMACForEnvelope(
            type: .partialResult,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: deviceId
        )

        let envelope = MessageEnvelope(
            type: .partialResult,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: deviceId,
            hmac: hmac
        )

        // 发送部分结果（可选，用于客户端实时显示）
        server.send(envelope)
    }
}
