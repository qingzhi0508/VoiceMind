import XCTest
@testable import VoiceMind

final class CollaborationControlsPolicyTests: XCTestCase {
    func testUnpairedStateShowsPairingAction() {
        let policy = CollaborationControlsPolicy(
            pairingState: .unpaired,
            isServiceRunning: true
        )

        XCTAssertTrue(policy.showsStartPairing)
        XCTAssertFalse(policy.showsUnpair)
    }

    func testPairedStateShowsUnpairAction() {
        let policy = CollaborationControlsPolicy(
            pairingState: .paired(deviceId: "ios-1", deviceName: "cayden"),
            isServiceRunning: true
        )

        XCTAssertFalse(policy.showsStartPairing)
        XCTAssertTrue(policy.showsUnpair)
    }
}
