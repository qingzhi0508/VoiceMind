import SwiftUI

struct SpeechRecognitionTab: View {
    @ObservedObject var controller: MenuBarController
    @State private var availableEngines: [SpeechRecognitionEngine] = []
    @State private var selectedEngineId: String = ""
    @State private var isRefreshing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(String(localized: "speech_engine_title"))
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
        GroupBox(label: Label(String(localized: "speech_engine_select_title"), systemImage: "waveform.circle")) {
            VStack(alignment: .leading, spacing: 12) {
                if availableEngines.isEmpty {
                    Text(String(localized: "speech_engine_loading"))
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
        GroupBox(label: Label(String(localized: "model_management_title"), systemImage: "square.and.arrow.down")) {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "model_management_desc"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let senseVoiceEngine = availableEngines.first(where: { $0.identifier == "sensevoice" }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "model_name_sensevoice"))
                                .font(.headline)

                            Text(String(localized: "model_desc_sensevoice"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if senseVoiceEngine.isAvailable {
                            Label(String(localized: "model_downloaded"), systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        } else {
                            Button(String(localized: "model_download_button")) {
                                // TODO: Implement model download
                                print("下载 SenseVoice 模型")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } else {
                    Text(String(localized: "model_engine_not_registered"))
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
