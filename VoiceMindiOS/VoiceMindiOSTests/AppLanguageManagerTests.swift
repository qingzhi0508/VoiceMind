import Testing
@testable import VoiceMind

struct AppLanguageManagerTests {
    @Test
    func restartAfterLanguageChangeDoesNotForceQuitApp() {
        var didRequestTermination = false

        AppLanguageManager.restartAfterLanguageChange {
            didRequestTermination = true
        }

        #expect(!didRequestTermination)
    }
}
