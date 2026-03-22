import XCTest
import SwiftUI
@testable import VoiceMind

final class HomeDashboardThemePolicyTests: XCTestCase {
    @MainActor
    func testSecondaryActionUsesThemeAwareSurface() {
        let style = SpotlightActionStylePolicy.style(for: .secondary)

        XCTAssertEqual(style.fillColor, MainWindowColors.secondaryButtonSurface)
    }

    @MainActor
    func testRecentActivityCardUsesThemeAwareSurface() {
        XCTAssertEqual(MainWindowColors.recentActivitySurface, MainWindowColors.recentActivitySurface)
        XCTAssertNotEqual(MainWindowColors.recentActivitySurface, Color.white)
    }
}
