import Foundation

enum LocalTranscriptionPolicy {
    static func canStartLocalRecognition(
        recognitionState: RecognitionState,
        hasPermissions: Bool
    ) -> Bool {
        hasPermissions && isIdle(recognitionState)
    }

    static func shouldForwardResultToMac(
        sendToMacEnabled: Bool,
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
        connectionState: ConnectionState
    ) -> String {
        guard hasPermissions else { return "ptt_local_permissions_required" }
        if sendToMacEnabled && connectionState == .connected {
            return "ptt_local_ready_and_sync"
        }
        return "ptt_local_ready"
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
