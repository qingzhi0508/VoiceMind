import Combine
import Foundation

struct EngineSnapshot {
    let engines: [SpeechRecognitionEngine]
    let selectedEngineId: String
}

@MainActor
final class SpeechRecognitionEngineListStore: ObservableObject {
    @Published private(set) var availableEngines: [SpeechRecognitionEngine] = []
    @Published private(set) var selectedEngineId: String = ""

    private let snapshotProvider: () -> EngineSnapshot
    private var cancellable: AnyCancellable?

    init(
        notificationCenter: NotificationCenter = .default,
        snapshotProvider: (() -> EngineSnapshot)? = nil
    ) {
        self.snapshotProvider = snapshotProvider ?? Self.liveSnapshot
        reload()
        cancellable = notificationCenter.publisher(for: .speechEngineDidChange)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.reload()
                }
            }
    }

    func reload() {
        let snapshot = snapshotProvider()
        availableEngines = snapshot.engines
        selectedEngineId = snapshot.selectedEngineId
    }

    private static func liveSnapshot() -> EngineSnapshot {
        EngineSnapshot(
            engines: SpeechRecognitionManager.shared.availableEngines(),
            selectedEngineId: SpeechRecognitionManager.shared.currentEngine?.identifier ?? ""
        )
    }
}
