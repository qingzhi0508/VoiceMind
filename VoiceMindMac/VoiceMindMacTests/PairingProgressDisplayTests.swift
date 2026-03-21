import XCTest
@testable import VoiceMind

final class PairingProgressDisplayTests: XCTestCase {
    func testConnectedPairedStateOverridesStaleProgressMessage() {
        let message = PairingProgressDisplay.message(
            pairingState: .paired(deviceId: "ios-1", deviceName: "cayden"),
            connectionState: .connected,
            progressMessage: "已生成配对码，等待 iPhone 扫描二维码或输入配对码。"
        )

        XCTAssertEqual(message, "已完成配对，cayden 已连接，可以开始使用。")
    }

    func testPairingStateKeepsLiveProgressMessage() {
        let message = PairingProgressDisplay.message(
            pairingState: .pairing(code: "123456", expiresAt: .distantFuture),
            connectionState: .disconnected,
            progressMessage: "已收到来自 cayden 的配对请求。"
        )

        XCTAssertEqual(message, "已收到来自 cayden 的配对请求。")
    }
}
