import Testing
@testable import VoiceMind

struct AppBackgroundStylePolicyTests {
    @Test
    func lightModeUsesMutedMistBackground() {
        #expect(AppBackgroundStylePolicy.usesMutedMistBackground(forDarkMode: false))
        #expect(AppBackgroundStylePolicy.showsRainbowBubbles(forDarkMode: false))
        #expect(AppBackgroundStylePolicy.usesModernGlassSurfaces)
    }

    @Test
    func darkModeKeepsExistingSystemStyle() {
        #expect(!AppBackgroundStylePolicy.usesMutedMistBackground(forDarkMode: true))
        #expect(!AppBackgroundStylePolicy.showsRainbowBubbles(forDarkMode: true))
    }
}
