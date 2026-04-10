import Foundation
import XCTest
@testable import VoiceMind

final class RemoteMicrophoneMonitorControllerTests: XCTestCase {
    func testStartRelayBootsPlayerOnlyWhenFlagIsEnabled() throws {
        let player = MockRemoteMicrophoneMonitorPlayer()
        let controller = RemoteMicrophoneMonitorController(player: player)

        try controller.startSession(
            sessionId: "session-1",
            sampleRate: 16_000,
            channels: 1,
            format: "pcm16",
            playThroughMacSpeaker: true
        )

        XCTAssertEqual(
            player.startCalls,
            [.init(sampleRate: 16_000, channels: 1, format: "pcm16")]
        )
        XCTAssertTrue(controller.isRelayActive)
    }

    func testAppendAudioIsIgnoredWhenPlaybackIsDisabled() throws {
        let player = MockRemoteMicrophoneMonitorPlayer()
        let controller = RemoteMicrophoneMonitorController(player: player)

        try controller.startSession(
            sessionId: "session-1",
            sampleRate: 16_000,
            channels: 1,
            format: "pcm16",
            playThroughMacSpeaker: false
        )

        try controller.appendAudio(Data([0x00, 0x01]), sessionId: "session-1")

        XCTAssertTrue(player.appendedData.isEmpty)
        XCTAssertFalse(controller.isRelayActive)
    }

    func testPlaybackFailureDisablesRelayButDoesNotThrowPastController() throws {
        let player = MockRemoteMicrophoneMonitorPlayer()
        player.errorOnAppend = MonitorPlaybackError.deviceUnavailable
        let controller = RemoteMicrophoneMonitorController(player: player)

        try controller.startSession(
            sessionId: "session-1",
            sampleRate: 16_000,
            channels: 1,
            format: "pcm16",
            playThroughMacSpeaker: true
        )

        XCTAssertNoThrow(try controller.appendAudio(Data([0x00, 0x01]), sessionId: "session-1"))
        XCTAssertFalse(controller.isRelayActive)
        XCTAssertEqual(player.stopCallCount, 1)
    }
}

private final class MockRemoteMicrophoneMonitorPlayer: RemoteMicrophoneMonitorPlaying {
    struct StartCall: Equatable {
        let sampleRate: Double
        let channels: UInt32
        let format: String
    }

    var startCalls: [StartCall] = []
    var appendedData: [Data] = []
    var stopCallCount = 0
    var errorOnAppend: Error?

    func start(sampleRate: Double, channels: UInt32, format: String) throws {
        startCalls.append(.init(sampleRate: sampleRate, channels: channels, format: format))
    }

    func appendPCM16(_ data: Data) throws {
        if let errorOnAppend {
            throw errorOnAppend
        }
        appendedData.append(data)
    }

    func stop() {
        stopCallCount += 1
    }
}
