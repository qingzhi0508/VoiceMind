import SwiftUI
import AppKit

@main
struct VoiceMindMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            MainWindow(controller: appDelegate.controller)
        }
        .defaultSize(width: 800, height: 720)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
                self.controller.normalizeMainWindowFrameIfNeeded()
            }

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

            await MacAppUpdateManager.shared.performAutomaticUpdateCheckIfNeeded()
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

        // 注册 Sherpa-ONNX 引擎（使用 ModelManager 持有的单例）
        // 不直接显示为可选引擎，而是通过模型管理器选择模型后间接使用
        let sherpaOnnx = SherpaOnnxModelManager.shared.engine
        do {
            try await sherpaOnnx.initialize()
            SpeechRecognitionManager.shared.registerEngine(sherpaOnnx)
            print("✅ Sherpa-ONNX 引擎已注册")
        } catch {
            print("⚠️ Sherpa-ONNX 引擎初始化失败: \(error.localizedDescription)")
            // 即使初始化失败也注册，模型下载后可能变为可用
            SpeechRecognitionManager.shared.registerEngine(sherpaOnnx)
        }

        // 注册火山引擎 ASR
        let volcengine = VolcengineEngine()
        do {
            try await volcengine.initialize()
        } catch {
            print("⚠️ 火山引擎 ASR 初始化失败: \(error.localizedDescription)")
        }
        SpeechRecognitionManager.shared.registerEngine(volcengine)
        print("✅ 火山引擎 ASR 引擎已注册")

        // 注册 Qwen3-ASR 引擎
        let qwen3Asr = Qwen3AsrModelManager.shared.engine
        do {
            try await qwen3Asr.initialize()
        } catch {
            print("⚠️ Qwen3-ASR 引擎初始化失败: \(error.localizedDescription)")
        }
        SpeechRecognitionManager.shared.registerEngine(qwen3Asr)
        print("✅ Qwen3-ASR 引擎已注册")

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
