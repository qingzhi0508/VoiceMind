import SwiftUI

struct SpeechRecognitionTab: View {
    @ObservedObject var controller: MenuBarController
    var showsInlineHeader = true
    @StateObject private var engineListStore = SpeechRecognitionEngineListStore()
    @StateObject private var modelManager = SherpaOnnxModelManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if showsInlineHeader {
                Text(AppLocalization.localizedString("speech_engine_title"))
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
    }

    // MARK: - Engine + Model Selection

    @ViewBuilder
    private var engineSelectionSection: some View {
        GroupBox(label: Label(AppLocalization.localizedString("speech_engine_select_title"), systemImage: "waveform.circle")) {
            VStack(alignment: .leading, spacing: 12) {
                // Apple Speech 引擎
                ForEach(availableEngines.filter { $0.identifier == "apple-speech" }, id: \.identifier) { engine in
                    engineRow(engine)
                }

                Divider()

                // Sherpa-ONNX 可下载模型
                ForEach(SherpaOnnxModelDefinition.catalog) { model in
                    modelRow(model)
                }
            }
            .padding()
        }
    }

    // MARK: - Apple Engine Row

    @ViewBuilder
    private func engineRow(_ engine: SpeechRecognitionEngine) -> some View {
        HStack {
            RadioButton(
                isSelected: selectedEngineId == engine.identifier && !isSherpaModelSelected,
                action: {
                    selectAppleSpeech()
                }
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(engine.displayName)
                    .font(.headline)

                HStack {
                    if engine.isAvailable {
                        Label(AppLocalization.localizedString("engine_available"), systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    } else {
                        Label(AppLocalization.localizedString("engine_unavailable"), systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    Text(String(format: AppLocalization.localizedString("engine_supported_languages_format"), engine.supportedLanguages.prefix(3).joined(separator: ", ")))
                        .font(.caption)
                        .foregroundColor(MainWindowColors.secondaryText)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Sherpa Model Row

    @ViewBuilder
    private func modelRow(_ model: SherpaOnnxModelDefinition) -> some View {
        let state = modelManager.modelStates[model.id] ?? .notDownloaded

        HStack(spacing: 12) {
            // Radio button - 只有已安装时可选
            RadioButton(
                isSelected: modelManager.selectedModelId == model.id,
                action: {
                    if case .installed = state {
                        modelManager.selectModel(model.id)
                    }
                }
            )
            .disabled(state != .installed)

            VStack(alignment: .leading, spacing: 4) {
                Text(model.displayName)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(model.estimatedSize)
                        .font(.caption)
                        .foregroundColor(MainWindowColors.secondaryText)

                    Text(model.languages.prefix(3).joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(MainWindowColors.secondaryText)

                    // 状态标签
                    switch state {
                    case .installed:
                        Label("已安装", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    case .notDownloaded:
                        Text("需下载")
                            .font(.caption)
                            .foregroundColor(.orange)
                    case .downloading(let progress):
                        Text(String(format: "下载中 %.0f%%", progress * 100))
                            .font(.caption)
                            .foregroundColor(.blue)
                    case .extracting:
                        Text("解压中...")
                            .font(.caption)
                            .foregroundColor(.blue)
                    case .failed(let msg):
                        Text("失败: \(msg)")
                            .font(.caption)
                            .foregroundColor(.red)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // 操作按钮
            switch state {
            case .notDownloaded, .failed:
                Button(action: { modelManager.download(model: model) }) {
                    Label("下载", systemImage: "arrow.down.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

            case .downloading(let progress):
                Button(action: { modelManager.cancelDownload(modelId: model.id) }) {
                    Label("取消", systemImage: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)

                ProgressView(value: progress)
                    .frame(width: 80)

            case .extracting:
                ProgressView()
                    .controlSize(.small)

            case .installed:
                Button(action: { modelManager.deleteModel(model: model) }) {
                    Label("删除", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func selectAppleSpeech() {
        modelManager.selectedModelId = nil
        do {
            try SpeechRecognitionManager.shared.selectEngine(identifier: "apple-speech")
            engineListStore.reload()
            UserDefaults.standard.selectedSpeechEngine = "apple-speech"
            NotificationCenter.default.post(name: .speechEngineDidChange, object: nil)
        } catch {
            print("❌ 选择 Apple Speech 失败: \(error)")
        }
    }

    private var isSherpaModelSelected: Bool {
        modelManager.selectedModelId != nil
    }

    // MARK: - View Lifecycle

    private func refreshEngines() {
        engineListStore.reload()
    }
}

private extension SpeechRecognitionTab {
    var availableEngines: [SpeechRecognitionEngine] {
        engineListStore.availableEngines
    }

    var selectedEngineId: String {
        engineListStore.selectedEngineId
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
