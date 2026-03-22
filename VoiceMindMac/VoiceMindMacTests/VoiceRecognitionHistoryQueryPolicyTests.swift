import XCTest
@testable import VoiceMind

final class VoiceRecognitionHistoryQueryPolicyTests: XCTestCase {
    func testMatchesSearchKeywordAgainstTranscriptText() {
        let record = VoiceRecognitionRecord(
            id: UUID(),
            text: "今天开会确认了发版时间",
            source: .localMac,
            createdAt: .now
        )

        XCTAssertTrue(VoiceRecognitionHistoryQueryPolicy.matches(record, keyword: "发版"))
        XCTAssertFalse(VoiceRecognitionHistoryQueryPolicy.matches(record, keyword: "报销"))
    }
}
