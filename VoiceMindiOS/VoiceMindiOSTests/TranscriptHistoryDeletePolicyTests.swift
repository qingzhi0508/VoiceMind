import Testing
@testable import VoiceMind

struct TranscriptHistoryDeletePolicyTests {
    @Test
    func usesTrailingSwipeForSystemDeletePattern() {
        #expect(TranscriptHistoryDeletePolicy.usesTrailingSwipe)
    }

    @Test
    func allowsFullSwipeForImmediateDelete() {
        #expect(TranscriptHistoryDeletePolicy.allowsFullSwipe)
    }

    @Test
    func skipsConfirmationAlertForDirectDelete() {
        #expect(!TranscriptHistoryDeletePolicy.requiresConfirmation)
    }
}
