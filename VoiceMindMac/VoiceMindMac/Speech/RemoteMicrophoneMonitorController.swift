import AVFoundation
import Foundation

protocol RemoteMicrophoneMonitorPlaying: AnyObject {
    func start(sampleRate: Double, channels: AVAudioChannelCount, format: String) throws
    func appendPCM16(_ data: Data) throws
    func stop()
}

enum MonitorPlaybackError: Error {
    case deviceUnavailable
    case invalidPCMData
    case unsupportedFormat(String)
    case notStarted
}

final class RemoteMicrophoneMonitorController {
    private let player: RemoteMicrophoneMonitorPlaying

    private(set) var currentSessionId: String?
    private(set) var isRelayActive = false

    init(player: RemoteMicrophoneMonitorPlaying) {
        self.player = player
    }

    func startSession(
        sessionId: String,
        sampleRate: Int,
        channels: Int,
        format: String,
        playThroughMacSpeaker: Bool
    ) throws {
        if currentSessionId != nil || isRelayActive {
            stopSession(sessionId: nil)
        }
        currentSessionId = sessionId

        guard playThroughMacSpeaker else {
            isRelayActive = false
            return
        }

        try player.start(
            sampleRate: Double(sampleRate),
            channels: AVAudioChannelCount(channels),
            format: format
        )
        isRelayActive = true
    }

    func appendAudio(_ data: Data, sessionId: String) throws {
        guard isRelayActive, sessionId == currentSessionId else {
            return
        }

        do {
            try player.appendPCM16(data)
        } catch {
            print("⚠️ 远端麦克风播放已降级: \(error)")
            player.stop()
            isRelayActive = false
        }
    }

    func stopSession(sessionId: String?) {
        guard sessionId == nil || sessionId == currentSessionId else {
            return
        }

        player.stop()
        currentSessionId = nil
        isRelayActive = false
    }
}
