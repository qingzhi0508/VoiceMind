import SwiftUI

struct SpeechRecognitionTab: View {
    @ObservedObject var controller: MenuBarController
    var showsInlineHeader = true
    @StateObject private var engineListStore = SpeechRecognitionEngineListStore()

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
            engineListStore.reload()
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
