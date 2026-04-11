import XCTest
import SharedCore
@testable import VoiceMind

final class KeywordActionRoutingPolicyTests: XCTestCase {
    // MARK: - KeywordActionRoutingPolicy

    func testConfirmRoutesToSimulateReturn() {
        let result = KeywordActionRoutingPolicy.route(.confirm)
        XCTAssertEqual(result, .simulateReturn)
    }

    func testUndoRoutesToSelectAndDelete() {
        let result = KeywordActionRoutingPolicy.route(.undo)
        XCTAssertEqual(result, .selectAndDelete)
    }

    // MARK: - VoiceInboundLogPolicy for keyword

    func testKeywordEnvelopeSkipsInboundLog() {
        XCTAssertFalse(VoiceInboundLogPolicy.shouldAppendInboundRecord(for: .keyword))
    }
}
