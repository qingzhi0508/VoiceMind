import Foundation
import SwiftUI
import Combine
import SharedCore

class ContentViewModel: ObservableObject {
    @Published var pairingState: PairingState = .unpaired
    @Published var connectionState: ConnectionState = .disconnected
    @Published var recognitionState: RecognitionState = .idle
    @Published var discoveredServices: [DiscoveredService] = []
    @Published var selectedLanguage: String = "zh-CN"
    @Published var showPairingView = false
    @Published var latestPairingFeedback: String?
    @Published var reconnectStatusMessage: String?
    @Published var pushToTalkStatusMessage: String?
    @Published var inboundDataRecords: [InboundDataRecord] = []
    @Published var reconnectNeedsManualAction = false

    private let lastKnownHostKey = "voicerelay.lastKnownHost"
    private let lastKnownPortKey = "voicerelay.lastKnownPort"
    private let lastKnownDeviceNameKey = "voicerelay.lastKnownDeviceName"

    private let connectionManager = ConnectionManager()
    private let speechController = SpeechController()
    private let audioStreamController = AudioStreamController()
    private let bonjourBrowser = BonjourBrowser()

    private var currentSessionId: String?
    private var manualSessionId: String?

    init() {
        connectionManager.delegate = self
        speechController.delegate = self
        audioStreamController.delegate = self
        bonjourBrowser.delegate = self

        // Load pairing state
        pairingState = connectionManager.pairingState

        // Start browsing for services
        bonjourBrowser.start()

        // Auto-reconnect if paired
        if case .paired = pairingState {
            reconnectToPairedDevice()
        }
    }

    func pair(with service: DiscoveredService, code: String) {
        print("📱 ContentViewModel.pair 被调用")
        print("   服务: \(service.name) (\(service.host):\(service.port))")
        print("   配对码: \(code)")
        latestPairingFeedback = nil
        appendInboundDataRecord(
            title: "发起配对",
            detail: "服务: \(service.name)\n地址: \(service.host):\(service.port)\n配对码: \(code)",
            category: .pairing
        )
        saveLastKnownConnection(host: service.host, port: service.port, deviceName: service.name)
        connectionManager.pair(with: service, code: code)
    }

    func unpair() {
        connectionManager.unpair()
        pairingState = .unpaired
        connectionState = .disconnected
        reconnectStatusMessage = nil
        reconnectNeedsManualAction = false
    }

    func reconnect() {
        print("🔄 手动重连")
        reconnectNeedsManualAction = false
        latestPairingFeedback = "正在尝试重连到已配对的 Mac..."
        reconnectStatusMessage = "正在查找已配对的 Mac..."
        appendInboundDataRecord(
            title: "手动重连",
            detail: "用户触发重连，正在查找已配对的 Mac。",
            category: .connection
        )
        reconnectToPairedDevice()
    }

    func connectToMac(ip: String, port: UInt16, deviceName: String? = nil) {
        latestPairingFeedback = nil
        appendInboundDataRecord(
            title: "直接连接 Mac",
            detail: "地址: \(ip):\(port)\n设备: \(deviceName ?? "未知")",
            category: .connection
        )
        saveLastKnownConnection(host: ip, port: port, deviceName: deviceName)
        connectionManager.connectDirectly(ip: ip, port: port)
    }

    func pairWithCode(_ code: String, deviceName: String? = nil) {
        latestPairingFeedback = nil
        appendInboundDataRecord(
            title: "提交配对码",
            detail: "设备: \(deviceName ?? lastKnownDeviceName ?? "未知")\n配对码: \(code)",
            category: .pairing
        )
        connectionManager.setPendingPairingDeviceName(deviceName ?? lastKnownDeviceName)
        connectionManager.pairWithCode(code)
    }

    func clearPairingFeedback() {
        latestPairingFeedback = nil
    }

    func updateLanguage(_ language: String) {
        selectedLanguage = language
        speechController.selectedLanguage = language
    }

