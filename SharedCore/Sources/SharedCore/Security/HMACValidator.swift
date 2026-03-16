import Foundation
import CryptoKit

public class HMACValidator {
    private let key: SymmetricKey

    public init(key: SymmetricKey) {
        self.key = key
    }

    public convenience init(sharedSecret: String) {
        let data = Data(sharedSecret.utf8)
        let key = SymmetricKey(data: data)
        self.init(key: key)
    }

    public func generateHMAC(for message: String) -> String {
        let data = Data(message.utf8)
        let hmac = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return hmac.map { String(format: "%02x", $0) }.joined()
    }

    public func validateHMAC(_ hmac: String, for message: String) -> Bool {
        let expectedHMAC = generateHMAC(for: message)
        return hmac == expectedHMAC
    }

    public func generateHMACForEnvelope(
        type: MessageType,
        payload: Data,
        timestamp: Date,
        deviceId: String
    ) -> String {
        let message = "\(type.rawValue)\(payload.base64EncodedString())\(timestamp.timeIntervalSince1970)\(deviceId)"
        return generateHMAC(for: message)
    }

    public func validateEnvelopeHMAC(_ envelope: MessageEnvelope) -> Bool {
        guard let hmac = envelope.hmac else { return false }
        let expectedHMAC = generateHMACForEnvelope(
            type: envelope.type,
            payload: envelope.payload,
            timestamp: envelope.timestamp,
            deviceId: envelope.deviceId
        )
        return hmac == expectedHMAC
    }
}
