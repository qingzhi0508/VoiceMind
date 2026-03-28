import XCTest
import SharedCore
@testable import VoiceMind

final class VoiceInboundLogPolicyTests: XCTestCase {
    func testResultEnvelopeSkipsDuplicateInboundLog() {
        XCTAssertFalse(VoiceInboundLogPolicy.shouldAppendInboundRecord(for: .result))
    }

    func testTextMessageEnvelopeStillAppendsInboundLog() {
        XCTAssertTrue(VoiceInboundLogPolicy.shouldAppendInboundRecord(for: .textMessage))
    }
}
