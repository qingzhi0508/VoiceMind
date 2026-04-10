import AVFoundation
import Foundation

final class RemoteMicrophoneMonitorPlayer: RemoteMicrophoneMonitorPlaying {
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let eq = AVAudioUnitEQ(numberOfBands: 2)
    private var audioFormat: AVAudioFormat?

    /// 软件增益倍数，用于放大麦克风采集的低音量 PCM 数据
    private let gain: Float = 2.5

    init() {
        audioEngine.attach(playerNode)
        audioEngine.attach(eq)
        configureEQ()
    }

    private func configureEQ() {
        // Band 0: 高通滤波器 — 切除 150Hz 以下低频，减少低频回音和闷响
        let highPass = eq.bands[0]
        highPass.filterType = .highPass
        highPass.frequency = 150
        highPass.bypass = false

        // Band 1: 人声增强 — 提升 2-4kHz 使说话更清晰
        let presence = eq.bands[1]
        presence.filterType = .parametric
        presence.frequency = 3000
        presence.bandwidth = 1.5
        presence.gain = 3
        presence.bypass = false
    }

    func start(sampleRate: Double, channels: AVAudioChannelCount, format: String) throws {
        guard format == "pcm16" else {
            throw MonitorPlaybackError.unsupportedFormat(format)
        }

        stop()

        // Use Float32 non-interleaved — AVAudioEngine's native format
        guard let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false
        ) else {
            throw MonitorPlaybackError.deviceUnavailable
        }

        self.audioFormat = audioFormat
        playerNode.volume = 1.0
        audioEngine.connect(playerNode, to: eq, format: audioFormat)
        audioEngine.connect(eq, to: audioEngine.mainMixerNode, format: audioFormat)
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

        // Convert PCM16 → Float32 with gain, de-interleaving into non-interleaved buffer
        data.withUnsafeBytes { rawBuffer in
            guard let srcSamples = rawBuffer.bindMemory(to: Int16.self).baseAddress else {
                return
            }

            guard let floatData = buffer.floatChannelData else { return }

            for frameIndex in 0..<frameCount {
                for ch in 0..<channelCount {
                    let srcIndex = frameIndex * channelCount + ch
                    let sample = Float(srcSamples[srcIndex]) / Float(Int16.max)
                    floatData[ch][frameIndex] = sample * gain
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
