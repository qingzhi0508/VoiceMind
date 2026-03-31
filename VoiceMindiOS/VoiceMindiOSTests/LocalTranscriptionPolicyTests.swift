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
    func primaryCaptureRequiresConnectionWhenMacCollaborationIsEnabled() {
        #expect(
            !LocalTranscriptionPolicy.canStartPrimaryCapture(
                recognitionState: .idle,
                hasPermissions: true,
                sendToMacEnabled: true,
                preferredMode: .local,
                pairingState: .unpaired,
                connectionState: .disconnected
            )
        )

        #expect(
            LocalTranscriptionPolicy.canStartPrimaryCapture(
                recognitionState: .idle,
                hasPermissions: true,
                sendToMacEnabled: true,
                preferredMode: .local,
                pairingState: .paired(deviceId: "ios-1", deviceName: "cayden"),
                connectionState: .connected
            )
        )

        #expect(
            LocalTranscriptionPolicy.canStartPrimaryCapture(
                recognitionState: .idle,
                hasPermissions: true,
                sendToMacEnabled: false,
                preferredMode: .local,
                pairingState: .unpaired,
                connectionState: .disconnected
            )
        )
    }

    @Test
    func forwardingToMacIsDisabledByDefault() {
        #expect(
            !LocalTranscriptionPolicy.shouldForwardResultToMac(
                sendToMacEnabled: false,
                preferredMode: .local,
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
                preferredMode: .mac,
                pairingState: .paired(deviceId: "ios-1", deviceName: "cayden"),
                connectionState: .connected
            )
        )

        #expect(
            !LocalTranscriptionPolicy.shouldForwardResultToMac(
                sendToMacEnabled: true,
                preferredMode: .mac,
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
    func bonjourBrowsingRequiresMacCollaborationToggle() {
        #expect(!LocalTranscriptionPolicy.shouldStartBonjourBrowsing(sendToMacEnabled: false))
        #expect(LocalTranscriptionPolicy.shouldStartBonjourBrowsing(sendToMacEnabled: true))
    }

    @Test
    func autoReconnectRequiresToggleAndPairing() {
        #expect(
            !LocalTranscriptionPolicy.shouldAutoReconnectToMac(
                sendToMacEnabled: false,
                pairingState: .paired(deviceId: "ios-1", deviceName: "cayden")
            )
        )

        #expect(
            !LocalTranscriptionPolicy.shouldAutoReconnectToMac(
                sendToMacEnabled: true,
                pairingState: .unpaired
            )
        )

        #expect(
            LocalTranscriptionPolicy.shouldAutoReconnectToMac(
                sendToMacEnabled: true,
                pairingState: .paired(deviceId: "ios-1", deviceName: "cayden")
            )
        )
    }

    @Test
    func effectiveHomeModeFallsBackToLocalWhenMacCollaborationIsOff() {
        #expect(
            LocalTranscriptionPolicy.effectiveHomeTranscriptionMode(
                sendToMacEnabled: false,
                preferredMode: .mac
            ) == .local
        )
    }

    @Test
    func effectiveHomeModeUsesPreferredModeWhenMacCollaborationIsOn() {
        #expect(
            LocalTranscriptionPolicy.effectiveHomeTranscriptionMode(
                sendToMacEnabled: true,
                preferredMode: .mac
            ) == .mac
        )
    }

    @Test
    func transcriptPreviewOnHomeRequiresLocalModeCompletedRecognitionAndText() {
        #expect(
            LocalTranscriptionPolicy.shouldShowTranscriptPreviewOnHome(
                mode: .local,
                recognitionState: .listening,
                transcriptText: ""
            )
        )

        #expect(
            LocalTranscriptionPolicy.shouldShowTranscriptPreviewOnHome(
                mode: .local,
                recognitionState: .processing,
                transcriptText: ""
            )
        )

        #expect(
            LocalTranscriptionPolicy.shouldShowTranscriptPreviewOnHome(
                mode: .local,
                recognitionState: .idle,
                transcriptText: "hello"
            )
        )

        #expect(
            !LocalTranscriptionPolicy.shouldShowTranscriptPreviewOnHome(
                mode: .local,
                recognitionState: .idle,
                transcriptText: "   "
            )
        )

        #expect(
            !LocalTranscriptionPolicy.shouldShowTranscriptPreviewOnHome(
                mode: .local,
                recognitionState: .idle,
                transcriptText: "   "
            )
        )

        #expect(
            !LocalTranscriptionPolicy.shouldShowTranscriptPreviewOnHome(
                mode: .mac,
                recognitionState: .listening,
                transcriptText: ""
            )
        )
    }

    @Test
    func macModeRequiresActionPromptWhenMacIsNotConnected() {
        #expect(
            LocalTranscriptionPolicy.shouldPromptForHomeMacAction(
                sendToMacEnabled: true,
                preferredMode: .mac,
                pairingState: .unpaired,
                connectionState: .disconnected
            )
        )

        #expect(
            !LocalTranscriptionPolicy.shouldPromptForHomeMacAction(
                sendToMacEnabled: true,
                preferredMode: .mac,
                pairingState: .paired(deviceId: "ios-1", deviceName: "cayden"),
                connectionState: .connected
            )
        )

        #expect(
            LocalTranscriptionPolicy.shouldPromptForHomeMacAction(
                sendToMacEnabled: true,
                preferredMode: .local,
                pairingState: .unpaired,
                connectionState: .disconnected
            )
        )

        #expect(
            !LocalTranscriptionPolicy.shouldPromptForHomeMacAction(
                sendToMacEnabled: false,
                preferredMode: .local,
                pairingState: .unpaired,
                connectionState: .disconnected
            )
        )
    }

    @Test
    func forwardingToMacRequiresMacModeAndConnection() {
        #expect(
            LocalTranscriptionPolicy.shouldForwardResultToMac(
                sendToMacEnabled: true,
                preferredMode: .local,
                pairingState: .paired(deviceId: "ios-1", deviceName: "cayden"),
                connectionState: .connected
            )
        )

        #expect(
            LocalTranscriptionPolicy.shouldForwardResultToMac(
                sendToMacEnabled: true,
                preferredMode: .mac,
                pairingState: .paired(deviceId: "ios-1", deviceName: "cayden"),
                connectionState: .connected
            )
        )

        #expect(
            !LocalTranscriptionPolicy.shouldForwardResultToMac(
                sendToMacEnabled: true,
                preferredMode: .local,
                pairingState: .paired(deviceId: "ios-1", deviceName: "cayden"),
                connectionState: .disconnected
            )
        )
    }

    @Test
    func localModeShowsSyncReadyMessageWhenMacIsConnected() {
        #expect(
            LocalTranscriptionPolicy.idleStatusMessageKey(
                hasPermissions: true,
                sendToMacEnabled: true,
                preferredMode: .local,
                pairingState: .paired(deviceId: "ios-1", deviceName: "cayden"),
                connectionState: .connected
            ) == "ptt_local_ready_and_sync"
        )
    }

    @Test
    func manualTextForwardingRequiresToggleConnectionAndTranscript() {
        #expect(
            LocalTranscriptionPolicy.canManuallyForwardTextToMac(
                sendToMacEnabled: true,
                pairingState: .paired(deviceId: "ios-1", deviceName: "cayden"),
                connectionState: .connected,
                transcriptText: "hello"
            )
        )

        #expect(
            !LocalTranscriptionPolicy.canManuallyForwardTextToMac(
                sendToMacEnabled: false,
                pairingState: .paired(deviceId: "ios-1", deviceName: "cayden"),
                connectionState: .connected,
                transcriptText: "hello"
            )
        )

        #expect(
            !LocalTranscriptionPolicy.canManuallyForwardTextToMac(
                sendToMacEnabled: true,
                pairingState: .paired(deviceId: "ios-1", deviceName: "cayden"),
                connectionState: .disconnected,
                transcriptText: "hello"
            )
        )

        #expect(
            !LocalTranscriptionPolicy.canManuallyForwardTextToMac(
                sendToMacEnabled: true,
                pairingState: .paired(deviceId: "ios-1", deviceName: "cayden"),
                connectionState: .connected,
                transcriptText: "   "
            )
        )
    }

    @Test
    func unpairedSocketConnectionDoesNotCountAsMacReadyState() {
        #expect(
            !LocalTranscriptionPolicy.canStartPrimaryCapture(
                recognitionState: .idle,
                hasPermissions: true,
                sendToMacEnabled: true,
                preferredMode: .mac,
                pairingState: .unpaired,
                connectionState: .connected
            )
        )

        #expect(
            LocalTranscriptionPolicy.shouldPromptForHomeMacAction(
                sendToMacEnabled: true,
                preferredMode: .mac,
                pairingState: .unpaired,
                connectionState: .connected
            )
        )

        #expect(
            !LocalTranscriptionPolicy.canManuallyForwardTextToMac(
                sendToMacEnabled: true,
                pairingState: .unpaired,
                connectionState: .connected,
                transcriptText: "hello"
            )
        )

        #expect(
            LocalTranscriptionPolicy.idleStatusMessageKey(
                hasPermissions: true,
                sendToMacEnabled: true,
                preferredMode: .local,
                pairingState: .unpaired,
                connectionState: .connected
            ) == "ptt_local_ready"
        )
    }

    @Test
    func notPairedErrorsRequireRePairingRecovery() {
        #expect(PairingErrorRecoveryPolicy.requiresRePairing(for: "not_paired"))
        #expect(PairingErrorRecoveryPolicy.messageKey(for: "not_paired") == "pairing_repair_required")
        #expect(!PairingErrorRecoveryPolicy.requiresRePairing(for: "invalid_code"))
        #expect(PairingErrorRecoveryPolicy.messageKey(for: "invalid_code") == nil)
    }
}
