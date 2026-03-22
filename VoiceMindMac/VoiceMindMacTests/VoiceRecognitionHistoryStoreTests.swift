import XCTest
@testable import VoiceMind

final class VoiceRecognitionHistoryStoreTests: XCTestCase {
    func testDeleteRecordsRemovesOnlySelectedItems() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let fileURL = tempDirectory.appendingPathComponent("voice-history.json")
        let store = VoiceRecognitionHistoryStore(fileURL: fileURL)
        let now = Date(timeIntervalSince1970: 1_710_000_000)

        try store.append(text: "keep first", source: .localMac, createdAt: now.addingTimeInterval(-300))
        try store.append(text: "delete me", source: .iosSync, createdAt: now.addingTimeInterval(-200))
        try store.append(text: "keep last", source: .localMac, createdAt: now.addingTimeInterval(-100))

        let beforeDelete = try store.loadRecentRecords(referenceDate: now)
        let deleteID = try XCTUnwrap(beforeDelete.first(where: { $0.text == "delete me" })?.id)

        try store.deleteRecords(withIDs: [deleteID])

        let remainingRecords = try store.loadRecentRecords(referenceDate: now)
        XCTAssertEqual(remainingRecords.map(\.text), ["keep last", "keep first"])
    }

    func testClearRecentRecordsRemovesAllPersistedItems() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let fileURL = tempDirectory.appendingPathComponent("voice-history.json")
        let store = VoiceRecognitionHistoryStore(fileURL: fileURL)

        try store.append(text: "mac final text", source: .localMac, createdAt: .now)
        try store.append(text: "iphone synced text", source: .iosSync, createdAt: .now)

        try store.clearRecentRecords()

        let records = try store.loadRecentRecords(referenceDate: .now)
        XCTAssertTrue(records.isEmpty)
    }

    func testLoadRecentRecordsKeepsOnlyLast30DaysAndSortsNewestFirst() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let store = VoiceRecognitionHistoryStore(
            fileURL: tempDirectory.appendingPathComponent("voice-history.json")
        )
        let now = Date(timeIntervalSince1970: 1_710_000_000)

        try store.append(
            text: "31 days ago",
            source: .localMac,
            createdAt: now.addingTimeInterval(-31 * 24 * 60 * 60)
        )
        try store.append(
            text: "recent iphone",
            source: .iosSync,
            createdAt: now.addingTimeInterval(-2 * 24 * 60 * 60)
        )
        try store.append(
            text: "recent mac",
            source: .localMac,
            createdAt: now.addingTimeInterval(-60)
        )

        let records = try store.loadRecentRecords(referenceDate: now)

        XCTAssertEqual(records.map(\.text), ["recent mac", "recent iphone"])
        XCTAssertEqual(records.map(\.source), [.localMac, .iosSync])
    }

    func testAppendPersistsRecordsForBothSources() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let fileURL = tempDirectory.appendingPathComponent("voice-history.json")
        let writer = VoiceRecognitionHistoryStore(fileURL: fileURL)

        try writer.append(text: "mac final text", source: .localMac, createdAt: .now)
        try writer.append(text: "iphone synced text", source: .iosSync, createdAt: .now)

        let reader = VoiceRecognitionHistoryStore(fileURL: fileURL)
        let records = try reader.loadRecentRecords(referenceDate: .now)

        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(Set(records.map(\.source)), [.localMac, .iosSync])
    }
}
