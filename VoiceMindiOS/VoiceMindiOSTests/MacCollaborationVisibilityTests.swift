import Testing
@testable import VoiceMind

struct MacCollaborationVisibilityTests {
    @Test
    func pairingOptionsAreHiddenWhenMacCollaborationIsDisabled() {
        #expect(!LocalTranscriptionPolicy.shouldShowMacPairingOptions(sendToMacEnabled: false))
    }

    @Test
    func pairingOptionsAreVisibleWhenMacCollaborationIsEnabled() {
        #expect(LocalTranscriptionPolicy.shouldShowMacPairingOptions(sendToMacEnabled: true))
    }
}
