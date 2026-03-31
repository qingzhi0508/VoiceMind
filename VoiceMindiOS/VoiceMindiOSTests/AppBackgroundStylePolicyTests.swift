import Testing
import SwiftUI
@testable import VoiceMind

struct AppBackgroundStylePolicyTests {
    @Test
    func explicitLightThemeUsesDefaultBackgroundTintWhenNoStoredValueExists() {
        #expect(
            AppLightBackgroundTintPolicy.effectiveHex(
                appTheme: "light",
                colorScheme: .light,
                storedHex: nil
            ) == AppLightBackgroundTintPolicy.defaultHex
        )
    }

    @Test
    func explicitLightThemeUsesNormalizedStoredBackgroundTint() {
        #expect(
            AppLightBackgroundTintPolicy.effectiveHex(
                appTheme: "light",
                colorScheme: .light,
                storedHex: "66bdc9"
            ) == "#66BDC9"
        )
    }

    @Test
    func explicitLightThemeFallsBackToDefaultBackgroundTintForInvalidStoredValue() {
        #expect(
            AppLightBackgroundTintPolicy.effectiveHex(
                appTheme: "light",
                colorScheme: .light,
                storedHex: "not-a-color"
            ) == AppLightBackgroundTintPolicy.defaultHex
        )
    }

    @Test
    func systemAndDarkThemesIgnoreStoredLightBackgroundTint() {
        #expect(
            AppLightBackgroundTintPolicy.effectiveHex(
                appTheme: "system",
                colorScheme: .light,
                storedHex: "#FF0000"
            ) == nil
        )
        #expect(
            AppLightBackgroundTintPolicy.effectiveHex(
                appTheme: "dark",
                colorScheme: .dark,
                storedHex: "#FF0000"
            ) == nil
        )
    }

    @Test
    func explicitLightThemeUsesSkyPopVisualStyle() {
        #expect(
            AppBackgroundStylePolicy.visualStyle(
                appTheme: "light",
                colorScheme: .light
            ) == .skyPopLight
        )
    }

    @Test
    func systemLightKeepsClassicMutedMistStyle() {
        #expect(
            AppBackgroundStylePolicy.visualStyle(
                appTheme: "system",
                colorScheme: .light
            ) == .mutedMistLight
        )
    }

    @Test
    func darkModeKeepsExistingDarkStyle() {
        #expect(
            AppBackgroundStylePolicy.visualStyle(
                appTheme: "dark",
                colorScheme: .dark
            ) == .darkSystem
        )
    }

    @Test
    func explicitLightThemeUsesSkyPopSurfaceStyleForSecondaryPanels() {
        #expect(
            AppSurfaceStylePolicy.visualStyle(
                appTheme: "light",
                colorScheme: .light
            ) == .skyPopLight
        )
        #expect(
            AppSurfaceStylePolicy.visualStyle(
                appTheme: "system",
                colorScheme: .light
            ) == .defaultLight
        )
    }
}
