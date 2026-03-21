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
}
