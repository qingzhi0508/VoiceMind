import Testing
@testable import VoiceMind

struct MacMicrophoneMonitorPolicyTests {
    @Test
    func toggleVisibilityRequiresSendToMac() {
        #expect(!MacMicrophoneMonitorPolicy.shouldShowToggle(sendToMacEnabled: false))
        #expect(MacMicrophoneMonitorPolicy.shouldShowToggle(sendToMacEnabled: true))
    }

    @Test
    func speakerPlaybackRequiresMacModeSendToMacAndMicMonitorToggle() {
        #expect(
            MacMicrophoneMonitorPolicy.shouldPlayThroughMacSpeaker(
                sendToMacEnabled: true,
                preferredMode: .mac,
                microphoneMonitorEnabled: true
            )
        )

        #expect(
            !MacMicrophoneMonitorPolicy.shouldPlayThroughMacSpeaker(
                sendToMacEnabled: true,
                preferredMode: .local,
                microphoneMonitorEnabled: true
            )
        )

        #expect(
            !MacMicrophoneMonitorPolicy.shouldPlayThroughMacSpeaker(
                sendToMacEnabled: false,
                preferredMode: .mac,
                microphoneMonitorEnabled: true
            )
        )

        #expect(
            !MacMicrophoneMonitorPolicy.shouldPlayThroughMacSpeaker(
                sendToMacEnabled: true,
                preferredMode: .mac,
                microphoneMonitorEnabled: false
            )
        )
    }
}
