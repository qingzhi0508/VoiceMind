import XCTest
@testable import VoiceMind

@MainActor
final class SpeechRecognitionEngineListStoreTests: XCTestCase {
    func testReloadUpdatesSnapshot() {
        let emptyState = EngineSnapshot(engines: [], selectedEngineId: "")
        let loadedState = EngineSnapshot(
            engines: [MockSpeechEngine()],
            selectedEngineId: "mock-engine"
        )
        let snapshots = [emptyState, loadedState]
        var snapshotIndex = 0

        let store = SpeechRecognitionEngineListStore(
            snapshotProvider: {
                let snapshot = snapshots[min(snapshotIndex, snapshots.count - 1)]
                snapshotIndex += 1
                return snapshot
            }
        )

        XCTAssertTrue(store.availableEngines.isEmpty)
        XCTAssertEqual(store.selectedEngineId, "")

        store.reload()

        XCTAssertEqual(store.availableEngines.map(\.identifier), ["mock-engine"])
        XCTAssertEqual(store.selectedEngineId, "mock-engine")
    }
}