    func startPushToTalk() {
        guard canStartPushToTalk else { return }

        do {
            let sessionId = UUID().uuidString
            manualSessionId = sessionId
            try audioStreamController.startStreaming(sessionId: sessionId)
            recognitionState = .listening
            pushToTalkStatusMessage = "正在采集语音，松开后发送到 Mac 识别。"
        } catch {
            recognitionState = .idle
            manualSessionId = nil
            pushToTalkStatusMessage = error.localizedDescription
        }
    }

    func stopPushToTalk() {
        guard recognitionState == .listening else { return }
        recognitionState = .sending
        pushToTalkStatusMessage = "正在发送语音到 Mac..."
        audioStreamController.stopStreaming()
    }

    var canStartPushToTalk: Bool {
        if case .paired = pairingState, case .connected = connectionState {
            return recognitionState == .idle && checkPermissions()
        }
        return false
    }

    var canManuallyReconnectFromPrimaryButton: Bool {
        if case .paired = pairingState {
            return reconnectNeedsManualAction && recognitionState == .idle
        }
        return false
    }

    func handlePrimaryButtonPressChanged(_ isPressing: Bool) {
        if canManuallyReconnectFromPrimaryButton {
            if isPressing {
                reconnect()
            }
            return
        }

        if isPressing {
            startPushToTalk()
        } else {
            stopPushToTalk()
        }
    }

    func requestPermissions(completion: @escaping (Bool) -> Void) {
        audioStreamController.requestPermissions(completion: completion)
    }

    func checkPermissions() -> Bool {
        return audioStreamController.checkPermissions()
    }

    private func reconnectToPairedDevice() {
        // Find the paired device in discovered services
        guard case .paired(let deviceId, let deviceName) = pairingState else {
            print("⚠️ 无法重连: 未配对")
            return
        }

        print("🔍 查找已配对的设备: \(deviceName) (ID: \(deviceId))")

        if let service = discoveredServices.first(where: { $0.id.uuidString == deviceId || $0.name == deviceName }) {
            print("✅ 找到设备，开始连接: \(service.host):\(service.port)")
            latestPairingFeedback = "已找到 \(service.name)，正在建立连接..."
            reconnectStatusMessage = "已找到 \(service.name)，正在建立连接..."
            appendInboundDataRecord(
                title: "发现已配对设备",
                detail: "设备: \(service.name)\n地址: \(service.host):\(service.port)",
                category: .connection
            )
            connectionManager.connect(to: service)
        } else if let lastKnownHost,
                  let lastKnownPort {
            print("📡 未找到 Bonjour 服务，回退到上次已知地址: \(lastKnownHost):\(lastKnownPort)")
            latestPairingFeedback = "未发现 Bonjour 服务，正在直连上次保存的地址..."
            reconnectStatusMessage = "未发现 Bonjour 服务，已回退到上次保存的地址直连..."
            appendInboundDataRecord(
                title: "回退到直连",
                detail: "未发现 Bonjour 服务。\n地址: \(lastKnownHost):\(lastKnownPort)",
                category: .connection,
                severity: .warning
            )
            connectionManager.connectDirectly(ip: lastKnownHost, port: lastKnownPort)
        } else {
            print("⚠️ 未找到已配对的设备，等待 Bonjour 发现...")
            latestPairingFeedback = "暂未发现已配对的 Mac，请确认 Mac 在线并与 iPhone 处于同一网络。"
            reconnectStatusMessage = "未发现已配对的 Mac，请确认 Mac 在线并与 iPhone 处于同一网络。"
            appendInboundDataRecord(
                title: "未发现已配对设备",
                detail: "Bonjour 和上次保存地址都无法用于重连。",
                category: .connection,
                severity: .warning
            )
        }
    }

    private var lastKnownHost: String? {
        UserDefaults.standard.string(forKey: lastKnownHostKey)
    }

    private var lastKnownPort: UInt16? {
        let port = UserDefaults.standard.integer(forKey: lastKnownPortKey)
        return port > 0 ? UInt16(port) : nil
    }

    private var lastKnownDeviceName: String? {
        UserDefaults.standard.string(forKey: lastKnownDeviceNameKey)
    }

    private func saveLastKnownConnection(host: String, port: UInt16, deviceName: String?) {
        UserDefaults.standard.set(host, forKey: lastKnownHostKey)
        UserDefaults.standard.set(Int(port), forKey: lastKnownPortKey)
        if let deviceName, !deviceName.isEmpty {
            UserDefaults.standard.set(deviceName, forKey: lastKnownDeviceNameKey)
        }
    }

