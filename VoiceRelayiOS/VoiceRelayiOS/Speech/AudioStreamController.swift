import Foundation
import Speech
import AVFoundation
import SharedCore

/// iOS 端音频流传输器
/// 负责捕获音频并发送到 Mac 端进行识别
class AudioStreamController: NSObject {

    // MARK: - Properties

    weak var delegate: AudioStreamControllerDelegate?

    private let audioEngine = AVAudioEngine()
    private var currentSessionId: String?
    private var sequenceNumber: Int = 0
    private var isStreaming: Bool = false

    var selectedLanguage: String = "zh-CN"

    // MARK: - Public Methods

    func checkPermissions() -> Bool {
        return AVAudioSession.sharedInstance().recordPermission == .granted
    }

    func requestPermissions(completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    /// 开始音频流传输
    func startStreaming(sessionId: String) throws {
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

        // 配置音频会话
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // 配置音频格式：16kHz, 单声道, PCM16
        let sampleRate: Double = 16000
        let channels: AVAudioChannelCount = 1

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
            format: "pcm16"
        ))

        // 安装音频 tap
        let inputNode = audioEngine.inputNode
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }

        // 启动音频引擎
        audioEngine.prepare()
        try audioEngine.start()

        print("✅ 音频引擎已启动")
    }

    /// 停止音频流传输
    func stopStreaming() {
        guard isStreaming else {
            return
        }

        print("🛑 停止音频流传输")

        isStreaming = false

        // 停止音频引擎
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

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

        // 将 AVAudioPCMBuffer 转换为 Data
        guard let audioData = bufferToData(buffer) else {
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

        // 每 100 个包打印一次日志
        if sequenceNumber % 100 == 0 {
            print("📤 已发送 \(sequenceNumber) 个音频包")
        }
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
}

// MARK: - Delegate Protocol

protocol AudioStreamControllerDelegate: AnyObject {
    func audioStreamController(_ controller: AudioStreamController, didStartStream payload: AudioStartPayload)
    func audioStreamController(_ controller: AudioStreamController, didCaptureAudio payload: AudioDataPayload)
    func audioStreamController(_ controller: AudioStreamController, didEndStream payload: AudioEndPayload)
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
