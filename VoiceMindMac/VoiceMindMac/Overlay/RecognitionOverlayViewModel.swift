import Foundation
import AppKit
import Combine

extension Notification.Name {
    static let voiceMindAudioSessionDidStart = Notification.Name("voiceMindAudioSessionDidStart")
    static let voiceMindAudioSessionDidEnd = Notification.Name("voiceMindAudioSessionDidEnd")
}

enum OverlayState: Equatable {
    case hidden
    case listening
    case streaming(String)
    case result(String)
    case error(String)
}

class RecognitionOverlayViewModel: ObservableObject {
    @Published var state: OverlayState = .hidden
    @Published var cursorPosition: NSPoint = .zero

    private var autoHideTask: Task<Void, Never>?
    private var suppressUpdates = false

    func showListening() {
        autoHideTask?.cancel()
        autoHideTask = nil
        suppressUpdates = false
        state = .listening
    }

    func updatePartialText(_ text: String) {
        guard !suppressUpdates else { return }
        if case .result = state { return }
        autoHideTask?.cancel()
        autoHideTask = nil
        if text.isEmpty {
            if state != .hidden {
                state = .listening
            }
        } else {
            state = .streaming(text)
        }
    }

    func showResult(_ text: String) {
        guard !suppressUpdates else { return }
        if case .result(let prevText) = state, prevText == text { return }
        autoHideTask?.cancel()
        state = .result(text)
        scheduleAutoHide(delay: 0.8)
    }

    func showError(_ message: String) {
        guard !suppressUpdates else { return }
        autoHideTask?.cancel()
        state = .error(message)
        scheduleAutoHide(delay: 0.8)
    }

    func hide() {
        suppressUpdates = true
        autoHideTask?.cancel()
        autoHideTask = nil
        state = .hidden
    }

    private func scheduleAutoHide(delay: TimeInterval) {
        autoHideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.state = .hidden
        }
    }
}
