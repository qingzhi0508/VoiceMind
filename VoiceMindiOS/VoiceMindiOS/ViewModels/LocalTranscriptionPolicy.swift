import Foundation

enum HomeTranscriptionMode: String {
    case local
    case mac
}

enum LocalTranscriptionPolicy {
    static func effectiveHomeTranscriptionMode(
        sendToMacEnabled: Bool,
        preferredMode: HomeTranscriptionMode
    ) -> HomeTranscriptionMode {
        sendToMacEnabled ? preferredMode : .local
    }

    static func shouldShowTranscriptPreviewOnHome(
        mode: HomeTranscriptionMode,
        recognitionState: RecognitionState,
        transcriptText: String
    ) -> Bool {
        guard mode == .local else { return false }
        switch recognitionState {
        case .listening, .processing, .sending:
            return true
        case .idle:
            return !transcriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    static func shouldPromptForHomeMacAction(
        sendToMacEnabled: Bool,
        preferredMode: HomeTranscriptionMode,
        connectionState: ConnectionState
    ) -> Bool {
        guard sendToMacEnabled else { return false }
        let mode = effectiveHomeTranscriptionMode(
            sendToMacEnabled: sendToMacEnabled,
            preferredMode: preferredMode
        )
        return (mode == .mac || mode == .local) && connectionState != .connected
    }

    static func canStartLocalRecognition(
        recognitionState: RecognitionState,
        hasPermissions: Bool
    ) -> Bool {
        hasPermissions && isIdle(recognitionState)
    }

    static func canStartPrimaryCapture(
        recognitionState: RecognitionState,
        hasPermissions: Bool,
        sendToMacEnabled: Bool,
        preferredMode: HomeTranscriptionMode,
        connectionState: ConnectionState
    ) -> Bool {
        guard !shouldPromptForHomeMacAction(
            sendToMacEnabled: sendToMacEnabled,
            preferredMode: preferredMode,
            connectionState: connectionState
        ) else {
            return false
        }

        let mode = effectiveHomeTranscriptionMode(
            sendToMacEnabled: sendToMacEnabled,
            preferredMode: preferredMode
        )

        switch mode {
        case .local:
            return canStartLocalRecognition(
                recognitionState: recognitionState,
                hasPermissions: hasPermissions
            )
        case .mac:
            return hasPermissions && isIdle(recognitionState) && connectionState == .connected
        }
    }

    static func shouldForwardResultToMac(
        sendToMacEnabled: Bool,
        preferredMode: HomeTranscriptionMode,
        pairingState: PairingState,
        connectionState: ConnectionState
    ) -> Bool {
        guard sendToMacEnabled else { return false }
        guard case .paired = pairingState else { return false }
        guard connectionState == .connected else { return false }
        return true
    }

    static func shouldShowMacPairingOptions(sendToMacEnabled: Bool) -> Bool {
        sendToMacEnabled
    }

    static func shouldStartBonjourBrowsing(sendToMacEnabled: Bool) -> Bool {
        sendToMacEnabled
    }

    static func shouldAutoReconnectToMac(
        sendToMacEnabled: Bool,
        pairingState: PairingState
    ) -> Bool {
        guard sendToMacEnabled else { return false }
        guard case .paired = pairingState else { return false }
        return true
    }

    static func shouldRetryReconnectOnDisconnect(
        sendToMacEnabled: Bool,
        pairingState: PairingState,
        reconnectNeedsManualAction: Bool
    ) -> Bool {
        guard shouldAutoReconnectToMac(
            sendToMacEnabled: sendToMacEnabled,
            pairingState: pairingState
        ) else {
            return false
        }
        return !reconnectNeedsManualAction
    }

    static func canManuallyForwardTextToMac(
        sendToMacEnabled: Bool,
        connectionState: ConnectionState,
        transcriptText: String
    ) -> Bool {
        guard sendToMacEnabled else { return false }
        guard connectionState == .connected else { return false }
        return !transcriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func idleStatusMessageKey(
        hasPermissions: Bool,
        sendToMacEnabled: Bool,
        preferredMode: HomeTranscriptionMode,
        connectionState: ConnectionState
    ) -> String {
        guard hasPermissions else { return "ptt_local_permissions_required" }
        switch effectiveHomeTranscriptionMode(
            sendToMacEnabled: sendToMacEnabled,
            preferredMode: preferredMode
        ) {
        case .local:
            return sendToMacEnabled && connectionState == .connected
            ? "ptt_local_ready_and_sync"
            : "ptt_local_ready"
        case .mac:
            return connectionState == .connected ? "ptt_hold_to_talk" : "ptt_connect_to_talk"
        }
    }

    private static func isIdle(_ state: RecognitionState) -> Bool {
        switch state {
        case .idle:
            return true
        case .listening, .processing, .sending:
            return false
        }
    }
}
