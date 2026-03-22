import Testing
@testable import VoiceMind

struct ContentInteractionPolicyTests {
    @Test
    func backgroundTapDismissesKeyboardWhileTranscriptEditorIsFocused() {
        #expect(
            ContentInteractionPolicy.shouldDismissKeyboardOnBackgroundTap(
                isTranscriptEditorFocused: true
            )
        )
    }

    @Test
    func backgroundTapDoesNothingWhenTranscriptEditorIsNotFocused() {
        #expect(
            !ContentInteractionPolicy.shouldDismissKeyboardOnBackgroundTap(
                isTranscriptEditorFocused: false
            )
        )
    }
}
