import XCTest
import SharedCore
@testable import VoiceMind

final class KeywordActionRoutingPolicyTests: XCTestCase {
    // MARK: - KeywordActionRoutingPolicy

    func testConfirmRoutesToSimulateReturn() {
        let result = KeywordActionRoutingPolicy.route(.confirm)
        XCTAssertEqual(result, .simulateReturn)
    }

    func testUndoRoutesToSimulateUndo() {
        let result = KeywordActionRoutingPolicy.route(.undo)
        XCTAssertEqual(result, .simulateUndo)
    }

    // MARK: - VoiceInboundLogPolicy for keyword

    func testKeywordEnvelopeSkipsInboundLog() {
        XCTAssertFalse(VoiceInboundLogPolicy.shouldAppendInboundRecord(for: .keyword))
    }
}
