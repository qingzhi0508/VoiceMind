import Foundation

enum MacMicrophoneMonitorSettings {
    static let storageKey = "voicemind.playMicrophoneThroughMacSpeaker"

    static func load(from defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: storageKey)
    }

    static func store(_ value: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: storageKey)
    }
}
