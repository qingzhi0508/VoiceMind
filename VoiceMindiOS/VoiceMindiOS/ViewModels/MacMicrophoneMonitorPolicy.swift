import Foundation

enum MacMicrophoneMonitorPolicy {
    static func shouldPlayThroughMacSpeaker(
        preferredMode: HomeTranscriptionMode
    ) -> Bool {
        preferredMode == .microphone
    }
}
