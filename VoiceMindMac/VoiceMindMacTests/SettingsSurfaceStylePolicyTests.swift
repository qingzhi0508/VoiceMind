import XCTest
import SwiftUI
@testable import VoiceMind

final class SettingsSurfaceStylePolicyTests: XCTestCase {
    @MainActor
    func testSettingsSurfaceAvoidsNativeFormContainerInLightTheme() {
        XCTAssertFalse(SettingsSurfaceStylePolicy.usesNativeGroupedForm)
    }

    @MainActor
    func testSettingsSurfaceUsesVisibleCardBorders() {
        XCTAssertNotEqual(SettingsSurfaceStylePolicy.cardBorderColor, Color.clear)
    }
}
