import XCTest
@testable import VoiceMind

final class MenuBarStatusPresentationTests: XCTestCase {
    func testConnectedStateUsesShortStatusInMenuBar() {
        let presentation = MenuBarStatusPresentation(
            pairingState: .paired(deviceId: "ios-1", deviceName: "cayden"),
            connectionState: .connected
        )

        XCTAssertEqual(presentation.buttonTitle, "已连接")
        XCTAssertEqual(presentation.menuStatusTitle, "已连接到 cayden")
        XCTAssertTrue(presentation.showsUnpairAction)
    }

    func testPairedButDisconnectedDoesNotClaimConnectedInMenuBar() {
        let presentation = MenuBarStatusPresentation(
            pairingState: .paired(deviceId: "ios-1", deviceName: "cayden"),
            connectionState: .disconnected
        )

        XCTAssertEqual(presentation.buttonTitle, "语灵")
        XCTAssertEqual(presentation.menuStatusTitle, "已配对但未连接")
        XCTAssertTrue(presentation.showsUnpairAction)
    }

    func testPairingStateShowsProgressStatus() {
        let presentation = MenuBarStatusPresentation(
            pairingState: .pairing(code: "123456", expiresAt: .distantFuture),
            connectionState: .connecting
        )

        XCTAssertEqual(presentation.buttonTitle, "语灵")
        XCTAssertEqual(presentation.menuStatusTitle, "配对中...")
        XCTAssertFalse(presentation.showsUnpairAction)
    }
}
