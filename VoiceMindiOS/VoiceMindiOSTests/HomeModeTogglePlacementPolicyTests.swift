import Testing
@testable import VoiceMind

struct HomeModeTogglePlacementPolicyTests {
    @Test
    func bottomToggleIsOnlyVisibleWhenMacCollaborationIsEnabled() {
        #expect(!HomeModeTogglePlacementPolicy.shouldShowBottomToggle(sendToMacEnabled: false))
        #expect(HomeModeTogglePlacementPolicy.shouldShowBottomToggle(sendToMacEnabled: true))
    }

    @Test
    func bottomToggleUsesOnlyModeIcons() {
        #expect(HomeModeTogglePlacementPolicy.systemImage(for: .local) == "desktopcomputer")
        #expect(HomeModeTogglePlacementPolicy.systemImage(for: .mac) == "iphone")
    }

    @Test
    func bottomToggleUsesRainbowAccentStyle() {
        #expect(HomeModeTogglePlacementPolicy.usesRainbowAccent)
    }
}
