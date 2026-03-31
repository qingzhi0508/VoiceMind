import Testing
import SwiftUI
@testable import VoiceMind

struct AppChromeStylePolicyTests {
    @Test
    func explicitLightThemeUsesTintedChromeHex() {
        #expect(
            AppChromeStylePolicy.barBackgroundHex(
                appTheme: "light",
                colorScheme: .light,
                storedHex: "#F5EC00"
            ) == "#F5EC00"
        )
    }

    @Test
    func explicitLightThemeNormalizesChromeHex() {
        #expect(
            AppChromeStylePolicy.barBackgroundHex(
                appTheme: "light",
                colorScheme: .light,
                storedHex: "f5ec00"
            ) == "#F5EC00"
        )
    }

    @Test
    func systemAndDarkThemesKeepSystemChrome() {
        #expect(
            AppChromeStylePolicy.barBackgroundHex(
                appTheme: "system",
                colorScheme: .light,
                storedHex: "#F5EC00"
            ) == nil
        )
        #expect(
            AppChromeStylePolicy.barBackgroundHex(
                appTheme: "dark",
                colorScheme: .dark,
                storedHex: "#F5EC00"
            ) == nil
        )
    }
}
