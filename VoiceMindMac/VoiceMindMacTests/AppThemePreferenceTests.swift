import XCTest
import SwiftUI
@testable import VoiceMind

final class AppThemePreferenceTests: XCTestCase {
    func testPreferredColorSchemeUsesSystemWhenConfigured() {
        XCTAssertNil(AppThemePreference.system.preferredColorScheme)
    }

    func testPreferredColorSchemeMapsLightAndDarkModes() {
        XCTAssertEqual(AppThemePreference.light.preferredColorScheme, .light)
        XCTAssertEqual(AppThemePreference.dark.preferredColorScheme, .dark)
    }
}
