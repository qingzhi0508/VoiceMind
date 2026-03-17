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

    private let connectionManager = ConnectionManager()
    private let speechController = SpeechController()
    private let bonjourBrowser = BonjourBrowser()

    private var currentSessionId: String?

    init() {
        connectionManager.delegate = self
        speechController.delegate = self
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
        connectionManager.pair(with: service, code: code)
    }

    func unpair() {
        connectionManager.unpair()
        pairingState = .unpaired
        connectionState = .disconnected
    }

    func reconnect() {
        print("🔄 手动重连")
        reconnectToPairedDevice()
    }

    func connectToMac(ip: String, port: UInt16) {
        latestPairingFeedback = nil
        connectionManager.connectDirectly(ip: ip, port: port)
    }

    func pairWithCode(_ code: String) {
        latestPairingFeedback = nil
        connectionManager.pairWithCode(code)
    }

    func clearPairingFeedback() {
        latestPairingFeedback = nil
    }

    func updateLanguage(_ language: String) {
        selectedLanguage = language
        speechController.selectedLanguage = language
    }

    func requestPermissions(completion: @escaping (Bool) -> Void) {
        speechController.requestPermissions(completion: completion)
    }

    func checkPermissions() -> Bool {
        return speechController.checkPermissions()
    }

    private func reconnectToPairedDevice() {
        // Find the paired device in discovered services
        guard case .paired(let deviceId, let deviceName) = pairingState else {
            print("⚠️ 无法重连: 未配对")
            return
        }

        print("🔍 查找已配对的设备: \(deviceName) (ID: \(deviceId))")

        if let service = discoveredServices.first(where: { $0.id.uuidString == deviceId }) {
            print("✅ 找到设备，开始连接: \(service.host):\(service.port)")
            connectionManager.connect(to: service)
        } else {
            print("⚠️ 未找到已配对的设备，等待 Bonjour 发现...")
            // 设备可能还没被发现，等待 Bonjour 发现后会自动连接
        }
    }
}

extension ContentViewModel: ConnectionManagerDelegate {
    func connectionManager(_ manager: ConnectionManager, didChangePairingState state: PairingState) {
        DispatchQueue.main.async {
            self.pairingState = state

            if case .paired = state {
                self.latestPairingFeedback = "Mac 已确认配对，正在完成绑定。"
                self.showPairingView = false
                self.reconnectToPairedDevice()
            }
        }
    }

    func connectionManager(_ manager: ConnectionManager, didChangeConnectionState state: ConnectionState) {
        DispatchQueue.main.async {
            self.connectionState = state
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

        currentSessionId = payload.sessionId
        speechController.startListening(sessionId: payload.sessionId)
    }

    private func handleStopListen(_ envelope: MessageEnvelope) {
        guard let payload = try? JSONDecoder().decode(StopListenPayload.self, from: envelope.payload) else {
            return
        }

        // Only stop if session ID matches
        guard payload.sessionId == currentSessionId else {
            return
        }

        speechController.stopListening()
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
        }
    }
}

extension ContentViewModel: SpeechControllerDelegate {
    func speechController(_ controller: SpeechController, didChangeState state: RecognitionState) {
        DispatchQueue.main.async {
            self.recognitionState = state
        }
    }

    func speechController(_ controller: SpeechController, didRecognizeText text: String, language: String) {
        guard let sessionId = currentSessionId else { return }

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
    }

    func speechController(_ controller: SpeechController, didFailWithError error: Error) {
        print("Speech recognition error: \(error)")

        // Send error to Mac if we have a session
        if currentSessionId != nil {
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
        }
    }
}

extension ContentViewModel: BonjourBrowserDelegate {
    func browser(_ browser: BonjourBrowser, didFindService service: DiscoveredService) {
        DispatchQueue.main.async {
            if !self.discoveredServices.contains(where: { $0.id == service.id }) {
                self.discoveredServices.append(service)
            }

            // Auto-connect if this is our paired device
            if case .paired(let deviceId, _) = self.pairingState,
               service.id.uuidString == deviceId,
               self.connectionState == .disconnected {
                self.connectionManager.connect(to: service)
            }
        }
    }

    func browser(_ browser: BonjourBrowser, didRemoveService service: DiscoveredService) {
        DispatchQueue.main.async {
            self.discoveredServices.removeAll { $0.id == service.id }
        }
    }
}
