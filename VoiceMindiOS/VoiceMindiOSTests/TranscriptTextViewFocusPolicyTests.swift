import Testing
@testable import VoiceMind

struct TranscriptTextViewFocusPolicyTests {
    // MARK: - shouldBecomeFirstResponder

    @Test
    func becomesFirstResponderWhenEditableFocusedAndNotActive() {
        #expect(
            TranscriptTextViewFocusPolicy.shouldBecomeFirstResponder(
                isEditable: true,
                isFocused: true,
                isFirstResponder: false
            )
        )
    }

    @Test
    func doesNotBecomeFirstResponderWhenNotEditable() {
        #expect(
            !TranscriptTextViewFocusPolicy.shouldBecomeFirstResponder(
                isEditable: true,
                isFocused: true,
                isFirstResponder: true
            )
        )
    }

    @Test
    func doesNotBecomeFirstResponderWhenAlreadyActive() {
        #expect(
            !TranscriptTextViewFocusPolicy.shouldBecomeFirstResponder(
                isEditable: true,
                isFocused: true,
                isFirstResponder: true
            )
        )
    }

    @Test
    func doesNotBecomeFirstResponderWhenNotFocused() {
        #expect(
            !TranscriptTextViewFocusPolicy.shouldBecomeFirstResponder(
                isEditable: true,
                isFocused: false,
                isFirstResponder: false
            )
        )
    }

    // MARK: - shouldResignFirstResponder (editable mode)

    @Test
    func resignsWhenEditableNotFocusedAndActive() {
        #expect(
            TranscriptTextViewFocusPolicy.shouldResignFirstResponder(
                isEditable: true,
                isFocused: false,
                isFirstResponder: true,
                hasMarkedText: false
            )
        )
    }

    @Test
    func doesNotResignWhenEditableNotFocusedButHasMarkedText() {
        #expect(
            !TranscriptTextViewFocusPolicy.shouldResignFirstResponder(
                isEditable: true,
                isFocused: false,
                isFirstResponder: true,
                hasMarkedText: true
            )
        )
    }

    @Test
    func doesNotResignWhenEditableNotFocusedButNotActive() {
        #expect(
            !TranscriptTextViewFocusPolicy.shouldResignFirstResponder(
                isEditable: true,
                isFocused: false,
                isFirstResponder: false,
                hasMarkedText: false
            )
        )
    }

    @Test
    func doesNotResignWhenEditableAndStillFocused() {
        #expect(
            !TranscriptTextViewFocusPolicy.shouldResignFirstResponder(
                isEditable: true,
                isFocused: true,
                isFirstResponder: true,
                hasMarkedText: false
            )
        )
    }

    // MARK: - shouldResignFirstResponder (non-editable mode)

    @Test
    func resignsWhenNotEditableAndActive() {
        #expect(
            TranscriptTextViewFocusPolicy.shouldResignFirstResponder(
                isEditable: false,
                isFocused: false,
                isFirstResponder: true,
                hasMarkedText: false
            )
        )
    }

    @Test
    func doesNotResignWhenNotEditableButHasMarkedText() {
        #expect(
            !TranscriptTextViewFocusPolicy.shouldResignFirstResponder(
                isEditable: false,
                isFocused: false,
                isFirstResponder: true,
                hasMarkedText: true
            )
        )
    }
}
