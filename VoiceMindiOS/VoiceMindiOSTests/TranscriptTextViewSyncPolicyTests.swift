import Testing
@testable import VoiceMind

struct TranscriptTextViewSyncPolicyTests {
    @Test
    func skipsExternalTextWriteWhileComposingMarkedText() {
        #expect(
            !TranscriptTextViewSyncPolicy.shouldApplyExternalText(
                currentText: "ni",
                newText: "ni",
                isFirstResponder: true,
                hasMarkedText: true
            )
        )
    }

    @Test
    func appliesExternalTextWhenNotComposing() {
        #expect(
            TranscriptTextViewSyncPolicy.shouldApplyExternalText(
                currentText: "old",
                newText: "new",
                isFirstResponder: true,
                hasMarkedText: false
            )
        )
    }
}
