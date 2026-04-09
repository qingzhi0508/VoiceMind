import SwiftUI

struct SpeechRecognitionTab: View {
    @ObservedObject var controller: MenuBarController
    var showsInlineHeader = true
    @StateObject private var engineListStore = SpeechRecognitionEngineListStore()
    @StateObject private var modelManager = SherpaOnnxModelManager.shared

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            if showsInlineHeader {
                Text(AppLocalization.localizedString("speech_engine_title"))
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(MainWindowColors.title)
            }

            speechHero

            engineSelectionSection

            Spacer()
        }
        .padding(.bottom, 8)
        }
        .onAppear {
            refreshEngines()
        }
    }

    private var speechHero: some View {
        MainWindowSurface(emphasized: true) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(AppLocalization.localizedString("speech_engine_title"))
                        .font(.title3.weight(.semibold))
                        .foregroundColor(MainWindowColors.title)

                    Text(AppLocalization.localizedString("main_speech_subtitle"))
                        .font(.subheadline)
                        .foregroundColor(MainWindowColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    MainWindowStatusChip(
                        title: selectedEngineDisplayName,
                        systemImage: "waveform.circle",
                        tint: .blue
                    )

                    MainWindowStatusChip(
                        title: modelStatusSummary,
                        systemImage: "internaldrive",
                        tint: isSherpaModelSelected ? .green : .orange
                    )
                }
            }
        }
    }

    // MARK: - Engine + Model Selection

    @ViewBuilder
    private var engineSelectionSection: some View {
        MainWindowSurface {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(AppLocalization.localizedString("speech_engine_select_title"), systemImage: "waveform.circle")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(MainWindowColors.title)

                    Text(AppLocalization.localizedString("main_speech_subtitle"))
                        .font(.subheadline)
                        .foregroundColor(MainWindowColors.secondaryText)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Apple Speech")
                        .font(.headline)
                        .foregroundColor(MainWindowColors.title)

                    ForEach(availableEngines.filter { $0.identifier == "apple-speech" }, id: \.identifier) { engine in
                        engineRow(engine)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Sherpa-ONNX")
                            .font(.headline)
                            .foregroundColor(MainWindowColors.title)

                        Spacer()

                        Text("\(installedModelCount)/\(SherpaOnnxModelDefinition.catalog.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(MainWindowColors.secondaryText)
                    }

                    ForEach(SherpaOnnxModelDefinition.catalog) { model in
                        modelRow(model)
                    }
                }
            }
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
                    .foregroundColor(MainWindowColors.title)

                HStack(spacing: 10) {
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

            if selectedEngineId == engine.identifier && !isSherpaModelSelected {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.accentColor)
                    .padding(8)
                    .background(MainWindowColors.cardSurface)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MainWindowColors.softSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MainWindowColors.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Sherpa Model Row

    @ViewBuilder
    private func modelRow(_ model: SherpaOnnxModelDefinition) -> some View {
        let state = modelManager.modelStates[model.id] ?? .notDownloaded

        HStack(alignment: .center, spacing: 12) {
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
                HStack(spacing: 8) {
                    Text(model.displayName)
                        .font(.headline)
                        .foregroundColor(MainWindowColors.title)

                    statePill(for: state)
                }

                HStack(spacing: 8) {
                    Text(model.estimatedSize)
                        .font(.caption)
                        .foregroundColor(MainWindowColors.secondaryText)

                    Text(model.languages.prefix(3).joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(MainWindowColors.secondaryText)
                }

                if case .failed(let msg) = state {
                    Text("失败: \(msg)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(1)
                }
            }

            Spacer()

            switch state {
            case .notDownloaded, .failed:
                Button(action: { modelManager.download(model: model) }) {
                    Label("下载", systemImage: "arrow.down.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

            case .downloading(let progress):
                VStack(alignment: .trailing, spacing: 8) {
                    Button(action: { modelManager.cancelDownload(modelId: model.id) }) {
                        Label("取消", systemImage: "xmark.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)

                    ProgressView(value: progress)
                        .frame(width: 96)
                }

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
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MainWindowColors.softSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MainWindowColors.cardBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func statePill(for state: ModelState) -> some View {
        switch state {
        case .installed:
            miniPill(title: "已安装", tint: .green)
        case .notDownloaded:
            miniPill(title: "需下载", tint: .orange)
        case .downloading(let progress):
            miniPill(title: String(format: "下载中 %.0f%%", progress * 100), tint: .blue)
        case .extracting:
            miniPill(title: "解压中", tint: .blue)
        case .failed:
            miniPill(title: "失败", tint: .red)
        }
    }

    private func miniPill(title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.10))
            .clipShape(Capsule())
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

    var selectedEngineDisplayName: String {
        if let selectedModelId = modelManager.selectedModelId,
           let model = SherpaOnnxModelDefinition.catalog.first(where: { $0.id == selectedModelId }) {
            return model.displayName
        }

        return availableEngines.first(where: { $0.identifier == selectedEngineId })?.displayName
            ?? AppLocalization.localizedString("speech_engine_title")
    }

    var modelStatusSummary: String {
        if isSherpaModelSelected {
            return "Sherpa-ONNX"
        }

        return "Apple Speech"
    }

    var installedModelCount: Int {
        SherpaOnnxModelDefinition.catalog.filter {
            if case .installed = modelManager.modelStates[$0.id] ?? .notDownloaded {
                return true
            }
            return false
        }.count
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
