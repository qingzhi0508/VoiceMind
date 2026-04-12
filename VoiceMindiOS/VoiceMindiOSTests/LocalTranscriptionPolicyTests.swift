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
        // Local mode can always start regardless of Mac connection
        #expect(
            LocalTranscriptionPolicy.canStartPrimaryCapture(
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

        // .mac mode also shows transcript preview during recognition and when text exists
        #expect(
            LocalTranscriptionPolicy.shouldShowTranscriptPreviewOnHome(
                mode: .mac,
                recognitionState: .listening,
                transcriptText: ""
            )
        )

        #expect(
            LocalTranscriptionPolicy.shouldShowTranscriptPreviewOnHome(
                mode: .mac,
                recognitionState: .idle,
                transcriptText: "hello"
            )
        )
    }

    @Test
    func microphoneModeRequiresConnectionToStart() {
        #expect(
            LocalTranscriptionPolicy.canStartPrimaryCapture(
                recognitionState: .idle,
                hasPermissions: true,
                sendToMacEnabled: true,
                preferredMode: .microphone,
                pairingState: .paired(deviceId: "ios-1", deviceName: "cayden"),
                connectionState: .connected
            )
        )

        #expect(
            !LocalTranscriptionPolicy.canStartPrimaryCapture(
                recognitionState: .idle,
                hasPermissions: true,
                sendToMacEnabled: true,
                preferredMode: .microphone,
                pairingState: .paired(deviceId: "ios-1", deviceName: "cayden"),
                connectionState: .disconnected
            )
        )
    }

    @Test
    func microphoneModePromptsForConnectionWhenMacIsNotReady() {
        #expect(
            LocalTranscriptionPolicy.shouldPromptForHomeMacAction(
                sendToMacEnabled: true,
                preferredMode: .microphone,
                pairingState: .unpaired,
                connectionState: .disconnected
            )
        )

        #expect(
            !LocalTranscriptionPolicy.shouldPromptForHomeMacAction(
                sendToMacEnabled: true,
                preferredMode: .microphone,
                pairingState: .paired(deviceId: "ios-1", deviceName: "cayden"),
                connectionState: .connected
            )
        )
    }

    @Test
    func microphoneModeIdleStatusMessage() {
        #expect(
            LocalTranscriptionPolicy.idleStatusMessageKey(
                hasPermissions: true,
                sendToMacEnabled: true,
                preferredMode: .microphone,
                pairingState: .paired(deviceId: "ios-1", deviceName: "cayden"),
                connectionState: .connected
            ) == "ptt_mic_mode_ready"
        )

        #expect(
            LocalTranscriptionPolicy.idleStatusMessageKey(
                hasPermissions: true,
                sendToMacEnabled: true,
                preferredMode: .microphone,
                pairingState: .unpaired,
                connectionState: .disconnected
            ) == "ptt_connect_for_mic_mode"
        )
    }

    @Test
    func microphoneModeDoesNotShowTranscriptPreview() {
        #expect(
            !LocalTranscriptionPolicy.shouldShowTranscriptPreviewOnHome(
                mode: .microphone,
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
            !LocalTranscriptionPolicy.shouldPromptForHomeMacAction(
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

    // MARK: - Text Input Mode

    @Test
    func textInputModeCannotStartPrimaryCapture() {
        #expect(
            !LocalTranscriptionPolicy.canStartPrimaryCapture(
                recognitionState: .idle,
                hasPermissions: true,
                sendToMacEnabled: true,
                preferredMode: .textInput,
                pairingState: .paired(deviceId: "ios-1", deviceName: "cayden"),
                connectionState: .connected
            )
        )
    }

    @Test
    func textInputModeShowsTranscriptPreviewAlways() {
        #expect(
            LocalTranscriptionPolicy.shouldShowTranscriptPreviewOnHome(
                mode: .textInput,
                recognitionState: .idle,
                transcriptText: ""
            )
        )
        #expect(
            LocalTranscriptionPolicy.shouldShowTranscriptPreviewOnHome(
                mode: .textInput,
                recognitionState: .idle,
                transcriptText: "hello"
            )
        )
    }

    @Test
    func textInputModeIdleStatusMessage() {
        #expect(
            LocalTranscriptionPolicy.idleStatusMessageKey(
                hasPermissions: true,
                sendToMacEnabled: true,
                preferredMode: .textInput,
                pairingState: .paired(deviceId: "ios-1", deviceName: "cayden"),
                connectionState: .connected
            ) == "ptt_text_input_ready"
        )
        #expect(
            LocalTranscriptionPolicy.idleStatusMessageKey(
                hasPermissions: true,
                sendToMacEnabled: true,
                preferredMode: .textInput,
                pairingState: .unpaired,
                connectionState: .disconnected
            ) == "ptt_text_input_connect"
        )
    }

    @Test
    func canSendTextInputRequiresConnectionAndText() {
        let paired = PairingState.paired(deviceId: "ios-1", deviceName: "cayden")
        // Connected + non-empty text → true
        #expect(
            LocalTranscriptionPolicy.canSendTextInput(
                sendToMacEnabled: true,
                pairingState: paired,
                connectionState: .connected,
                transcriptText: "hello"
            )
        )
        // Disconnected → false
        #expect(
            !LocalTranscriptionPolicy.canSendTextInput(
                sendToMacEnabled: true,
                pairingState: paired,
                connectionState: .disconnected,
                transcriptText: "hello"
            )
        )
        // Empty text → false
        #expect(
            !LocalTranscriptionPolicy.canSendTextInput(
                sendToMacEnabled: true,
                pairingState: paired,
                connectionState: .connected,
                transcriptText: "   "
            )
        )
        // Sync disabled → false
        #expect(
            !LocalTranscriptionPolicy.canSendTextInput(
                sendToMacEnabled: false,
                pairingState: paired,
                connectionState: .connected,
                transcriptText: "hello"
            )
        )
    }

    @Test
    func shouldShowTextInputAreaOnlyForTextInputMode() {
        #expect(LocalTranscriptionPolicy.shouldShowTextInputArea(mode: .textInput))
        #expect(!LocalTranscriptionPolicy.shouldShowTextInputArea(mode: .local))
        #expect(!LocalTranscriptionPolicy.shouldShowTextInputArea(mode: .mac))
        #expect(!LocalTranscriptionPolicy.shouldShowTextInputArea(mode: .microphone))
    }

    @Test
    func shouldHideRecordingControlForTextInputMode() {
        #expect(!LocalTranscriptionPolicy.shouldShowRecordingControl(mode: .textInput))
        #expect(LocalTranscriptionPolicy.shouldShowRecordingControl(mode: .local))
        #expect(LocalTranscriptionPolicy.shouldShowRecordingControl(mode: .mac))
        #expect(LocalTranscriptionPolicy.shouldShowRecordingControl(mode: .microphone))
    }

    @Test
    func effectiveModeReturnsTextInputWhenEnabled() {
        #expect(
            LocalTranscriptionPolicy.effectiveHomeTranscriptionMode(
                sendToMacEnabled: true,
                preferredMode: .textInput
            ) == .textInput
        )
    }

    @Test
    func effectiveModeFallsBackToLocalForTextInputWhenSyncDisabled() {
        #expect(
            LocalTranscriptionPolicy.effectiveHomeTranscriptionMode(
                sendToMacEnabled: false,
                preferredMode: .textInput
            ) == .local
        )
    }
}
