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

        Task {
            await initializeSpeechEngine()
            controller.startNetworkServices()

            // Show onboarding on first launch
            if !AppSettings.shared.hasLaunchedBefore {
                AppSettings.shared.hasLaunchedBefore = true
                controller.showOnboarding()
            }
        }
    }

    private func initializeSpeechEngine() async {
        // 初始化模型管理器（确保目录创建）
        _ = ModelManager.shared
        print("✅ 模型管理器已初始化")

        let appleSpeech = AppleSpeechEngine()
        do {
            try await appleSpeech.initialize()
            SpeechRecognitionManager.shared.registerEngine(appleSpeech)
            print("✅ Apple Speech 引擎已注册")

            // Setup delegate after engine is registered
            controller.connectionManager.setupSpeechRecognition()
        } catch {
            print("❌ Apple Speech 引擎初始化失败: \(error.localizedDescription)")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when main window closes - keep running in menu bar
        return false
    }
}
