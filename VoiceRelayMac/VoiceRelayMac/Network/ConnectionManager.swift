import Foundation
import SharedCore
import CryptoKit

protocol ConnectionManagerDelegate: AnyObject {
    func connectionManager(_ manager: ConnectionManager, didChangePairingState state: PairingState)
    func connectionManager(_ manager: ConnectionManager, didChangeConnectionState state: ConnectionState)
    func connectionManager(_ manager: ConnectionManager, didReceiveMessage envelope: MessageEnvelope)
}

class ConnectionManager: NSObject {
    weak var delegate: ConnectionManagerDelegate?

    private let server = WebSocketServer()
    private var bonjourPublisher: BonjourPublisher?
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

    override init() {
        super.init()
        server.delegate = self
        loadPairing()
    }

    func start() throws {
        try server.start()
        let publisher = BonjourPublisher(port: server.port)
        try publisher.start()
        bonjourPublisher = publisher
    }

    func stop() {
        server.stop()
        bonjourPublisher?.stop()
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

        return code
    }

    func cancelPairing() {
        pairingTimer?.invalidate()
        pairingTimer = nil

        if case .pairing = pairingState {
            pairingState = .unpaired
        }
    }

    func unpair() {
        try? KeychainManager.delete(service: keychainService, account: keychainAccount)
        hmacValidator = nil
        pairingState = .unpaired
    }

    func send(_ envelope: MessageEnvelope) {
        server.send(envelope)
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

    private func handlePairConfirm(_ payload: PairConfirmPayload) {
        guard case .pairing(let code, _) = pairingState else {
            sendError(code: "not_pairing", message: "Not in pairing mode")
            return
        }

        guard payload.shortCode == code else {
            sendError(code: "invalid_code", message: "Invalid pairing code")
            return
        }

        // Generate shared secret
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let sharedSecret = Data(bytes).base64EncodedString()

        // Save pairing
        let pairing = PairingData(
            deviceId: payload.iosId,
            deviceName: payload.iosName,
            sharedSecret: sharedSecret
        )

        do {
            try KeychainManager.savePairing(pairing, service: keychainService, account: keychainAccount)
            hmacValidator = HMACValidator(sharedSecret: sharedSecret)
            pairingState = .paired(deviceId: payload.iosId, deviceName: payload.iosName)

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

            pairingTimer?.invalidate()
            pairingTimer = nil
        } catch {
            sendError(code: "pairing_failed", message: "Failed to save pairing: \(error)")
        }
    }

    private func sendError(code: String, message: String) {
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

        // Forward validated message to delegate
        delegate?.connectionManager(self, didReceiveMessage: message)
    }

    func server(_ server: WebSocketServer, didChangeState state: ConnectionState) {
        connectionState = state
        delegate?.connectionManager(self, didChangeConnectionState: state)
    }
}
