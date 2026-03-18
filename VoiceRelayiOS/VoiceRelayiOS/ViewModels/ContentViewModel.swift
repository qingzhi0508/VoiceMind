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

    private func localized(_ key: String, _ args: CVarArg...) -> String {
        if args.isEmpty {
            return String(localized: .init(key))
        }
        return String(format: String(localized: .init(key)), arguments: args)
    }

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
            title: localized("log_title_pairing_start"),
            detail: localized(
                "log_detail_pairing_start_format",
                service.name,
                service.host,
                "\(service.port)",
                code
            ),
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
        latestPairingFeedback = localized("reconnect_trying")
        reconnectStatusMessage = localized("reconnect_searching")
        appendInboundDataRecord(
            title: localized("log_title_manual_reconnect"),
            detail: localized("log_detail_manual_reconnect"),
            category: .connection
        )
        connectionManager.disconnect()
        reconnectToPairedDevice()
    }

    func connectToMac(ip: String, port: UInt16, deviceName: String? = nil) {
        latestPairingFeedback = nil
        appendInboundDataRecord(
            title: localized("log_title_direct_connect"),
            detail: localized(
                "log_detail_direct_connect_format",
                ip,
                "\(port)",
                deviceName ?? localized("connection_status_unknown")
            ),
            category: .connection
        )
        saveLastKnownConnection(host: ip, port: port, deviceName: deviceName)
        connectionManager.connectDirectly(ip: ip, port: port)
    }

    func pairWithCode(_ code: String, deviceName: String? = nil) {
        latestPairingFeedback = nil
        appendInboundDataRecord(
            title: localized("log_title_submit_pairing_code"),
            detail: localized(
                "log_detail_submit_pairing_code_format",
                deviceName ?? lastKnownDeviceName ?? localized("connection_status_unknown"),
                code
            ),
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
            pushToTalkStatusMessage = localized("ptt_capturing")
        } catch {
            recognitionState = .idle
            manualSessionId = nil
            pushToTalkStatusMessage = error.localizedDescription
        }
    }

    func stopPushToTalk() {
        guard recognitionState == .listening else { return }
        recognitionState = .sending
        pushToTalkStatusMessage = localized("ptt_sending_audio")
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
            latestPairingFeedback = localized("reconnect_found_format", service.name)
            reconnectStatusMessage = localized("reconnect_found_format", service.name)
            appendInboundDataRecord(
                title: localized("log_title_paired_device_found"),
                detail: localized(
                    "log_detail_paired_device_found_format",
                    service.name,
                    service.host,
                    "\(service.port)"
                ),
                category: .connection
            )
            connectionManager.connect(to: service)
        } else if let lastKnownHost,
                  let lastKnownPort {
            print("📡 未找到 Bonjour 服务，回退到上次已知地址: \(lastKnownHost):\(lastKnownPort)")
            latestPairingFeedback = localized("reconnect_no_bonjour")
            reconnectStatusMessage = localized("reconnect_fallback")
            appendInboundDataRecord(
                title: localized("log_title_fallback_direct"),
                detail: localized(
                    "log_detail_fallback_direct_format",
                    lastKnownHost,
                    "\(lastKnownPort)"
                ),
                category: .connection,
                severity: .warning
            )
            connectionManager.connectDirectly(ip: lastKnownHost, port: lastKnownPort)
        } else {
            print("⚠️ 未找到已配对的设备，等待 Bonjour 发现...")
            latestPairingFeedback = localized("reconnect_not_found")
            reconnectStatusMessage = localized("reconnect_not_found")
            appendInboundDataRecord(
                title: localized("log_title_no_paired_device"),
                detail: localized("log_detail_no_paired_device"),
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
                self.latestPairingFeedback = self.localized("pairing_confirmed_binding")
                self.appendInboundDataRecord(
                    title: self.localized("log_pairing_success_title"),
                    detail: self.localized("log_pairing_success_detail"),
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
                    title: self.localized("log_connecting_title"),
                    detail: self.localized("log_connecting_detail"),
                    category: .connection
                )
                if self.reconnectStatusMessage != nil {
                    self.reconnectStatusMessage = self.reconnectStatusMessage ?? self.localized("reconnect_connecting")
                }
            case .connected:
                self.reconnectNeedsManualAction = false
                self.appendInboundDataRecord(
                    title: self.localized("log_connected_title"),
                    detail: self.localized("log_connected_detail"),
                    category: .connection
                )
                self.reconnectStatusMessage = self.localized("reconnect_success")
            case .error(let message):
                if message.contains(self.localized("reconnect_exhausted_snippet")) {
                    self.reconnectNeedsManualAction = true
                }
                self.appendInboundDataRecord(
                    title: self.localized("log_connection_failed_title"),
                    detail: message,
                    category: .connection,
                    severity: .error
                )
                if self.reconnectStatusMessage != nil {
                    self.reconnectStatusMessage = self.localized("reconnect_failed_format", message)
                }
            case .disconnected:
                if case .paired = self.pairingState, !self.reconnectNeedsManualAction {
                    self.reconnectStatusMessage = self.localized("reconnect_waiting")
                }
                self.appendInboundDataRecord(
                    title: self.localized("log_disconnected_title"),
                    detail: self.localized("log_disconnected_detail"),
                    category: .connection,
                    severity: .warning
                )
                if self.recognitionState == .listening {
                    self.pushToTalkStatusMessage = self.localized("ptt_connection_lost")
                    self.recognitionState = .idle
                    self.manualSessionId = nil
                    self.audioStreamController.stopStreaming()
                } else if self.reconnectNeedsManualAction {
                    self.pushToTalkStatusMessage = self.localized("ptt_hold_to_reconnect")
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
            message = localized("pairing_code_incorrect")
        case "not_pairing":
            message = localized("pairing_not_in_pairing_mode")
        case "pairing_failed":
            message = localized("pairing_save_failed")
        default:
            message = localized("pairing_mac_error_format", payload.message)
        }

        DispatchQueue.main.async {
            self.latestPairingFeedback = message
            self.appendInboundDataRecord(
                title: self.localized("log_error_from_mac_title"),
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
                    self.pushToTalkStatusMessage = self.localized("ptt_hold_to_reconnect")
                } else if self.connectionState == .connected {
                    self.pushToTalkStatusMessage = self.localized("ptt_hold_to_talk")
                } else {
                    self.pushToTalkStatusMessage = self.localized("ptt_connect_to_talk")
                }
            case .listening:
                self.pushToTalkStatusMessage = self.localized("ptt_listening")
            case .processing:
                self.pushToTalkStatusMessage = self.localized("ptt_processing")
            case .sending:
                self.pushToTalkStatusMessage = self.localized("ptt_sending_result")
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
        pushToTalkStatusMessage = localized("ptt_sent")
        appendInboundDataRecord(
            title: localized("log_speech_result_title"),
            detail: localized("log_speech_result_detail_format", sessionId, language, text),
            category: .voice
        )
    }

    func speechController(_ controller: SpeechController, didFailWithError error: Error) {
        print("Speech recognition error: \(error)")
        pushToTalkStatusMessage = error.localizedDescription
        appendInboundDataRecord(
            title: localized("log_speech_error_title"),
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
                title: self.localized("log_bonjour_found_title"),
                detail: self.localized("log_bonjour_found_detail_format", service.name, service.host, "\(service.port)"),
                category: .connection
            )
            }

            // Auto-connect if this is our paired device
            if case .paired(let deviceId, let deviceName) = self.pairingState,
               (service.id.uuidString == deviceId || service.name == deviceName),
               self.connectionState != .connected,
               !self.reconnectNeedsManualAction {
                self.reconnectStatusMessage = self.localized("reconnect_found_auto")
                self.connectionManager.connect(to: service)
            } else if case .paired(let deviceId, let deviceName) = self.pairingState,
                      (service.id.uuidString == deviceId || service.name == deviceName),
                      self.reconnectNeedsManualAction {
                self.reconnectNeedsManualAction = false
                self.reconnectStatusMessage = self.localized("reconnect_found_again")
                self.connectionManager.connect(to: service)
            }
        }
    }

    func browser(_ browser: BonjourBrowser, didRemoveService service: DiscoveredService) {
        DispatchQueue.main.async {
            self.discoveredServices.removeAll { $0.id == service.id }
            self.appendInboundDataRecord(
                title: self.localized("log_bonjour_removed_title"),
                detail: self.localized("log_bonjour_removed_detail_format", service.name),
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
            self.pushToTalkStatusMessage = self.localized("ptt_capturing")
        }
        appendInboundDataRecord(
            title: localized("log_audio_start_title"),
            detail: localized("log_audio_start_detail_format", payload.sessionId, payload.language, "\(payload.sampleRate)"),
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
            self.pushToTalkStatusMessage = self.localized("ptt_sent_mac_processing")
        }
        appendInboundDataRecord(
            title: localized("log_audio_end_title"),
            detail: localized("log_audio_end_detail_format", payload.sessionId),
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
