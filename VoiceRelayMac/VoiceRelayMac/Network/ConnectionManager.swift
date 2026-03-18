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
    weak var delegate: ConnectionManagerDelegate?

    let server = WebSocketServer()
    var hmacValidator: HMACValidator?

    private let keychainService = "com.voicerelay.mac"
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

    // 当前会话 ID（用于匹配识别结果）
    private var currentSessionId: String?

    override init() {
        super.init()
        server.delegate = self
        loadPairing()

        // Set delegate for speech recognition
        speechManager.currentEngine?.delegate = self
    }

    func start(port: UInt16) throws {
        // WebSocketServer now handles both TCP server and Bonjour advertising
        try server.start(port: port)
        print("✅ Connection manager started on port \(server.port)")
    }

    func stop() {
        server.stop()
        print("🛑 Connection manager stopped")
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
        updatePairingProgress("已生成配对码，等待 iPhone 扫描二维码或输入配对码。")

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
            updatePairingProgress("配对码校验失败，已拒绝此次请求。")
            recordInboundEvent(
                title: "配对失败",
                detail: "配对码校验失败。\n期望: \(code)\n收到: \(payload.shortCode)",
                category: .pairing,
                severity: .error
            )
            sendError(code: "invalid_code", message: "Invalid pairing code")
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

            print("💾 配对信息已保存到 Keychain")
            updatePairingProgress("配对信息已保存，正在向 iPhone 返回成功结果。")

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
        recordInboundEvent(
            title: "语音流开始",
            detail: "Session: \(payload.sessionId)\n语言: \(payload.language)\n采样率: \(payload.sampleRate) Hz\n通道数: \(payload.channels)\n格式: \(payload.format)",
            category: .voice
        )

        do {
            try speechManager.startRecognition(
                sessionId: payload.sessionId,
                language: payload.language
            )
            currentSessionId = payload.sessionId
            print("✅ 语音识别已启动")
        } catch {
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
        }
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

        do {
            try speechManager.stopRecognition()
            currentSessionId = nil
            print("✅ 语音识别已停止")
        } catch {
            print("❌ 停止语音识别失败: \(error.localizedDescription)")
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

        // 将识别结果发送给 delegate（MenuBarController）进行文本注入
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

        // 通过 delegate 传递给 MenuBarController 进行文本注入
        delegate?.connectionManager(self, didReceiveMessage: envelope)
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
        // Optional: can be used for real-time display in the future
        // For now, we only handle final results
    }
}

