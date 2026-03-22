import Testing
@testable import VoiceMind

struct TranscriptHistoryEditingPolicyTests {
    @Test
    func backgroundTapAutoSavesWhenEditing() {
        #expect(TranscriptHistoryEditingPolicy.shouldAutoSaveOnBackgroundTap(isEditing: true))
    }

    @Test
    func backgroundTapDoesNothingWhenNotEditing() {
        #expect(!TranscriptHistoryEditingPolicy.shouldAutoSaveOnBackgroundTap(isEditing: false))
    }

    @Test
    func savedTextUsesTrimmedDraftWhenNonEmpty() {
        #expect(
            TranscriptHistoryEditingPolicy.savedText(
                originalText: "original",
                draftText: "  updated  "
            ) == "updated"
        )
    }

    @Test
    func savedTextFallsBackToOriginalWhenDraftIsBlank() {
        #expect(
            TranscriptHistoryEditingPolicy.savedText(
                originalText: "original",
                draftText: "   "
            ) == "original"
        )
    }
}
