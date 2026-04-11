import Foundation
import Speech
import AVFoundation
import CoreGraphics
import SharedCore
import UIKit

/// iOS 端音频流传输器
/// 负责捕获音频并发送到 Mac 端进行识别
class AudioStreamController: NSObject {

    // MARK: - Properties

    weak var delegate: AudioStreamControllerDelegate?

    private let audioEngine = AVAudioEngine()
    private var currentSessionId: String?
    private var sequenceNumber: Int = 0
    private var isStreaming: Bool = false
    private var outputFormat: AVAudioFormat?
    private var audioConverter: AVAudioConverter?
    private var smoothedLevel: CGFloat = 0
    private var lastLevelUpdateTime: TimeInterval = 0
    private let levelSmoothing: CGFloat = 0.3
    private let minDecibels: Float = -60
    private let levelUpdateInterval: TimeInterval = 1.0 / 45.0

    var selectedLanguage: String = "zh-CN"

    // MARK: - Public Methods

    func checkPermissions() -> Bool {
        return AVAudioApplication.shared.recordPermission == .granted
    }

    func requestPermissions(completion: @escaping (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    /// 开始音频流传输
    func startStreaming(sessionId: String, playThroughMacSpeaker: Bool = false) throws {
        guard checkPermissions() else {
            throw AudioStreamError.permissionDenied
        }

        guard !isStreaming else {
            print("⚠️ 音频流已在传输中")
            return
        }

        print("🎤 开始音频流传输")
        print("   Session ID: \(sessionId)")
        print("   语言: \(selectedLanguage)")

        currentSessionId = sessionId
        sequenceNumber = 0
        isStreaming = true
        do {
            // 话筒播放模式使用 48kHz 提升音质；识别模式使用 16kHz 匹配模型
            let sampleRate: Double = playThroughMacSpeaker ? 48000 : 16000
            let channels: AVAudioChannelCount = 1

            // 配置音频会话。不要强制设置输入通道数，部分设备在首次激活时会直接失败。
            let audioSession = AVAudioSession.sharedInstance()
            if playThroughMacSpeaker {
                // 话筒播放模式：measurement 模式保留完整采集音量，不经过系统 AGC 衰减
                // 回声抑制由 Mac 端 AcousticFeedbackDetector 处理
                try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            } else {
                // 普通识别模式：仅录音，measurement 模式减少系统信号处理
                try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            }
            try audioSession.setPreferredSampleRate(sampleRate)
            try audioSession.setPreferredIOBufferDuration(0.02)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            guard let format = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: sampleRate,
                channels: channels,
                interleaved: false
            ) else {
                throw AudioStreamError.audioFormatError
            }

            print("📊 音频格式:")
            print("   采样率: \(Int(sampleRate)) Hz")
            print("   通道数: \(channels)")
            print("   格式: PCM16")

            // 发送 audioStart 消息
            delegate?.audioStreamController(self, didStartStream: AudioStartPayload(
                sessionId: sessionId,
                language: selectedLanguage,
                sampleRate: Int(sampleRate),
                channels: Int(channels),
                format: "pcm16",
                playThroughMacSpeaker: playThroughMacSpeaker
            ))

            // 安装音频 tap
            let inputNode = audioEngine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)

            guard let converter = AVAudioConverter(from: inputFormat, to: format) else {
                throw AudioStreamError.audioFormatError
            }

            outputFormat = format
            audioConverter = converter

            inputNode.removeTap(onBus: 0)
            // 使用更小的缓冲区减少首包延迟
            inputNode.installTap(onBus: 0, bufferSize: 512, format: inputFormat) { [weak self] buffer, _ in
                self?.processAudioBuffer(buffer)
            }

            // 启动音频引擎
            audioEngine.prepare()
            try audioEngine.start()

            // 触发震动反馈
            DispatchQueue.main.async {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.prepare()
                generator.impactOccurred()
            }

            print("✅ 音频引擎已启动")
        } catch {
            isStreaming = false
            currentSessionId = nil
            sequenceNumber = 0
            outputFormat = nil
            audioConverter = nil
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("❌ 启动音频流失败: \(error.localizedDescription)")
            throw error
        }
    }

    /// 停止音频流传输
    func stopStreaming() {
        guard isStreaming else {
            return
        }

        print("🛑 停止音频流传输")

        isStreaming = false
        smoothedLevel = 0
        lastLevelUpdateTime = 0
        delegate?.audioStreamController(self, didUpdateAudioLevel: 0)

        // 停止音频引擎
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioConverter = nil
        outputFormat = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        // 发送 audioEnd 消息
        if let sessionId = currentSessionId {
            delegate?.audioStreamController(self, didEndStream: AudioEndPayload(sessionId: sessionId))
        }

        currentSessionId = nil
        sequenceNumber = 0

        print("✅ 音频流传输已停止")
    }

