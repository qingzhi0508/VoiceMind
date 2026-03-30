import XCTest
@testable import VoiceMind

final class DeprecatedPreferenceCleanupPolicyTests: XCTestCase {
    func testCleanupRemovesLegacyTextInjectionMethodPreference() {
        let suiteName = "DeprecatedPreferenceCleanupPolicyTests"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated UserDefaults suite")
            return
        }

        defaults.removePersistentDomain(forName: suiteName)
        defaults.set("accessibility", forKey: "textInjectionMethod")

        AppSettings.DeprecatedPreferenceCleanupPolicy.cleanup(defaults: defaults)

        XCTAssertNil(defaults.object(forKey: "textInjectionMethod"))
    }
}
