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
        let modelManager = ModelManager.shared
        if !modelManager.isInitialized {
            print("⚠️ 模型管理器初始化失败，模型下载功能将不可用")
            // Note: App continues with degraded functionality
        } else {
            print("✅ 模型管理器已初始化")
        }

        // 注册 Apple Speech 引擎
        let appleSpeech = AppleSpeechEngine()
        do {
            try await appleSpeech.initialize()
            SpeechRecognitionManager.shared.registerEngine(appleSpeech)
            print("✅ Apple Speech 引擎已注册")
        } catch {
            print("❌ Apple Speech 引擎初始化失败: \(error.localizedDescription)")
        }

        // 注册 SenseVoice 引擎（如果模型已下载）
        if modelManager.isModelDownloaded(engineType: "sensevoice") {
            print("📦 检测到 SenseVoice 模型，正在初始化...")
            let senseVoice = SenseVoiceEngine()
            do {
                try await senseVoice.initialize()
                SpeechRecognitionManager.shared.registerEngine(senseVoice)
                print("✅ SenseVoice 引擎已注册")
            } catch {
                print("❌ SenseVoice 引擎初始化失败: \(error.localizedDescription)")
            }
        } else {
            print("ℹ️ SenseVoice 模型未下载，跳过引擎注册")
        }

        // 恢复之前选择的引擎
        if let savedEngineId = UserDefaults.standard.string(forKey: "selectedEngineId") {
            SpeechRecognitionManager.shared.selectEngine(identifier: savedEngineId)
            print("🔄 已恢复引擎选择: \(savedEngineId)")
        }

        // Setup delegate after engines are registered
        controller.connectionManager.setupSpeechRecognition()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when main window closes - keep running in menu bar
        return false
    }
}
