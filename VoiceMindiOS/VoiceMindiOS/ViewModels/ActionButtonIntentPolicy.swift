import Foundation

enum ActionButtonIntentPolicy {
    enum RecognitionMode {
        case local
        case remote
    }

    static func shouldAutoStartRecognition(
        recognitionState: RecognitionState,
        hasPermissions: Bool
    ) -> Bool {
        guard hasPermissions else { return false }
        switch recognitionState {
        case .idle:
            return true
        case .listening, .processing, .sending:
            return false
        }
    }

    static func forcedMode(for mode: RecognitionMode) -> HomeTranscriptionMode {
        switch mode {
        case .local: return .local
        case .remote: return .mac
        }
    }

    static func shouldForceRemoteMode(
        mode: RecognitionMode,
        isPaired: Bool,
        isConnected: Bool
    ) -> Bool {
        guard mode == .remote else { return false }
        return isPaired && isConnected
    }
}
