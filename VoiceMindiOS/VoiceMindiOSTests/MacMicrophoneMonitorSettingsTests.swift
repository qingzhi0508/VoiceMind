import Foundation
import Testing
@testable import VoiceMind

struct MacMicrophoneMonitorSettingsTests {
    @Test
    func defaultsToDisabledWhenNothingIsStored() {
        let suiteName = "MacMicrophoneMonitorSettingsTests-default"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(!MacMicrophoneMonitorSettings.load(from: defaults))
    }

    @Test
    func storesAndLoadsEnabledValue() {
        let suiteName = "MacMicrophoneMonitorSettingsTests-roundtrip"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        MacMicrophoneMonitorSettings.store(true, in: defaults)

        #expect(MacMicrophoneMonitorSettings.load(from: defaults))
    }
}
