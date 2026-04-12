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

    // MARK: - shouldResignFirstResponder (editable mode — never actively resign)

    @Test
    func doesNotResignInEditableModeEvenWhenNotFocused() {
        // IME interaction may cause textViewDidEndEditing → isFocused=false
        // We must NOT actively resign, otherwise IME input is interrupted
        #expect(
            !TranscriptTextViewFocusPolicy.shouldResignFirstResponder(
                isEditable: true,
                isFocused: false,
                isFirstResponder: true,
                hasMarkedText: false
            )
        )
    }

    @Test
    func doesNotResignInEditableModeWhenFocused() {
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

    @Test
    func doesNotResignWhenNotEditableAndNotActive() {
        #expect(
            !TranscriptTextViewFocusPolicy.shouldResignFirstResponder(
                isEditable: false,
                isFocused: false,
                isFirstResponder: false,
                hasMarkedText: false
            )
        )
    }
}
