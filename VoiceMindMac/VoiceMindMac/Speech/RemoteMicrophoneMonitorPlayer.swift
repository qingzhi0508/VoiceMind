import AVFoundation
import Foundation

final class RemoteMicrophoneMonitorPlayer: RemoteMicrophoneMonitorPlaying {
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var audioFormat: AVAudioFormat?

    init() {
        audioEngine.attach(playerNode)
    }

    func start(sampleRate: Double, channels: AVAudioChannelCount, format: String) throws {
        guard format == "pcm16" else {
            throw MonitorPlaybackError.unsupportedFormat(format)
        }

        stop()

        guard let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false
        ) else {
            throw MonitorPlaybackError.deviceUnavailable
        }

        self.audioFormat = audioFormat
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: audioFormat)
        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            throw MonitorPlaybackError.deviceUnavailable
        }

        playerNode.play()
    }

    func appendPCM16(_ data: Data) throws {
        guard let audioFormat else {
            throw MonitorPlaybackError.notStarted
        }

        guard !data.isEmpty else {
            return
        }

        let channelCount = Int(audioFormat.channelCount)
        let bytesPerFrame = MemoryLayout<Int16>.size * max(channelCount, 1)
        guard data.count % bytesPerFrame == 0 else {
            throw MonitorPlaybackError.invalidPCMData
        }

        let frameCount = data.count / bytesPerFrame
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFormat,
            frameCapacity: AVAudioFrameCount(frameCount)
        ) else {
            throw MonitorPlaybackError.deviceUnavailable
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)

        guard let channelData = buffer.int16ChannelData else {
            throw MonitorPlaybackError.invalidPCMData
        }

        data.withUnsafeBytes { rawBuffer in
            guard let samples = rawBuffer.bindMemory(to: Int16.self).baseAddress else {
                return
            }

            if channelCount == 1 {
                channelData[0].update(from: samples, count: frameCount)
                return
            }

            for frameIndex in 0..<frameCount {
                for channelIndex in 0..<channelCount {
                    let sampleIndex = frameIndex * channelCount + channelIndex
                    channelData[channelIndex][frameIndex] = samples[sampleIndex]
                }
            }
        }

        playerNode.scheduleBuffer(buffer)
    }

    func stop() {
        if playerNode.isPlaying {
            playerNode.stop()
        }

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.reset()
        audioFormat = nil
    }
}
