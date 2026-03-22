import SwiftUI
import AppKit

@main
struct VoiceMindMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            MainWindow(controller: appDelegate.controller)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("关于 语灵") {
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

            if !AppSettings.shared.hasShownUsageGuide {
                AppSettings.shared.hasShownUsageGuide = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [self] in
                    self.controller.showUsageGuide()
                }
            }
        }
    }

    private func initializeSpeechEngine() async {
        let appleSpeech = AppleSpeechEngine()
        do {
            try await appleSpeech.initialize()
            SpeechRecognitionManager.shared.registerEngine(appleSpeech)
            print("✅ Apple Speech 引擎已注册")
        } catch {
            print("❌ Apple Speech 引擎初始化失败: \(error.localizedDescription)")
        }

        restorePreferredSpeechEngine()

        // Setup speech recognition delegate
        controller.connectionManager.setupSpeechRecognition()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when main window closes - keep running in menu bar
        return false
    }

    private func restorePreferredSpeechEngine() {
        let fallbackEngineId = "apple-speech"
        let savedEngineId = UserDefaults.standard.selectedSpeechEngine
        let availableEngineIds = Set(SpeechRecognitionManager.shared.availableEngines().map(\.identifier))
        let resolvedEngineId = PreferredSpeechEngineResolver.resolve(
            savedEngineId: savedEngineId,
            availableEngineIds: availableEngineIds,
            fallbackEngineId: fallbackEngineId
        )

        guard resolvedEngineId == savedEngineId.trimmingCharacters(in: .whitespacesAndNewlines) else {
            if !savedEngineId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                print("ℹ️ 已忽略不存在的历史引擎: \(savedEngineId)，切换到默认引擎")
            }
            selectFallbackSpeechEngine(fallbackEngineId)
            return
        }

        do {
            try SpeechRecognitionManager.shared.selectEngine(identifier: resolvedEngineId)
            print("✅ 恢复上次选择的引擎: \(resolvedEngineId)")
        } catch {
            print("⚠️ 恢复引擎失败: \(resolvedEngineId)，切换到默认引擎")
            selectFallbackSpeechEngine(fallbackEngineId)
        }
    }

    private func selectFallbackSpeechEngine(_ identifier: String) {
        try? SpeechRecognitionManager.shared.selectEngine(identifier: identifier)
        UserDefaults.standard.selectedSpeechEngine = identifier
    }
}
