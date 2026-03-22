import XCTest
@testable import VoiceMind

final class AppSettingsTests: XCTestCase {
    func testUsageGuideFlagPersists() {
        let settings = AppSettings.shared
        let originalValue = settings.hasShownUsageGuide

        settings.hasShownUsageGuide = false
        XCTAssertFalse(settings.hasShownUsageGuide)

        settings.hasShownUsageGuide = true
        XCTAssertTrue(settings.hasShownUsageGuide)

        settings.hasShownUsageGuide = originalValue
    }

    func testResetToDefaultsUsesNewListeningPort() {
        let settings = AppSettings.shared
        let originalPort = settings.serverPort

        settings.serverPort = 19999
        settings.resetToDefaults()

        XCTAssertEqual(settings.serverPort, 18661)

        settings.serverPort = originalPort
    }
}
