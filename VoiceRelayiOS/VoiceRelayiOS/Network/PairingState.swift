import Foundation

enum PairingState {
    case unpaired
    case pairing(code: String, expiresAt: Date)
    case paired(deviceId: String, deviceName: String)
}
