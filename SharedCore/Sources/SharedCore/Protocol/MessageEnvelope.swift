import Foundation

public struct MessageEnvelope: Codable {
    public let type: MessageType
    public let payload: Data
    public let timestamp: Date
    public let deviceId: String
    public let hmac: String?

    public init(
        type: MessageType,
        payload: Data,
        timestamp: Date,
        deviceId: String,
        hmac: String?
    ) {
        self.type = type
        self.payload = payload
        self.timestamp = timestamp
        self.deviceId = deviceId
        self.hmac = hmac
    }
}
