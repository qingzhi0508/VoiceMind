import Testing
@testable import VoiceMind

struct MacMicrophoneMonitorPolicyTests {
    @Test
    func speakerPlaybackOnlyActivatesInMicrophoneMode() {
        #expect(
            MacMicrophoneMonitorPolicy.shouldPlayThroughMacSpeaker(
                preferredMode: .microphone
            )
        )

        #expect(
            !MacMicrophoneMonitorPolicy.shouldPlayThroughMacSpeaker(
                preferredMode: .local
            )
        )

        #expect(
            !MacMicrophoneMonitorPolicy.shouldPlayThroughMacSpeaker(
                preferredMode: .mac
            )
        )
    }
}
