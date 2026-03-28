import Testing
@testable import VoiceMind

@MainActor
struct SettingsAppearancePresentationPolicyTests {
    @Test
    func lightThemeShowsBackgroundColorControl() {
        #expect(SettingsAppearancePresentationPolicy.showsLightBackgroundColor(appTheme: "light"))
    }

    @Test
    func systemThemeHidesBackgroundColorControl() {
        #expect(!SettingsAppearancePresentationPolicy.showsLightBackgroundColor(appTheme: "system"))
    }

    @Test
    func darkThemeHidesBackgroundColorControl() {
        #expect(!SettingsAppearancePresentationPolicy.showsLightBackgroundColor(appTheme: "dark"))
    }
}