    func clearInboundDataRecords() {
        inboundDataRecords.removeAll()
    }

    private func appendInboundDataRecord(
        title: String,
        detail: String,
        category: InboundDataCategory,
        severity: InboundDataSeverity = .info
    ) {
        let record = InboundDataRecord(
            timestamp: Date(),
            title: title,
            detail: detail,
            category: category,
            severity: severity
        )
        inboundDataRecords.insert(record, at: 0)

        if inboundDataRecords.count > 200 {
            inboundDataRecords = Array(inboundDataRecords.prefix(200))
        }
    }
}

extension ContentViewModel: ConnectionManagerDelegate {
    func connectionManager(_ manager: ConnectionManager, didChangePairingState state: PairingState) {
        DispatchQueue.main.async {
            self.pairingState = state

            if case .paired = state {
                self.reconnectNeedsManualAction = false
                self.latestPairingFeedback = "Mac 已确认配对，正在完成绑定。"
                self.appendInboundDataRecord(
                    title: "配对成功",
                    detail: "Mac 已确认配对，绑定已完成。",
                    category: .pairing
                )
                self.showPairingView = false
                // 配对成功后不需要重连，因为连接已经存在
                // 只有在连接断开的情况下才需要重连
                if self.connectionState == .disconnected {
                    print("🔄 配对成功但连接已断开，尝试重连")
                    self.reconnectToPairedDevice()
                } else {
                    print("✅ 配对成功，保持现有连接")
                }
            }
        }
    }

    func connectionManager(_ manager: ConnectionManager, didChangeConnectionState state: ConnectionState) {
        DispatchQueue.main.async {
            self.connectionState = state

            switch state {
            case .connecting:
                self.reconnectNeedsManualAction = false
                self.appendInboundDataRecord(
                    title: "连接中",
                    detail: "正在与 Mac 建立连接。",
                    category: .connection
                )
                if self.reconnectStatusMessage != nil {
                    self.reconnectStatusMessage = self.reconnectStatusMessage ?? "正在建立连接..."
                }
            case .connected:
                self.reconnectNeedsManualAction = false
                self.appendInboundDataRecord(
                    title: "连接成功",
                    detail: "与 Mac 的连接已建立。",
                    category: .connection
                )
                if self.reconnectStatusMessage != nil {
                    self.reconnectStatusMessage = "重连成功，已重新连接。"
                }
            case .error(let message):
                if message.contains("自动重连已停止") {
                    self.reconnectNeedsManualAction = true
                }
                self.appendInboundDataRecord(
                    title: "连接失败",
                    detail: message,
                    category: .connection,
                    severity: .error
                )
                if self.reconnectStatusMessage != nil {
                    self.reconnectStatusMessage = "重连失败：\(message)"
                }
            case .disconnected:
                self.appendInboundDataRecord(
                    title: "连接断开",
                    detail: "当前与 Mac 没有活跃连接。",
                    category: .connection,
                    severity: .warning
                )
                if self.recognitionState == .listening {
                    self.pushToTalkStatusMessage = "连接已断开，无法继续发送语音结果。"
                    self.recognitionState = .idle
                    self.manualSessionId = nil
                    self.audioStreamController.stopStreaming()
                } else if self.reconnectNeedsManualAction {
                    self.pushToTalkStatusMessage = "自动重连已停止，按住按钮重新连接服务。"
                }
                break
            }
        }
    }

    func connectionManager(_ manager: ConnectionManager, didReceiveMessage envelope: MessageEnvelope) {
        switch envelope.type {
        case .startListen:
            handleStartListen(envelope)
        case .stopListen:
            handleStopListen(envelope)
        case .error:
            handlePairingError(envelope)
        default:
            break
        }
    }

