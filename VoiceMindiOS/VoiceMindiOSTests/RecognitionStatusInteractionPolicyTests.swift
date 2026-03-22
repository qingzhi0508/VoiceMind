import Testing
@testable import VoiceMind

struct RecognitionStatusInteractionPolicyTests {
    @Test
    func manualSendTargetIsDisabled() {
        #expect(
            !RecognitionStatusInteractionPolicy.shouldShowManualSendTarget(
                isPressing: true,
                state: .idle
            )
        )
    }

    @Test
    func interactionRequiresEnabledStateOrReconnectPrompt() {
        #expect(
            RecognitionStatusInteractionPolicy.isInteractionEnabled(
                isEnabled: true,
                showsReconnectAction: false
            )
        )
        #expect(
            RecognitionStatusInteractionPolicy.isInteractionEnabled(
                isEnabled: false,
                showsReconnectAction: true
            )
        )
        #expect(
            !RecognitionStatusInteractionPolicy.isInteractionEnabled(
                isEnabled: false,
                showsReconnectAction: false
            )
        )
    }
}
