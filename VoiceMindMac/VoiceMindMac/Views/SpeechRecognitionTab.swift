import SwiftUI

struct SpeechRecognitionTab: View {
    @ObservedObject var controller: MenuBarController
    var showsInlineHeader = true
    @State private var availableEngines: [SpeechRecognitionEngine] = []
    @State private var selectedEngineId: String = ""
    @State private var isRefreshing = false
    
    // 模型管理相关状态
    @State private var availableModels: [ModelInfo] = []
    @State private var downloadingModelId: String? = nil
    @State private var downloadProgress: Double = 0.0
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if showsInlineHeader {
                Text(String(localized: "speech_engine_title"))
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            engineSelectionSection

            Spacer()
        }
        .padding()
        .onAppear {
            refreshEngines()
        }
        .alert(isPresented: $showError) {
            errorAlert
        }
    }

    @ViewBuilder
    private var engineSelectionSection: some View {
        GroupBox(label: Label(String(localized: "speech_engine_select_title"), systemImage: "waveform.circle")) {
            VStack(alignment: .leading, spacing: 12) {
                if availableEngines.isEmpty {
                    Text(String(localized: "speech_engine_loading"))
                        .foregroundColor(MainWindowColors.secondaryText)
                } else {
                    ForEach(availableEngines, id: \.identifier) { engine in
                        engineRow(engine)
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var modelManagementSection: some View {
        GroupBox(label: Label(String(localized: "model_management_title"), systemImage: "square.and.arrow.down")) {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "model_management_desc"))
                    .font(.caption)
                    .foregroundColor(MainWindowColors.secondaryText)

                if availableModels.isEmpty {
                    Text(String(localized: "model_loading"))
                        .foregroundColor(MainWindowColors.secondaryText)
                        .font(.caption)
                } else {
                    ForEach(availableModels, id: \.id) { model in
                        modelRow(model)
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func modelRow(_ model: ModelInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name)
                        .font(.headline)

                    Text(model.description)
                        .font(.caption)
                        .foregroundColor(MainWindowColors.secondaryText)

                    HStack(spacing: 8) {
                        Text("引擎: \(model.engineType)")
                            .font(.caption2)
                            .foregroundColor(MainWindowColors.secondaryText)
                        Text("大小: \(formatFileSize(model.size))")
                            .font(.caption2)
                            .foregroundColor(MainWindowColors.secondaryText)
                    }
                }

                Spacer()

                if model.isDownloaded {
                    HStack(spacing: 8) {
                        if let defaultModel = ModelManager.shared.getDefaultModel(engineType: model.engineType),
                           defaultModel.id == model.id {
                            Label("默认", systemImage: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        } else {
                            Button("设为默认") {
                                setDefaultModel(model)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        Label(String(localized: "model_downloaded"), systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Button("删除") {
                            deleteModel(model)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundColor(.red)
                    }
                } else if downloadingModelId == model.id {
                    HStack {
                        ProgressView(value: downloadProgress)
                            .frame(width: 100)
                            .controlSize(.small)
                        Button("取消") {
                            cancelDownload()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } else {
                    Button(AppLocalization.localizedString("model_download_button")) {
                        downloadModel(model)
                    }
                    .buttonStyle(.bordered)
                }
            }

            if !model.languages.isEmpty {
                HStack {
                    Text("支持语言: \(model.languages.prefix(5).joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundColor(MainWindowColors.secondaryText)
                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(MainWindowColors.cardBorder, lineWidth: 1)
        )
        .padding(8)
    }

    @ViewBuilder
    private func engineRow(_ engine: SpeechRecognitionEngine) -> some View {
        HStack {
            RadioButton(
                isSelected: selectedEngineId == engine.identifier,
                action: {
                    selectEngine(engine.identifier)
                }
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(engine.displayName)
                    .font(.headline)

                HStack {
                    if engine.isAvailable {
                        Label(String(localized: "engine_available"), systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    } else {
                        Label(String(localized: "engine_unavailable"), systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    Text(String(format: String(localized: "engine_supported_languages_format"), engine.supportedLanguages.prefix(3).joined(separator: ", ")))
                        .font(.caption)
                        .foregroundColor(MainWindowColors.secondaryText)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }



    private func selectEngine(_ identifier: String) {
        do {
            try SpeechRecognitionManager.shared.selectEngine(identifier: identifier)
            selectedEngineId = identifier
            UserDefaults.standard.selectedSpeechEngine = identifier

            // Post notification for engine change
            NotificationCenter.default.post(
                name: .speechEngineDidChange,
                object: nil
            )
        } catch {
            print("❌ 选择引擎失败: \(error)")
        }
    }

    // MARK: - Model Management Methods

    private func refreshModels() {
        availableModels = ModelManager.shared.availableModels()
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func downloadModel(_ model: ModelInfo) {
        downloadingModelId = model.id
        downloadProgress = 0.0

        Task {
            do {
                try await ModelManager.shared.downloadModel(model) { progress in
                    DispatchQueue.main.async {
                        self.downloadProgress = progress
                    }
                }
                
                DispatchQueue.main.async {
                    self.downloadingModelId = nil
                    ModelManager.shared.setDefaultModel(engineType: model.engineType, modelId: model.id)
                    self.refreshModels()
                    self.refreshEngines() // 刷新引擎状态
                }
            } catch {
                DispatchQueue.main.async {
                    self.downloadingModelId = nil
                    self.errorMessage = "下载失败: \(error.localizedDescription)"
                    self.showError = true
                }
            }
            
            // 下载完成后，尝试注册或重新初始化 SenseVoice 引擎
            if model.engineType == "sensevoice" {
                DispatchQueue.main.async {
                    Task {
                        await self.initializeSenseVoiceEngineIfNeeded()
                    }
                }
            }
        }
    }

    private func cancelDownload() {
        // 目前 ModelManager 没有提供取消下载的方法
        // 可以在后续版本中实现
        downloadingModelId = nil
        downloadProgress = 0.0
    }

    private func deleteModel(_ model: ModelInfo) {
        do {
            try ModelManager.shared.deleteModel(model)
            refreshModels()
            refreshEngines() // 刷新引擎状态
        } catch {
            errorMessage = "删除失败: \(error.localizedDescription)"
            showError = true
        }
    }

    private func setDefaultModel(_ model: ModelInfo) {
        ModelManager.shared.setDefaultModel(engineType: model.engineType, modelId: model.id)
        refreshModels() // 刷新模型列表以显示默认标记
    }

    private func initializeSenseVoiceEngineIfNeeded() async {
        // 检查模型是否已下载
        guard ModelManager.shared.isModelDownloaded(engineType: "sensevoice") else {
            print("ℹ️ SenseVoice 模型未下载，跳过引擎初始化")
            return
        }
        
        // 检查引擎是否已注册
        let engines = SpeechRecognitionManager.shared.availableEngines()
        let isSenseVoiceRegistered = engines.contains { $0.identifier == "sensevoice" }
        
        if !isSenseVoiceRegistered {
            print("📦 注册 SenseVoice 引擎...")
            let senseVoice = SenseVoiceEngine()
            do {
                try await senseVoice.initialize()
                SpeechRecognitionManager.shared.registerEngine(senseVoice)
                print("✅ SenseVoice 引擎已注册")
                refreshEngines() // 刷新引擎列表
                selectSenseVoiceIfAvailable()
            } catch {
                print("❌ SenseVoice 引擎初始化失败: \(error.localizedDescription)")
            }
        } else {
            print("ℹ️ SenseVoice 引擎已注册，刷新状态")
            refreshEngines() // 刷新引擎状态
            selectSenseVoiceIfAvailable()
        }
    }

    // MARK: - View Lifecycle

    private func refreshEngines() {
        isRefreshing = true
        availableEngines = SpeechRecognitionManager.shared.availableEngines()
        selectedEngineId = SpeechRecognitionManager.shared.currentEngine?.identifier ?? ""
        isRefreshing = false
    }

    private func selectSenseVoiceIfAvailable() {
        guard let senseVoice = SpeechRecognitionManager.shared.getEngine(identifier: "sensevoice"),
              senseVoice.isAvailable else {
            return
        }
        if selectedEngineId != "sensevoice" {
            selectEngine("sensevoice")
        }
    }
}

// Error alert extension
private extension SpeechRecognitionTab {
    var errorAlert: Alert {
        Alert(
            title: Text("错误"),
            message: Text(errorMessage),
            dismissButton: .default(Text("确定"))
        )
    }
}

// Radio button component
struct RadioButton: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                .foregroundColor(isSelected ? .accentColor : MainWindowColors.secondaryText)
        }
        .buttonStyle(.plain)
    }
}
