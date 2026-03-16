import Foundation

public struct PairingData: Codable {
    public let deviceId: String
    public let deviceName: String
    public let sharedSecret: String

    public init(deviceId: String, deviceName: String, sharedSecret: String) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.sharedSecret = sharedSecret
    }
}
