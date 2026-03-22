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
}
