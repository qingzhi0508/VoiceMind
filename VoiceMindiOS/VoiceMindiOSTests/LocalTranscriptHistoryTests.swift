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

    @Test
    func updatingTranscriptReplacesMatchingRecordAndKeepsOrder() {
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

        let history = LocalTranscriptHistory.updating(
            id: second.id,
            text: "updated second",
            in: [second, first]
        )

        #expect(history.map(\.text) == ["updated second", "first"])
        #expect(history[0].createdAt == second.createdAt)
    }

    @Test
    func updatingTranscriptWithBlankTextKeepsOriginalRecordText() {
        let record = LocalTranscriptRecord(
            id: UUID(),
            text: "original",
            language: "zh-CN",
            createdAt: Date(timeIntervalSince1970: 1)
        )

        let history = LocalTranscriptHistory.updating(
            id: record.id,
            text: "   ",
            in: [record]
        )

        #expect(history.first?.text == "original")
    }

    @Test
    func appendingLatestTranscriptPlacesNewestTextAtBottom() {
        let combined = LocalTranscriptHistory.appendingLatestTranscript(
            "latest",
            to: "older line"
        )

        #expect(combined == "older line\n\nlatest")
    }

    @Test
    func renderingActiveTranscriptAppendsLiveDraftWithoutDuplicatingCommittedText() {
        let combined = LocalTranscriptHistory.renderingActiveTranscript(
            committedText: "older line",
            liveTranscriptText: "latest draft"
        )

        #expect(combined == "older line\n\nlatest draft")
    }

    @Test
    func renderingActiveTranscriptKeepsCommittedTextWhenDraftIsEmpty() {
        let combined = LocalTranscriptHistory.renderingActiveTranscript(
            committedText: "older line",
            liveTranscriptText: "   "
        )

        #expect(combined == "older line")
    }

    @Test
    func beginningNewRecognitionSessionClearsPreviousTranscript() {
        let cleared = LocalTranscriptHistory.beginningNewRecognitionSession(
            from: "previous transcript"
        )

        #expect(cleared.isEmpty)
    }
}
