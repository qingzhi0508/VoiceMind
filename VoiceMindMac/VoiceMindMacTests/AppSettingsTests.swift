import XCTest
@testable import VoiceMind

final class AppSettingsTests: XCTestCase {
    func testLegacyListeningPortMigratesToNewDefault() {
        XCTAssertEqual(
            ListeningPortMigrationPolicy.resolvedPort(savedPort: 19999, hasCustomizedPort: false),
            18661
        )
        XCTAssertEqual(
            ListeningPortMigrationPolicy.resolvedPort(savedPort: 19999, hasCustomizedPort: true),
            18661
        )
    }

    func testCustomizedListeningPortIsPreserved() {
        XCTAssertEqual(
            ListeningPortMigrationPolicy.resolvedPort(savedPort: 22345, hasCustomizedPort: true),
            22345
        )
    }

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

    func testThemePreferencePersists() {
        let settings = AppSettings.shared
        let originalPreference = settings.themePreference

        settings.themePreference = .dark
        XCTAssertEqual(settings.themePreference, .dark)

        settings.themePreference = .system
        XCTAssertEqual(settings.themePreference, .system)

        settings.themePreference = originalPreference
    }

    func testAutomaticUpdatePreferencePersists() {
        let settings = AppSettings.shared
        let originalValue = settings.automaticallyChecksForUpdates

        settings.automaticallyChecksForUpdates = true
        XCTAssertTrue(settings.automaticallyChecksForUpdates)

        settings.automaticallyChecksForUpdates = false
        XCTAssertFalse(settings.automaticallyChecksForUpdates)

        settings.automaticallyChecksForUpdates = originalValue
    }

    func testResetToDefaultsDisablesAutomaticUpdates() {
        let settings = AppSettings.shared
        let originalAutomaticUpdates = settings.automaticallyChecksForUpdates
        let originalLastCheckDate = settings.lastUpdateCheckDate

        settings.automaticallyChecksForUpdates = true
        settings.lastUpdateCheckDate = Date()
        settings.resetToDefaults()

        XCTAssertFalse(settings.automaticallyChecksForUpdates)
        XCTAssertNil(settings.lastUpdateCheckDate)

        settings.automaticallyChecksForUpdates = originalAutomaticUpdates
        settings.lastUpdateCheckDate = originalLastCheckDate
    }
}
