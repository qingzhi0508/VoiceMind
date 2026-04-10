import Foundation

enum MacMicrophoneMonitorPolicy {
    static func shouldShowToggle(sendToMacEnabled: Bool) -> Bool {
        sendToMacEnabled
    }

    static func shouldPlayThroughMacSpeaker(
        sendToMacEnabled: Bool,
        preferredMode: HomeTranscriptionMode,
        microphoneMonitorEnabled: Bool
    ) -> Bool {
        sendToMacEnabled && preferredMode == .mac && microphoneMonitorEnabled
    }
}
