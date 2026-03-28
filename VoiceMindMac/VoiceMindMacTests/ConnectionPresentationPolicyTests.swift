import XCTest
@testable import VoiceMind

final class ConnectionPresentationPolicyTests: XCTestCase {
    func testUnpairedSocketConnectionDoesNotPresentAsConnected() {
        let state = MacConnectionPresentationPolicy.displayState(
            pairingState: .unpaired,
            connectionState: .connected
        )

        guard case .disconnected = state else {
            return XCTFail("Expected unpaired socket connection to present as disconnected")
        }
    }

    func testPairedConnectionKeepsUnderlyingConnectedState() {
        let state = MacConnectionPresentationPolicy.displayState(
            pairingState: .paired(deviceId: "ios-1", deviceName: "cayden"),
            connectionState: .connected
        )

        guard case .connected = state else {
            return XCTFail("Expected paired connection to remain connected")
        }
    }
}
