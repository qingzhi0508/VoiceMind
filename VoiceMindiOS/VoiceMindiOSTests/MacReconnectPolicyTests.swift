import Testing
@testable import VoiceMind

struct MacReconnectPolicyTests {
    @Test
    func pairedSessionAutoReconnectsAfterDisconnectWhenManualActionNotRequired() {
        #expect(
            LocalTranscriptionPolicy.shouldRetryReconnectOnDisconnect(
                sendToMacEnabled: true,
                pairingState: .paired(deviceId: "mac-1", deviceName: "MacBook Pro"),
                reconnectNeedsManualAction: false
            )
        )
    }

    @Test
    func manualReconnectStateDoesNotAutoRetryAgain() {
        #expect(
            !LocalTranscriptionPolicy.shouldRetryReconnectOnDisconnect(
                sendToMacEnabled: true,
                pairingState: .paired(deviceId: "mac-1", deviceName: "MacBook Pro"),
                reconnectNeedsManualAction: true
            )
        )
    }

    @Test
    func unpairedStateDoesNotAutoRetry() {
        #expect(
            !LocalTranscriptionPolicy.shouldRetryReconnectOnDisconnect(
                sendToMacEnabled: true,
                pairingState: .unpaired,
                reconnectNeedsManualAction: false
            )
        )
    }
}