    // MARK: - Private Methods

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isStreaming, let sessionId = currentSessionId else {
            return
        }

        updateAudioLevel(with: buffer)

        guard let convertedBuffer = convertBufferIfNeeded(buffer) else {
            print("⚠️ 无法转换音频缓冲区")
            return
        }

        // 将 AVAudioPCMBuffer 转换为 Data
        guard let audioData = bufferToData(convertedBuffer) else {
            print("⚠️ 无法转换音频缓冲区")
            return
        }

        // 发送音频数据
        let payload = AudioDataPayload(
            sessionId: sessionId,
            audioData: audioData,
            sequenceNumber: sequenceNumber
        )

        delegate?.audioStreamController(self, didCaptureAudio: payload)

        sequenceNumber += 1

        // 每 50 个包打印一次日志（因为包变大了，频率降低）
        if sequenceNumber % 50 == 0 {
            print("📤 已发送 \(sequenceNumber) 个音频包")
        }
    }

    private func convertBufferIfNeeded(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let outputFormat = outputFormat, let audioConverter = audioConverter else {
            return nil
        }

        if buffer.format == outputFormat {
            return buffer
        }

        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let estimatedFrameCapacity = max(1, Int(ceil(Double(buffer.frameLength) * ratio)))

        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: AVAudioFrameCount(estimatedFrameCapacity)
        ) else {
            return nil
        }

        var conversionError: NSError?
        var hasProvidedInput = false

        let status = audioConverter.convert(to: convertedBuffer, error: &conversionError) { _, outStatus in
            if hasProvidedInput {
                outStatus.pointee = .noDataNow
                return nil
            }

            hasProvidedInput = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard conversionError == nil, status != .error, convertedBuffer.frameLength > 0 else {
            if let conversionError {
                print("⚠️ 音频转换失败: \(conversionError.localizedDescription)")
            }
            return nil
        }

        return convertedBuffer
    }

    private func bufferToData(_ buffer: AVAudioPCMBuffer) -> Data? {
        guard let channelData = buffer.int16ChannelData else {
            return nil
        }

        let channelDataPointer = channelData.pointee
        let frameLength = Int(buffer.frameLength)

        // 将 Int16 数组转换为 Data
        let data = Data(bytes: channelDataPointer, count: frameLength * MemoryLayout<Int16>.size)
        return data
    }

    private func updateAudioLevel(with buffer: AVAudioPCMBuffer) {
        let level = normalizedLevel(from: buffer)
        let smoothed = smoothedLevel + levelSmoothing * (level - smoothedLevel)
        smoothedLevel = smoothed

        let now = CACurrentMediaTime()
        guard now - lastLevelUpdateTime >= levelUpdateInterval else { return }
        lastLevelUpdateTime = now

        delegate?.audioStreamController(self, didUpdateAudioLevel: smoothed)
    }

    private func normalizedLevel(from buffer: AVAudioPCMBuffer) -> CGFloat {
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        if let channelData = buffer.floatChannelData {
            let data = channelData.pointee
            var sum: Float = 0
            for i in 0..<frameLength {
                let value = data[i]
                sum += value * value
            }
            let rms = sqrt(sum / Float(frameLength))
            return normalizeDecibels(from: rms)
        }

        if let channelData = buffer.int16ChannelData {
            let data = channelData.pointee
            var sum: Float = 0
            for i in 0..<frameLength {
                let value = Float(data[i]) / Float(Int16.max)
                sum += value * value
            }
            let rms = sqrt(sum / Float(frameLength))
            return normalizeDecibels(from: rms)
        }

        return 0
    }

    private func normalizeDecibels(from rms: Float) -> CGFloat {
        let safeRms = max(rms, 0.000_000_1)
        let decibels = 20 * log10(safeRms)
        let clamped = max(decibels, minDecibels)
        let normalized = (clamped - minDecibels) / (-minDecibels)
        let boosted = pow(min(max(normalized, 0), 1), 0.5)
        return CGFloat(boosted)
    }
}

// MARK: - Delegate Protocol

protocol AudioStreamControllerDelegate: AnyObject {
    func audioStreamController(_ controller: AudioStreamController, didStartStream payload: AudioStartPayload)
    func audioStreamController(_ controller: AudioStreamController, didCaptureAudio payload: AudioDataPayload)
    func audioStreamController(_ controller: AudioStreamController, didEndStream payload: AudioEndPayload)
    func audioStreamController(_ controller: AudioStreamController, didUpdateAudioLevel level: CGFloat)
}

// MARK: - Errors

enum AudioStreamError: Error {
    case permissionDenied
    case audioFormatError
    case audioEngineError

    var localizedDescription: String {
        switch self {
        case .permissionDenied:
            return "麦克风权限被拒绝"
        case .audioFormatError:
            return "音频格式配置错误"
        case .audioEngineError:
            return "音频引擎错误"
        }
    }
}
