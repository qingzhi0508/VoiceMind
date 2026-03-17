import Foundation

enum PairingState: Equatable {
    case unpaired
    case pairing(code: String, expiresAt: Date)
    case paired(deviceId: String, deviceName: String)
}
