import AppIntents

struct VoiceMindShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartLocalRecognitionIntent(),
            phrases: [
                "Start local recognition in \(.applicationName)",
                "Start on-device recognition in \(.applicationName)"
            ],
            shortTitle: "Local Recognition",
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: StartRemoteRecognitionIntent(),
            phrases: [
                "Start remote recognition in \(.applicationName)",
                "Start Mac recognition in \(.applicationName)"
            ],
            shortTitle: "Remote Recognition",
            systemImageName: "antenna.radiowaves.left.and.right"
        )
    }

    static var shortcutTileColor: ShortcutTileColor = .blue
}
