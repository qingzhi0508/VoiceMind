import Testing
@testable import VoiceMind

struct LocalTranscriptionPolicyTests {
    @Test
    func localRecognitionDoesNotRequireMacConnection() {
        #expect(
            LocalTranscriptionPolicy.canStartLocalRecognition(
                recognitionState: .idle,
                hasPermissions: true
            )
        )
    }

    @Test
    func forwardingToMacIsDisabledByDefault() {
        #expect(
            !LocalTranscriptionPolicy.shouldForwardResultToMac(
                sendToMacEnabled: false,
                pairingState: .paired(deviceId: "ios-1", deviceName: "cayden"),
                connectionState: .connected
            )
        )
    }

    @Test
    func forwardingToMacRequiresToggleAndActiveConnection() {
        #expect(
            LocalTranscriptionPolicy.shouldForwardResultToMac(
                sendToMacEnabled: true,
                pairingState: .paired(deviceId: "ios-1", deviceName: "cayden"),
                connectionState: .connected
            )
        )

        #expect(
            !LocalTranscriptionPolicy.shouldForwardResultToMac(
                sendToMacEnabled: true,
                pairingState: .paired(deviceId: "ios-1", deviceName: "cayden"),
                connectionState: .disconnected
            )
        )
    }

    @Test
    func macCollaborationUiIsHiddenWhenSyncIsOff() {
        #expect(!LocalTranscriptionPolicy.shouldShowMacPairingOptions(sendToMacEnabled: false))
        #expect(LocalTranscriptionPolicy.shouldShowMacPairingOptions(sendToMacEnabled: true))
    }

    @Test
    func manualTextForwardingRequiresToggleConnectionAndTranscript() {
        #expect(
            LocalTranscriptionPolicy.canManuallyForwardTextToMac(
                sendToMacEnabled: true,
                connectionState: .connected,
                transcriptText: "hello"
            )
        )

        #expect(
            !LocalTranscriptionPolicy.canManuallyForwardTextToMac(
                sendToMacEnabled: false,
                connectionState: .connected,
                transcriptText: "hello"
            )
        )

        #expect(
            !LocalTranscriptionPolicy.canManuallyForwardTextToMac(
                sendToMacEnabled: true,
                connectionState: .disconnected,
                transcriptText: "hello"
            )
        )

        #expect(
            !LocalTranscriptionPolicy.canManuallyForwardTextToMac(
                sendToMacEnabled: true,
                connectionState: .connected,
                transcriptText: "   "
            )
        )
    }
}