    private func handleStartListen(_ envelope: MessageEnvelope) {
        guard let payload = try? JSONDecoder().decode(StartListenPayload.self, from: envelope.payload) else {
            return
        }

        print("🎤 收到 startListen 消息，使用音频流模式")
        currentSessionId = payload.sessionId

        // 使用音频流模式（发送到 Mac 端识别）
        do {
            try audioStreamController.startStreaming(sessionId: payload.sessionId)
        } catch {
            print("❌ 启动音频流失败: \(error.localizedDescription)")
        }
    }

    private func handleStopListen(_ envelope: MessageEnvelope) {
        guard let payload = try? JSONDecoder().decode(StopListenPayload.self, from: envelope.payload) else {
            return
        }

        // Only stop if session ID matches
        guard payload.sessionId == currentSessionId else {
            return
        }

        print("🛑 收到 stopListen 消息，停止音频流")
        audioStreamController.stopStreaming()
    }

    private func handlePairingError(_ envelope: MessageEnvelope) {
        guard let payload = try? JSONDecoder().decode(ErrorPayload.self, from: envelope.payload) else {
            return
        }

        let message: String
        switch payload.code {
        case "invalid_code":
            message = "Mac 返回：配对码不正确。"
        case "not_pairing":
            message = "Mac 返回：当前不在配对模式。"
        case "pairing_failed":
            message = "Mac 返回：保存配对信息失败。"
        default:
            message = "Mac 返回：\(payload.message)"
        }

        DispatchQueue.main.async {
            self.latestPairingFeedback = message
            self.appendInboundDataRecord(
                title: "Mac 返回错误",
                detail: message,
                category: .pairing,
                severity: .error
            )
        }
    }
}

extension ContentViewModel: SpeechControllerDelegate {
    func speechController(_ controller: SpeechController, didChangeState state: RecognitionState) {
        DispatchQueue.main.async {
            self.recognitionState = state

            switch state {
            case .idle:
                if self.canManuallyReconnectFromPrimaryButton {
                    self.pushToTalkStatusMessage = "自动重连已停止，按住按钮重新连接服务。"
                } else if self.connectionState == .connected {
                    self.pushToTalkStatusMessage = "按住麦克风开始说话。"
                } else {
                    self.pushToTalkStatusMessage = "连接 Mac 后可按住说话。"
                }
            case .listening:
                self.pushToTalkStatusMessage = "正在监听语音，松开发送到 Mac。"
            case .processing:
                self.pushToTalkStatusMessage = "正在整理语音结果..."
            case .sending:
                self.pushToTalkStatusMessage = "正在发送结果到 Mac..."
            }
        }
    }

    func speechController(_ controller: SpeechController, didRecognizeText text: String, language: String) {
        guard let sessionId = currentSessionId ?? manualSessionId else { return }

        // Send result back to Mac
        let payload = ResultPayload(
            sessionId: sessionId,
            text: text,
            language: language
        )

        guard let payloadData = try? JSONEncoder().encode(payload) else { return }

        let timestamp = Date()
        let hmac = connectionManager.hmacValidator?.generateHMACForEnvelope(
            type: .result,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId
        )

        let envelope = MessageEnvelope(
            type: .result,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId,
            hmac: hmac
        )

        connectionManager.send(envelope)
        currentSessionId = nil
        manualSessionId = nil
        pushToTalkStatusMessage = "语音结果已发送到 Mac。"
        appendInboundDataRecord(
            title: "发送识别结果",
            detail: "Session: \(sessionId)\n语言: \(language)\n内容: \(text)",
            category: .voice
        )
    }

    func speechController(_ controller: SpeechController, didFailWithError error: Error) {
        print("Speech recognition error: \(error)")
        pushToTalkStatusMessage = error.localizedDescription
        appendInboundDataRecord(
            title: "语音识别失败",
            detail: error.localizedDescription,
            category: .voice,
            severity: .error
        )

        // Send error to Mac if we have a session
        if currentSessionId != nil || manualSessionId != nil {
            let payload = ErrorPayload(
                code: "SPEECH_ERROR",
                message: error.localizedDescription
            )

            guard let payloadData = try? JSONEncoder().encode(payload) else { return }

            let timestamp = Date()
            let hmac = connectionManager.hmacValidator?.generateHMACForEnvelope(
                type: .error,
                payload: payloadData,
                timestamp: timestamp,
                deviceId: connectionManager.deviceId
            )

            let envelope = MessageEnvelope(
                type: .error,
                payload: payloadData,
                timestamp: timestamp,
                deviceId: connectionManager.deviceId,
                hmac: hmac
            )

            connectionManager.send(envelope)
            currentSessionId = nil
            manualSessionId = nil
        }
    }
}

