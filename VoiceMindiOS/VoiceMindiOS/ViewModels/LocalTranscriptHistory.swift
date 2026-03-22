import Foundation

struct LocalTranscriptRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let language: String
    let createdAt: Date
}

enum LocalTranscriptHistory {
    static func appending(
        text: String,
        language: String,
        to history: [LocalTranscriptRecord],
        now: Date = Date()
    ) -> [LocalTranscriptRecord] {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return history }

        let record = LocalTranscriptRecord(
            id: UUID(),
            text: trimmedText,
            language: language,
            createdAt: now
        )

        return Array(([record] + history).prefix(10))
    }

    static func removing(
        id: UUID,
        from history: [LocalTranscriptRecord]
    ) -> [LocalTranscriptRecord] {
        history.filter { $0.id != id }
    }

    static func updating(
        id: UUID,
        text: String,
        in history: [LocalTranscriptRecord]
    ) -> [LocalTranscriptRecord] {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        return history.map { record in
            guard record.id == id else { return record }
            let nextText = trimmedText.isEmpty ? record.text : trimmedText
            return LocalTranscriptRecord(
                id: record.id,
                text: nextText,
                language: record.language,
                createdAt: record.createdAt
            )
        }
    }

    static func appendingLatestTranscript(
        _ latestText: String,
        to existingText: String
    ) -> String {
        let trimmedLatest = latestText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedExisting = existingText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedLatest.isEmpty else { return trimmedExisting }
        guard !trimmedExisting.isEmpty else { return trimmedLatest }

        return "\(trimmedExisting)\n\n\(trimmedLatest)"
    }

    static func renderingActiveTranscript(
        committedText: String,
        liveTranscriptText: String
    ) -> String {
        let trimmedCommitted = committedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLive = liveTranscriptText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedLive.isEmpty else { return trimmedCommitted }
        guard !trimmedCommitted.isEmpty else { return trimmedLive }

        return "\(trimmedCommitted)\n\n\(trimmedLive)"
    }

    static func beginningNewRecognitionSession(from _: String) -> String {
        ""
    }
}
