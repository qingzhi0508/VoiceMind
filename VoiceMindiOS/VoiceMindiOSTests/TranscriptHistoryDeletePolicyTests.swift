import Testing
import SwiftUI
@testable import VoiceMind

struct TranscriptHistoryDeletePolicyTests {
    @Test
    func usesTrailingSwipeForSystemDeletePattern() {
        #expect(TranscriptHistoryDeletePolicy.usesTrailingSwipe)
    }

    @Test
    func usesLeadingSwipeForSendWhenMacIsConnected() {
        #expect(TranscriptHistorySendPolicy.swipeEdge == .leading)
        #expect(TranscriptHistorySendPolicy.usesLeadingSwipe)
        #expect(!TranscriptHistorySendPolicy.allowsFullSwipe)
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
