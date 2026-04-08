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
        #expect(HomeModeTogglePlacementPolicy.systemImage(for: .local) == "iphone")
        #expect(HomeModeTogglePlacementPolicy.systemImage(for: .mac) == "desktopcomputer")
    }

    @Test
    func bottomToggleUsesRainbowAccentStyle() {
        #expect(HomeModeTogglePlacementPolicy.usesRainbowAccent)
    }
}
