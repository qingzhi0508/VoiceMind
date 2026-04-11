import AVFoundation
import Foundation

final class RemoteMicrophoneMonitorPlayer: RemoteMicrophoneMonitorPlaying {
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let eq = AVAudioUnitEQ(numberOfBands: 3)
    private var audioFormat: AVAudioFormat?

    // MARK: - Signal Processing
    private var signalProcessor = AudioSignalProcessor()
    private var feedbackDetector = AcousticFeedbackDetector()

    init() {
        audioEngine.attach(playerNode)
        audioEngine.attach(eq)
        configureEQ()
    }

    private func configureEQ() {
        // Band 0: 高通滤波器 — 80Hz 以下切除，减少低频噪声但保留更多人声温暖感
        let highPass = eq.bands[0]
        highPass.filterType = .highPass
        highPass.frequency = 80
        highPass.bypass = false

        // Band 1: 低频搁架 — 250Hz 提升 2dB，增加人声温暖度和厚度
        let lowShelf = eq.bands[1]
        lowShelf.filterType = .lowShelf
        lowShelf.frequency = 250
        lowShelf.gain = 2
        lowShelf.bypass = false

        // Band 2: 人声增强 — 3kHz 提升 3dB，带宽 1.0 倍频程，使说话更清晰
        let presence = eq.bands[2]
        presence.filterType = .parametric
        presence.frequency = 3000
        presence.bandwidth = 1.0
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

        // Convert PCM16 → Float32 with AGC + noise gate + feedback suppression
        data.withUnsafeBytes { rawBuffer in
            guard let srcSamples = rawBuffer.bindMemory(to: Int16.self).baseAddress else {
                return
            }

            guard let floatData = buffer.floatChannelData else { return }

            let totalSamples = frameCount * channelCount

            // Compute RMS
            var sumSquares: Float = 0
            for i in 0..<totalSamples {
                let sample = Float(srcSamples[i]) / Float(Int16.max)
                sumSquares += sample * sample
            }
            let rms = sqrt(sumSquares / Float(totalSamples))

            // Feedback detection
            let feedbackSeverity = feedbackDetector.process(rms: rms)

            // Signal processing (AGC + noise gate + feedback suppression)
            let result = signalProcessor.process(rms: rms, feedbackSeverity: feedbackSeverity)

            // Apply gain
            for frameIndex in 0..<frameCount {
                for ch in 0..<channelCount {
                    let srcIndex = frameIndex * channelCount + ch
                    let sample = Float(srcSamples[srcIndex]) / Float(Int16.max)
                    floatData[ch][frameIndex] = sample * result.effectiveGain
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

        signalProcessor = AudioSignalProcessor()
        feedbackDetector.reset()
    }
}
