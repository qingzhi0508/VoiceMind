import Foundation

public struct ConnectionInfo: Codable {
    public let ip: String
    public let port: UInt16
    public let deviceId: String
    public let deviceName: String

    public init(ip: String, port: UInt16, deviceId: String, deviceName: String) {
        self.ip = ip
        self.port = port
        self.deviceId = deviceId
        self.deviceName = deviceName
    }

    public func toQRCodeString() -> String? {
        guard let data = try? JSONEncoder().encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return json
    }

    public static func fromQRCodeString(_ string: String) -> ConnectionInfo? {
        guard let data = string.data(using: .utf8),
              let info = try? JSONDecoder().decode(ConnectionInfo.self, from: data) else {
            return nil
        }
        return info
    }
}
