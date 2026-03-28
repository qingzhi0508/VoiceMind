import Testing
@testable import VoiceMind

struct TranscriptHistoryEmptyStateLayoutPolicyTests {
    @Test
    func emptyHistoryStateDoesNotUseCardSurface() {
        #expect(!TranscriptHistoryEmptyStateLayoutPolicy.usesCardSurface)
    }
}
