import SwiftUI

@main
struct VoiceRelayMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            MainWindow(controller: appDelegate.controller)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("关于 VoiceMind") {
                    // Show about window
                }
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = MenuBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set activation policy to show in Dock
        NSApp.setActivationPolicy(.regular)

        controller.startNetworkServices()

        // Show onboarding on first launch
        if !AppSettings.shared.hasLaunchedBefore {
            AppSettings.shared.hasLaunchedBefore = true
            controller.showOnboarding()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when main window closes - keep running in menu bar
        return false
    }
}