extension ContentViewModel: BonjourBrowserDelegate {
    func browser(_ browser: BonjourBrowser, didFindService service: DiscoveredService) {
        DispatchQueue.main.async {
            if !self.discoveredServices.contains(where: { $0.id == service.id }) {
            self.discoveredServices.append(service)
            self.appendInboundDataRecord(
                title: "发现 Bonjour 服务",
                detail: "设备: \(service.name)\n地址: \(service.host):\(service.port)",
                category: .connection
            )
            }

            // Auto-connect if this is our paired device
            if case .paired(let deviceId, let deviceName) = self.pairingState,
               (service.id.uuidString == deviceId || service.name == deviceName),
               self.connectionState == .disconnected,
               !self.reconnectNeedsManualAction {
                self.reconnectStatusMessage = "已发现已配对的 Mac，正在自动重连..."
                self.connectionManager.connect(to: service)
            }
        }
    }

    func browser(_ browser: BonjourBrowser, didRemoveService service: DiscoveredService) {
        DispatchQueue.main.async {
            self.discoveredServices.removeAll { $0.id == service.id }
            self.appendInboundDataRecord(
                title: "Bonjour 服务移除",
                detail: "设备: \(service.name)",
                category: .connection,
                severity: .warning
            )
        }
    }
}

// MARK: - AudioStreamControllerDelegate

extension ContentViewModel: AudioStreamControllerDelegate {
    func audioStreamController(_ controller: AudioStreamController, didStartStream payload: AudioStartPayload) {
        print("📤 发送 audioStart 消息")
        DispatchQueue.main.async {
            self.recognitionState = .listening
            self.pushToTalkStatusMessage = "正在采集语音，松开后发送到 Mac 识别。"
        }
        appendInboundDataRecord(
            title: "开始发送语音流",
            detail: "Session: \(payload.sessionId)\n语言: \(payload.language)\n采样率: \(payload.sampleRate) Hz",
            category: .voice
        )
        guard let payloadData = try? JSONEncoder().encode(payload) else {
            print("❌ 无法编码 audioStart payload")
            return
        }

        let timestamp = Date()
        let hmac = connectionManager.hmacValidator?.generateHMACForEnvelope(
            type: .audioStart,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId
        )

        let envelope = MessageEnvelope(
            type: .audioStart,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId,
            hmac: hmac
        )

        connectionManager.send(envelope)
    }

    func audioStreamController(_ controller: AudioStreamController, didCaptureAudio payload: AudioDataPayload) {
        guard let payloadData = try? JSONEncoder().encode(payload) else {
            return
        }

        let timestamp = Date()
        let hmac = connectionManager.hmacValidator?.generateHMACForEnvelope(
            type: .audioData,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId
        )

        let envelope = MessageEnvelope(
            type: .audioData,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId,
            hmac: hmac
        )

        connectionManager.send(envelope)
    }

    func audioStreamController(_ controller: AudioStreamController, didEndStream payload: AudioEndPayload) {
        print("📤 发送 audioEnd 消息")
        DispatchQueue.main.async {
            self.manualSessionId = nil
            self.recognitionState = .idle
            self.pushToTalkStatusMessage = "语音已发送到 Mac，正在识别并尝试输入到当前光标位置。"
        }
        appendInboundDataRecord(
            title: "结束语音流",
            detail: "Session: \(payload.sessionId)",
            category: .voice
        )
        guard let payloadData = try? JSONEncoder().encode(payload) else {
            print("❌ 无法编码 audioEnd payload")
            return
        }

        let timestamp = Date()
        let hmac = connectionManager.hmacValidator?.generateHMACForEnvelope(
            type: .audioEnd,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId
        )

        let envelope = MessageEnvelope(
            type: .audioEnd,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId,
            hmac: hmac
        )

        connectionManager.send(envelope)
    }
}
