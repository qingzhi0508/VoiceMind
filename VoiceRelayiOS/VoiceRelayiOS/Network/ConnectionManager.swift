import Foundation
import SharedCore
import CryptoKit
import UIKit

protocol ConnectionManagerDelegate: AnyObject {
    func connectionManager(_ manager: ConnectionManager, didChangePairingState state: PairingState)
    func connectionManager(_ manager: ConnectionManager, didChangeConnectionState state: ConnectionState)
    func connectionManager(_ manager: ConnectionManager, didReceiveMessage envelope: MessageEnvelope)
}

class ConnectionManager: NSObject {
    weak var delegate: ConnectionManagerDelegate?

    private let client = WebSocketClient()
    var hmacValidator: HMACValidator?

    private let keychainService = "com.voicerelay.ios"
    private let keychainAccount = "pairing"
    let deviceId = UUID().uuidString

    private(set) var pairingState: PairingState = .unpaired {
        didSet {
            delegate?.connectionManager(self, didChangePairingState: pairingState)
        }
    }

    private var heartbeatTimer: Timer?
    private var pongTimer: Timer?
    private var currentPingNonce: String?

    override init() {
        super.init()
        client.delegate = self
        loadPairing()
    }

    func connect(to service: DiscoveredService) {
        client.connect(to: service.host, port: service.port)
    }

    func disconnect() {
        stopHeartbeat()
        client.disconnect()
    }

    func pair(with service: DiscoveredService, code: String) {
        connect(to: service)

        // Send pair confirm
        let payload = PairConfirmPayload(
            shortCode: code,
            iosName: UIDevice.current.name,
            iosId: deviceId
        )

        guard let payloadData = try? JSONEncoder().encode(payload) else { return }

        let envelope = MessageEnvelope(
            type: .pairConfirm,
            payload: payloadData,
            timestamp: Date(),
            deviceId: deviceId,
            hmac: nil
        )

        client.send(envelope)
    }

    func unpair() {
        try? KeychainManager.delete(service: keychainService, account: keychainAccount)
        hmacValidator = nil
        pairingState = .unpaired
        disconnect()
    }

    func send(_ envelope: MessageEnvelope) {
        client.send(envelope)
    }

    private func loadPairing() {
        do {
            let pairing = try KeychainManager.retrievePairing(service: keychainService, account: keychainAccount)
            hmacValidator = HMACValidator(sharedSecret: pairing.sharedSecret)
            pairingState = .paired(deviceId: pairing.deviceId, deviceName: pairing.deviceName)
        } catch {
            pairingState = .unpaired
        }
    }

    private func handlePairSuccess(_ payload: PairSuccessPayload, macId: String, macName: String) {
        // Save pairing
        let pairing = PairingData(
            deviceId: macId,
            deviceName: macName,
            sharedSecret: payload.sharedSecret
        )

        do {
            try KeychainManager.savePairing(pairing, service: keychainService, account: keychainAccount)
            hmacValidator = HMACValidator(sharedSecret: payload.sharedSecret)
            pairingState = .paired(deviceId: macId, deviceName: macName)

            startHeartbeat()
        } catch {
            print("Failed to save pairing: \(error)")
        }
    }

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }

    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        pongTimer?.invalidate()
        pongTimer = nil
    }

    private func sendPing() {
        let nonce = UUID().uuidString
        currentPingNonce = nonce

        let payload = PingPayload(nonce: nonce)
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }

        let timestamp = Date()
        let hmac = hmacValidator?.generateHMACForEnvelope(
            type: .ping,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: deviceId
        )

        let envelope = MessageEnvelope(
            type: .ping,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: deviceId,
            hmac: hmac
        )

        client.send(envelope)

        // Start pong timeout
        pongTimer?.invalidate()
        pongTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            self?.handlePongTimeout()
        }
    }

    private func handlePongTimeout() {
        print("Pong timeout, reconnecting...")
        client.disconnect()
    }

    private func sendError(code: String, message: String) {
        let payload = ErrorPayload(code: code, message: message)
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }

        let timestamp = Date()
        let hmac = hmacValidator?.generateHMACForEnvelope(
            type: .error,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: deviceId
        )

        let envelope = MessageEnvelope(
            type: .error,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: deviceId,
            hmac: hmac
        )

        client.send(envelope)
    }
}

extension ConnectionManager: WebSocketClientDelegate {
    func client(_ client: WebSocketClient, didReceiveMessage message: MessageEnvelope) {
        // Handle pairing messages without HMAC
        if message.type == .pairSuccess {
            guard let payload = try? JSONDecoder().decode(PairSuccessPayload.self, from: message.payload) else {
                return
            }
            handlePairSuccess(payload, macId: message.deviceId, macName: "Mac")
            return
        }

        // Validate HMAC for all other messages
        guard let validator = hmacValidator else {
            print("Received message but not paired")
            return
        }

        guard validator.validateEnvelopeHMAC(message) else {
            print("HMAC validation failed")
            return
        }

        // Handle pong
        if message.type == .pong {
            guard let payload = try? JSONDecoder().decode(PongPayload.self, from: message.payload) else {
                return
            }

            if payload.nonce == currentPingNonce {
                pongTimer?.invalidate()
                pongTimer = nil
            }
            return
        }

        // Forward validated message to delegate
        delegate?.connectionManager(self, didReceiveMessage: message)
    }

    func client(_ client: WebSocketClient, didChangeState state: WebSocketConnectionState) {
        let connectionState: ConnectionState

        switch state {
        case .disconnected:
            connectionState = .disconnected
        case .connecting:
            connectionState = .connecting
        case .connected:
            connectionState = .connected
        case .error(let error):
            connectionState = .error(error.localizedDescription)
        }

        delegate?.connectionManager(self, didChangeConnectionState: connectionState)

        if case .connected = connectionState, case .paired = pairingState {
            startHeartbeat()
        } else {
            stopHeartbeat()
        }
    }
}
