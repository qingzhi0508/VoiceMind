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

    private let lastKnownHostKey = "voicerelay.lastKnownHost"
    private let lastKnownPortKey = "voicerelay.lastKnownPort"
    private let lastKnownDeviceNameKey = "voicerelay.lastKnownDeviceName"

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
        saveLastKnownConnection(host: service.host, port: service.port, deviceName: service.name)
        connectionManager.pair(with: service, code: code)
    }

    func unpair() {
        connectionManager.unpair()
        pairingState = .unpaired
        connectionState = .disconnected
        reconnectStatusMessage = nil
    }

    func reconnect() {
        print("🔄 手动重连")
        latestPairingFeedback = "正在尝试重连到已配对的 Mac..."
        reconnectStatusMessage = "正在查找已配对的 Mac..."
        reconnectToPairedDevice()
    }

    func connectToMac(ip: String, port: UInt16, deviceName: String? = nil) {
        latestPairingFeedback = nil
        saveLastKnownConnection(host: ip, port: port, deviceName: deviceName)
        connectionManager.connectDirectly(ip: ip, port: port)
    }

    func pairWithCode(_ code: String, deviceName: String? = nil) {
        latestPairingFeedback = nil
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

        if let service = discoveredServices.first(where: { $0.id.uuidString == deviceId || $0.name == deviceName }) {
            print("✅ 找到设备，开始连接: \(service.host):\(service.port)")
            latestPairingFeedback = "已找到 \(service.name)，正在建立连接..."
            reconnectStatusMessage = "已找到 \(service.name)，正在建立连接..."
            connectionManager.connect(to: service)
        } else if let lastKnownHost,
                  let lastKnownPort {
            print("📡 未找到 Bonjour 服务，回退到上次已知地址: \(lastKnownHost):\(lastKnownPort)")
            latestPairingFeedback = "未发现 Bonjour 服务，正在直连上次保存的地址..."
            reconnectStatusMessage = "未发现 Bonjour 服务，已回退到上次保存的地址直连..."
            connectionManager.connectDirectly(ip: lastKnownHost, port: lastKnownPort)
        } else {
            print("⚠️ 未找到已配对的设备，等待 Bonjour 发现...")
            latestPairingFeedback = "暂未发现已配对的 Mac，请确认 Mac 在线并与 iPhone 处于同一网络。"
            reconnectStatusMessage = "未发现已配对的 Mac，请确认 Mac 在线并与 iPhone 处于同一网络。"
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

            switch state {
            case .connecting:
                if self.reconnectStatusMessage != nil {
                    self.reconnectStatusMessage = self.reconnectStatusMessage ?? "正在建立连接..."
                }
            case .connected:
                if self.reconnectStatusMessage != nil {
                    self.reconnectStatusMessage = "重连成功，已重新连接。"
                }
            case .error(let message):
                if self.reconnectStatusMessage != nil {
                    self.reconnectStatusMessage = "重连失败：\(message)"
                }
            case .disconnected:
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
            if case .paired(let deviceId, let deviceName) = self.pairingState,
               (service.id.uuidString == deviceId || service.name == deviceName),
               self.connectionState == .disconnected {
                self.reconnectStatusMessage = "已发现已配对的 Mac，正在自动重连..."
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
