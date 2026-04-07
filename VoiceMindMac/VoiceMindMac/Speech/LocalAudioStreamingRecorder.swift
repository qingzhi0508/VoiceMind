import AVFoundation
import Foundation

final class LocalAudioStreamingRecorder {
    private let audioEngine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private let targetFormat: AVAudioFormat

    init() {
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ) else {
            fatalError("Unable to create local audio target format")
        }

        self.targetFormat = targetFormat
    }

    var isRecording: Bool {
        audioEngine.isRunning
    }

    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    func checkMicrophonePermission() -> Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    func startStreaming(onAudioData: @escaping (Data) -> Void) throws {
        if audioEngine.isRunning {
            stopStreaming()
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw SpeechRecognitionError.audioEngineError
        }

        self.converter = converter

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            do {
                guard let pcmData = try self.convertToPCM16Data(buffer) else {
                    return
                }
                onAudioData(pcmData)
            } catch {
                print("❌ 本地音频转换失败: \(error.localizedDescription)")
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        print("✅ 本地音频流采集已启动")
    }

    func stopStreaming() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        converter = nil
        print("✅ 本地音频流采集已停止")
    }

    private func convertToPCM16Data(_ buffer: AVAudioPCMBuffer) throws -> Data? {
        guard let converter = converter else {
            return nil
        }

        let expectedFrameCount = max(
            1,
            Int(ceil(Double(buffer.frameLength) * targetFormat.sampleRate / buffer.format.sampleRate))
        )

        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: AVAudioFrameCount(expectedFrameCount)
        ) else {
            throw SpeechRecognitionError.audioEngineError
        }

        var conversionError: NSError?
        var didProvideInput = false

        let status = converter.convert(to: convertedBuffer, error: &conversionError) { _, outStatus in
            if didProvideInput {
                outStatus.pointee = .noDataNow
                return nil
            }

            didProvideInput = true
            outStatus.pointee = .haveData
            return buffer
        }

        if let conversionError {
            throw conversionError
        }

        guard status != .error, convertedBuffer.frameLength > 0 else {
            return nil
        }

        guard let floatSamples = convertedBuffer.floatChannelData?[0] else {
            return nil
        }

        let frameCount = Int(convertedBuffer.frameLength)
        let pcmSamples = (0..<frameCount).map { index -> Int16 in
            let clamped = max(-1, min(1, floatSamples[index]))
            if clamped <= -1 {
                return Int16.min
            }
            return Int16(clamped * Float(Int16.max))
        }

        return pcmSamples.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}
