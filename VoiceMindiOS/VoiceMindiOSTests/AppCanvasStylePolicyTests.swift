import Testing
import SwiftUI
@testable import VoiceMind

struct AppCanvasStylePolicyTests {
    @Test
    func explicitLightThemeUsesCustomCanvasHex() {
        #expect(
            AppCanvasStylePolicy.backgroundHex(
                appTheme: "light",
                colorScheme: .light,
                storedHex: "#F5EC00"
            ) == "#F5EC00"
        )
    }

    @Test
    func explicitLightThemeNormalizesCanvasHex() {
        #expect(
            AppCanvasStylePolicy.backgroundHex(
                appTheme: "light",
                colorScheme: .light,
                storedHex: "f5ec00"
            ) == "#F5EC00"
        )
    }

    @Test
    func systemAndDarkThemesDoNotUseCustomCanvasHex() {
        #expect(
            AppCanvasStylePolicy.backgroundHex(
                appTheme: "system",
                colorScheme: .light,
                storedHex: "#F5EC00"
            ) == nil
        )
        #expect(
            AppCanvasStylePolicy.backgroundHex(
                appTheme: "dark",
                colorScheme: .dark,
                storedHex: "#F5EC00"
            ) == nil
        )
    }
}
