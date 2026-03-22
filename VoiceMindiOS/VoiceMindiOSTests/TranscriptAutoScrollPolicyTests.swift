import Testing
@testable import VoiceMind

struct TranscriptAutoScrollPolicyTests {
    @Test
    func doesNotAutoScrollWhenContentIsBelowHalfHeight() {
        #expect(
            !TranscriptAutoScrollPolicy.shouldAutoScroll(
                contentHeight: 50,
                visibleHeight: 120
            )
        )
    }

    @Test
    func autoScrollsWhenContentExceedsHalfHeight() {
        #expect(
            TranscriptAutoScrollPolicy.shouldAutoScroll(
                contentHeight: 70,
                visibleHeight: 120
            )
        )
    }
}
