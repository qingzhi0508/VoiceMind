import Testing
@testable import VoiceMind

struct TranscriptHistoryBatchDeletePolicyTests {
    @Test
    func batchDeleteRequiresSelection() {
        #expect(
            !TranscriptHistoryBatchDeletePolicy.canDeleteSelectedRecords(
                selectedRecordIDs: []
            )
        )
        #expect(
            TranscriptHistoryBatchDeletePolicy.canDeleteSelectedRecords(
                selectedRecordIDs: ["a", "b"]
            )
        )
    }

    @Test
    func batchDeleteActionTitleUsesSelectionCount() {
        #expect(
            TranscriptHistoryBatchDeletePolicy.selectedDeleteCount(
                selectedRecordIDs: ["a", "b", "c"]
            ) == 3
        )
    }
}
