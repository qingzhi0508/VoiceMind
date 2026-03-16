import Cocoa
import Foundation
import SharedCore

// MARK: - ConnectionManagerDelegate
extension MenuBarController: ConnectionManagerDelegate {
    func connectionManager(_ manager: ConnectionManager, didChangePairingState state: PairingState) {
        updateStatusIcon()
        updateMenu()

        if case .paired = state {
            pairingWindow?.close()
        }
    }

    func connectionManager(_ manager: ConnectionManager, didChangeConnectionState state: ConnectionState) {
        updateStatusIcon()
        updateMenu()
    }

    func connectionManager(_ manager: ConnectionManager, didReceiveMessage envelope: MessageEnvelope) {
        switch envelope.type {
        case .result:
            handleResultMessage(envelope)
        case .ping:
            handlePingMessage(envelope)
        default:
            break
        }
    }

    private func handleResultMessage(_ envelope: MessageEnvelope) {
        guard let payload = try? JSONDecoder().decode(ResultPayload.self, from: envelope.payload) else {
            return
        }

        // Validate session ID
        guard payload.sessionId == currentSessionId else {
            print("Ignoring result with mismatched session ID")
            return
        }

        // Clear session
        currentSessionId = nil
        sessionTimer?.invalidate()
        sessionTimer = nil

        // Inject text
        do {
            try textInjector.inject(payload.text)
        } catch TextInjectionError.accessibilityPermissionDenied {
            showTextInjectionPermissionError(with: payload.text)
        } catch {
            showTextCopyAlert(payload.text, error: error.localizedDescription)
        }
    }

    private func handlePingMessage(_ envelope: MessageEnvelope) {
        guard let payload = try? JSONDecoder().decode(PingPayload.self, from: envelope.payload) else {
            return
        }

        // Send pong
        let pongPayload = PongPayload(nonce: payload.nonce)
        guard let payloadData = try? JSONEncoder().encode(pongPayload) else { return }

        let timestamp = Date()
        let hmac = connectionManager.hmacValidator?.generateHMACForEnvelope(
            type: .pong,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId
        )

        let pongEnvelope = MessageEnvelope(
            type: .pong,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId,
            hmac: hmac
        )

        connectionManager.send(pongEnvelope)
    }
}

// MARK: - HotkeyMonitorDelegate
extension MenuBarController: HotkeyMonitorDelegate {
    func hotkeyMonitor(_ monitor: HotkeyMonitor, didPressHotkey sessionId: String) {
        guard case .paired = connectionManager.pairingState else {
            return
        }

        currentSessionId = sessionId

        // Start 30-second timeout
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            self?.handleSessionTimeout()
        }

        // Send startListen message
        let payload = StartListenPayload(sessionId: sessionId)
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }

        let timestamp = Date()
        let hmac = connectionManager.hmacValidator?.generateHMACForEnvelope(
            type: .startListen,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId
        )

        let envelope = MessageEnvelope(
            type: .startListen,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId,
            hmac: hmac
        )

        connectionManager.send(envelope)
    }

    func hotkeyMonitor(_ monitor: HotkeyMonitor, didReleaseHotkey sessionId: String) {
        guard sessionId == currentSessionId else { return }

        // Send stopListen message
        let payload = StopListenPayload(sessionId: sessionId)
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }

        let timestamp = Date()
        let hmac = connectionManager.hmacValidator?.generateHMACForEnvelope(
            type: .stopListen,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId
        )

        let envelope = MessageEnvelope(
            type: .stopListen,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId,
            hmac: hmac
        )

        connectionManager.send(envelope)
    }

    private func handleSessionTimeout() {
        currentSessionId = nil
        showError("30秒内未收到 iPhone 响应")
    }
}
