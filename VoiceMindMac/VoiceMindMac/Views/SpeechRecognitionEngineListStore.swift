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

    private let notificationCenter: NotificationCenter
    private let snapshotProvider: () -> EngineSnapshot
    private var notificationToken: NSObjectProtocol?

    init(
        notificationCenter: NotificationCenter = .default,
        snapshotProvider: (() -> EngineSnapshot)? = nil
    ) {
        self.notificationCenter = notificationCenter
        self.snapshotProvider = snapshotProvider ?? Self.liveSnapshot
        reload()
        notificationToken = notificationCenter.addObserver(
            forName: .speechEngineDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.reload()
            }
        }
    }

    deinit {
        if let notificationToken {
            notificationCenter.removeObserver(notificationToken)
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
