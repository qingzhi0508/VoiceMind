import SwiftUI

struct SpeechRecognitionTab: View {
    @ObservedObject var controller: MenuBarController
    @State private var availableEngines: [SpeechRecognitionEngine] = []
    @State private var selectedEngineId: String = ""
    @State private var isRefreshing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("语音识别引擎")
                .font(.title2)
                .fontWeight(.semibold)

            // Engine selection section
            engineSelectionSection

            Divider()
                .padding(.vertical)

            // Model management section
            modelManagementSection

            Spacer()
        }
        .padding()
        .onAppear {
            refreshEngines()
        }
    }

    @ViewBuilder
    private var engineSelectionSection: some View {
        GroupBox(label: Label("选择识别引擎", systemImage: "waveform.circle")) {
            VStack(alignment: .leading, spacing: 12) {
                if availableEngines.isEmpty {
                    Text("正在加载引擎...")
                        .foregroundColor(.secondary)
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
        GroupBox(label: Label("模型管理", systemImage: "square.and.arrow.down")) {
            VStack(alignment: .leading, spacing: 12) {
                Text("管理本地语音识别模型")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let senseVoiceEngine = availableEngines.first(where: { $0.identifier == "sensevoice" }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SenseVoice Small")
                                .font(.headline)

                            Text("多语言语音识别模型，约 85MB")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if senseVoiceEngine.isAvailable {
                            Label("已下载", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        } else {
                            Button("下载模型") {
                                // TODO: Implement model download
                                print("下载 SenseVoice 模型")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } else {
                    Text("SenseVoice 引擎未注册")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .padding()
        }
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
                        Label("可用", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    } else {
                        Label("不可用", systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    Text("支持语言: \(engine.supportedLanguages.prefix(3).joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func refreshEngines() {
        isRefreshing = true
        availableEngines = SpeechRecognitionManager.shared.availableEngines()
        selectedEngineId = SpeechRecognitionManager.shared.currentEngine?.identifier ?? ""
        isRefreshing = false
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
}

// Radio button component
struct RadioButton: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
        }
        .buttonStyle(.plain)
    }
}
