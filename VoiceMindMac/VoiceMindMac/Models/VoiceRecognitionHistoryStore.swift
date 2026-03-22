import Foundation

enum VoiceRecognitionRecordSource: String, Codable, CaseIterable {
    case localMac
    case iosSync

    var localizedTitleKey: String {
        switch self {
        case .localMac:
            return "records_source_local_mac"
        case .iosSync:
            return "records_source_ios_sync"
        }
    }
}

struct VoiceRecognitionRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let source: VoiceRecognitionRecordSource
    let createdAt: Date
}

enum VoiceRecognitionHistoryQueryPolicy {
    static let retentionDays = 30

    static func matches(_ record: VoiceRecognitionRecord, keyword: String) -> Bool {
        let normalizedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKeyword.isEmpty else { return true }
        return record.text.localizedCaseInsensitiveContains(normalizedKeyword)
    }

    static func filteredRecords(
        from records: [VoiceRecognitionRecord],
        referenceDate: Date,
        keyword: String,
        calendar: Calendar = .current
    ) -> [VoiceRecognitionRecord] {
        let cutoffDate = calendar.date(byAdding: .day, value: -retentionDays, to: referenceDate) ?? referenceDate
        return records
            .filter { $0.createdAt >= cutoffDate }
            .filter { matches($0, keyword: keyword) }
            .sorted { $0.createdAt > $1.createdAt }
    }
}

struct VoiceRecognitionHistoryStore {
    private let fileURL: URL
    private let fileManager: FileManager
    private let calendar: Calendar

    init(
        fileURL: URL = VoiceRecognitionHistoryStore.defaultFileURL(),
        fileManager: FileManager = .default,
        calendar: Calendar = .current
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        self.calendar = calendar
    }

    func append(
        text: String,
        source: VoiceRecognitionRecordSource,
        createdAt: Date = .now
    ) throws {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else { return }

        var records = try loadAllRecords()
        records.append(
            VoiceRecognitionRecord(
                id: UUID(),
                text: normalizedText,
                source: source,
                createdAt: createdAt
            )
        )

        let prunedRecords = VoiceRecognitionHistoryQueryPolicy.filteredRecords(
            from: records,
            referenceDate: createdAt,
            keyword: "",
            calendar: calendar
        )
        try save(prunedRecords)
    }

    func loadRecentRecords(referenceDate: Date = .now) throws -> [VoiceRecognitionRecord] {
        let records = try loadAllRecords()
        return VoiceRecognitionHistoryQueryPolicy.filteredRecords(
            from: records,
            referenceDate: referenceDate,
            keyword: "",
            calendar: calendar
        )
    }

    func deleteRecords(withIDs ids: Set<UUID>) throws {
        guard !ids.isEmpty else { return }
        let records = try loadAllRecords()
        let remainingRecords = records.filter { !ids.contains($0.id) }
        try save(remainingRecords)
    }

    func clearRecentRecords() throws {
        try save([])
    }

    private func loadAllRecords() throws -> [VoiceRecognitionRecord] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else { return [] }
        return try makeDecoder().decode([VoiceRecognitionRecord].self, from: data)
    }

    private func save(_ records: [VoiceRecognitionRecord]) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try makeEncoder().encode(records)
        try data.write(to: fileURL, options: .atomic)
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func defaultFileURL() -> URL {
        let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return applicationSupportURL
            .appendingPathComponent("VoiceMind", isDirectory: true)
            .appendingPathComponent("voice-recognition-history.json")
    }
}
