import Foundation
import Testing
@testable import VoiceMind

struct LocalTranscriptHistoryTests {
    @Test
    func appendingTranscriptKeepsNewestTenRecords() {
        var history: [LocalTranscriptRecord] = []

        for index in 1...11 {
            history = LocalTranscriptHistory.appending(
                text: "record-\(index)",
                language: "zh-CN",
                to: history,
                now: Date(timeIntervalSince1970: Double(index))
            )
        }

        #expect(history.count == 10)
        #expect(history.first?.text == "record-11")
        #expect(history.last?.text == "record-2")
    }

    @Test
    func appendingBlankTranscriptDoesNothing() {
        let original = [
            LocalTranscriptRecord(
                id: UUID(),
                text: "existing",
                language: "zh-CN",
                createdAt: Date(timeIntervalSince1970: 1)
            )
        ]

        let history = LocalTranscriptHistory.appending(
            text: "   ",
            language: "zh-CN",
            to: original,
            now: Date(timeIntervalSince1970: 2)
        )

        #expect(history == original)
    }

    @Test
    func removingTranscriptDeletesMatchingRecordAndKeepsOrder() {
        let first = LocalTranscriptRecord(
            id: UUID(),
            text: "first",
            language: "zh-CN",
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let second = LocalTranscriptRecord(
            id: UUID(),
            text: "second",
            language: "zh-CN",
            createdAt: Date(timeIntervalSince1970: 2)
        )
        let third = LocalTranscriptRecord(
            id: UUID(),
            text: "third",
            language: "zh-CN",
            createdAt: Date(timeIntervalSince1970: 3)
        )

        let history = LocalTranscriptHistory.removing(
            id: second.id,
            from: [third, second, first]
        )

        #expect(history.map { $0.text } == ["third", "first"])
    }
}
