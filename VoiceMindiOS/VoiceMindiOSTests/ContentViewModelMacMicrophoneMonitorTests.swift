import Foundation
import SharedCore
import Testing
@testable import VoiceMind

@MainActor
struct ContentViewModelMacMicrophoneMonitorTests {
    @Test
    func pushToTalkInMacModePassesThroughSpeakerPlaybackFlag() {
        let audioStreamController = RecordingAudioStreamController()
        let viewModel = TestContentViewModel(audioStreamController: audioStreamController)

        viewModel.sendResultsToMacEnabled = true
        viewModel.preferredHomeTranscriptionMode = .mac
        viewModel.pairingState = .paired(deviceId: "mac-1", deviceName: "Office Mac")
        viewModel.connectionState = .connected
        viewModel.playMicrophoneThroughMacSpeakerEnabled = true

        viewModel.startPushToTalk()

        #expect(audioStreamController.startRequests.count == 1)
        #expect(audioStreamController.startRequests.first?.playThroughMacSpeaker == true)
    }

    @Test
    func startListenMessagesAlwaysDisableSpeakerPlayback() throws {
        let audioStreamController = RecordingAudioStreamController()
        let viewModel = TestContentViewModel(audioStreamController: audioStreamController)
        viewModel.playMicrophoneThroughMacSpeakerEnabled = true

        let payload = try JSONEncoder().encode(StartListenPayload(sessionId: "session-from-mac"))
        let envelope = MessageEnvelope(
            type: .startListen,
            payload: payload,
            timestamp: Date(),
            deviceId: "mac-1",
            hmac: nil
        )

        viewModel.connectionManager(ConnectionManager(), didReceiveMessage: envelope)

        #expect(
            audioStreamController.startRequests == [
                .init(sessionId: "session-from-mac", playThroughMacSpeaker: false)
            ]
        )
    }
}

private final class TestContentViewModel: ContentViewModel {
    override func checkPermissions() -> Bool {
        true
    }
}

private final class RecordingAudioStreamController: AudioStreamController {
    struct StartRequest: Equatable {
        let sessionId: String
        let playThroughMacSpeaker: Bool
    }

    private(set) var startRequests: [StartRequest] = []

    override func startStreaming(sessionId: String, playThroughMacSpeaker: Bool = false) throws {
        startRequests.append(
            StartRequest(
                sessionId: sessionId,
                playThroughMacSpeaker: playThroughMacSpeaker
            )
        )
    }

    override func stopStreaming() { }
}
