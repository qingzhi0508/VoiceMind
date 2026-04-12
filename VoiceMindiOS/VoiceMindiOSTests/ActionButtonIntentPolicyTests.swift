import Testing
@testable import VoiceMind

struct ActionButtonIntentPolicyTests {

    // MARK: - shouldAutoStartRecognition

    @Test
    func shouldStartWhenIdleWithPermissions() {
        #expect(
            ActionButtonIntentPolicy.shouldAutoStartRecognition(
                recognitionState: .idle,
                hasPermissions: true
            )
        )
    }

    @Test
    func shouldNotStartWhenAlreadyListening() {
        #expect(
            !ActionButtonIntentPolicy.shouldAutoStartRecognition(
                recognitionState: .listening,
                hasPermissions: true
            )
        )
    }

    @Test
    func shouldNotStartWhenProcessing() {
        #expect(
            !ActionButtonIntentPolicy.shouldAutoStartRecognition(
                recognitionState: .processing,
                hasPermissions: true
            )
        )
    }

    @Test
    func shouldNotStartWithoutPermissions() {
        #expect(
            !ActionButtonIntentPolicy.shouldAutoStartRecognition(
                recognitionState: .idle,
                hasPermissions: false
            )
        )
    }

    @Test
    func shouldNotStartWhenSending() {
        #expect(
            !ActionButtonIntentPolicy.shouldAutoStartRecognition(
                recognitionState: .sending,
                hasPermissions: true
            )
        )
    }

    // MARK: - forcedMode

    @Test
    func localModeForcesLocalTranscription() {
        #expect(
            ActionButtonIntentPolicy.forcedMode(for: .local) == .local
        )
    }

    @Test
    func remoteModeForcesMacTranscription() {
        #expect(
            ActionButtonIntentPolicy.forcedMode(for: .remote) == .mac
        )
    }

    // MARK: - shouldForceRemoteMode

    @Test
    func remoteModeForcesWhenPairedAndConnected() {
        #expect(
            ActionButtonIntentPolicy.shouldForceRemoteMode(
                mode: .remote,
                isPaired: true,
                isConnected: true
            )
        )
    }

    @Test
    func remoteModeDoesNotForceWhenNotPaired() {
        #expect(
            !ActionButtonIntentPolicy.shouldForceRemoteMode(
                mode: .remote,
                isPaired: false,
                isConnected: false
            )
        )
    }

    @Test
    func localModeNeverForcesRemote() {
        #expect(
            !ActionButtonIntentPolicy.shouldForceRemoteMode(
                mode: .local,
                isPaired: true,
                isConnected: true
            )
        )
    }
}
