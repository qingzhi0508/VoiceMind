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
    private var didShowModelCorruptedAlert = false
    private var didScheduleSenseVoiceRetry = false
    private var didShowModelRetryFailedAlert = false

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

        // 注册 SenseVoice 引擎（如果模型管理器初始化成功且模型已下载）
        if modelManager.isInitialized && modelManager.isModelDownloaded(engineType: "sensevoice") {
            print("📦 检测到 SenseVoice 模型，正在初始化...")
            let senseVoice = SenseVoiceEngine()
            do {
                try await senseVoice.initialize()
                SpeechRecognitionManager.shared.registerEngine(senseVoice)
                print("✅ SenseVoice 引擎已注册")
            } catch {
                print("❌ SenseVoice 引擎初始化失败: \(error.localizedDescription)")
                if let senseError = error as? SenseVoiceError {
                    switch senseError {
                    case .invalidTokensFile, .invalidModelPath, .modelLoadFailed:
                        print("🧹 SenseVoice 模型可能损坏，清理本地模型并等待重新下载")
                        ModelManager.shared.invalidateDownloadedModel(engineType: "sensevoice")
                        showModelCorruptedAlertIfNeeded()
                        scheduleSenseVoiceModelRetryDownload()
                    default:
                        break
                    }
                }
            }
        } else {
            print("ℹ️ SenseVoice 模型未下载或模型管理器未初始化，跳过引擎注册")
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
        let savedEngineId = UserDefaults.standard.selectedSpeechEngine.trimmingCharacters(in: .whitespacesAndNewlines)
        let availableEngineIds = Set(SpeechRecognitionManager.shared.availableEngines().map(\.identifier))

        guard !savedEngineId.isEmpty else {
            selectFallbackSpeechEngine(fallbackEngineId)
            return
        }

        guard availableEngineIds.contains(savedEngineId) else {
            print("ℹ️ 已忽略不存在的历史引擎: \(savedEngineId)，切换到默认引擎")
            selectFallbackSpeechEngine(fallbackEngineId)
            return
        }

        do {
            try SpeechRecognitionManager.shared.selectEngine(identifier: savedEngineId)
            print("✅ 恢复上次选择的引擎: \(savedEngineId)")
        } catch {
            print("⚠️ 恢复引擎失败: \(savedEngineId)，切换到默认引擎")
            selectFallbackSpeechEngine(fallbackEngineId)
        }
    }

    private func selectFallbackSpeechEngine(_ identifier: String) {
        try? SpeechRecognitionManager.shared.selectEngine(identifier: identifier)
        UserDefaults.standard.selectedSpeechEngine = identifier
    }

    private func showModelCorruptedAlertIfNeeded() {
        guard !didShowModelCorruptedAlert else { return }
        didShowModelCorruptedAlert = true

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = String(localized: "sensevoice_model_corrupted_title")
            alert.informativeText = String(localized: "sensevoice_model_corrupted_message")
            alert.addButton(withTitle: AppLocalization.localizedString("sensevoice_model_corrupted_ok"))
            alert.runModal()
        }
    }

    private func scheduleSenseVoiceModelRetryDownload() {
        guard !didScheduleSenseVoiceRetry else { return }
        didScheduleSenseVoiceRetry = true

        Task {
            let models = ModelManager.shared.modelsForEngine("sensevoice")
            guard let model = models.first else {
                print("⚠️ 未找到 SenseVoice 模型信息，无法自动重试下载")
                return
            }

            do {
                print("⬇️ 自动重试下载 SenseVoice 模型...")
                try await ModelManager.shared.downloadModel(model) { _ in }
                print("✅ SenseVoice 模型自动下载完成，尝试初始化引擎")

                let engines = SpeechRecognitionManager.shared.availableEngines()
                let isRegistered = engines.contains { $0.identifier == "sensevoice" }
                if !isRegistered {
                    let senseVoice = SenseVoiceEngine()
                    try await senseVoice.initialize()
                    SpeechRecognitionManager.shared.registerEngine(senseVoice)
                    print("✅ SenseVoice 引擎已注册（自动重试后）")
                }
            } catch {
                print("❌ SenseVoice 模型自动重试下载失败: \(error.localizedDescription)")
                showModelRetryFailedAlertIfNeeded(error: error)
            }
        }
    }

    private func showModelRetryFailedAlertIfNeeded(error: Error) {
        guard !didShowModelRetryFailedAlert else { return }
        didShowModelRetryFailedAlert = true

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = String(localized: "sensevoice_model_retry_failed_title")
            alert.informativeText = String(
                format: String(localized: "sensevoice_model_retry_failed_message"),
                error.localizedDescription
            )
            alert.addButton(withTitle: AppLocalization.localizedString("sensevoice_model_retry_failed_ok"))
            alert.runModal()
        }
    }
}
