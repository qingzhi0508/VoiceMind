import Testing
@testable import VoiceMind

struct HomeModeTogglePlacementPolicyTests {
    @Test
    func modeSelectorIsOnlyVisibleWhenMacCollaborationIsEnabled() {
        #expect(!HomeModeTogglePlacementPolicy.shouldShowModeSelector(sendToMacEnabled: false))
        #expect(HomeModeTogglePlacementPolicy.shouldShowModeSelector(sendToMacEnabled: true))
    }
}
