import Foundation
import Speech
import AVFoundation

/// Mac 端语音识别器 - 使用系统 Speech 框架
class MacSpeechRecognizer: NSObject {

    // MARK: - Properties

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private var sessionId: String?
    private var selectedLanguage: String = "zh-CN"

    // 音频格式参数（从 audioStart 消息中获取）
    private var audioFormat: AVAudioFormat?
    private var sampleRate: Double = 16000
    private var channels: AVAudioChannelCount = 1

    weak var delegate: MacSpeechRecognizerDelegate?

    // MARK: - Initialization

    override init() {
        // 初始化语音识别器（中文）
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        super.init()

        // 检查可用性
        checkAvailability()
    }

    // MARK: - Public Methods

    /// 检查语音识别是否可用
    func checkAvailability() {
        guard let recognizer = speechRecognizer else {
            print("❌ 语音识别器初始化失败")
            return
        }

        print("✅ 语音识别器可用")
        print("   语言: \(recognizer.locale.identifier)")
        print("   支持设备上识别: \(recognizer.supportsOnDeviceRecognition)")

        // 请求权限
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("✅ 语音识别权限已授予")
                case .denied:
                    print("❌ 语音识别权限被拒绝")
                case .restricted:
                    print("❌ 语音识别权限受限")
                case .notDetermined:
                    print("⚠️ 语音识别权限未确定")
                @unknown default:
                    print("❌ 未知的权限状态")
                }
            }
        }
    }

    /// 更改识别语言
    func setLanguage(_ languageCode: String) {
        selectedLanguage = languageCode
        print("🌐 切换语音识别语言: \(languageCode)")
    }

    /// 开始识别（从远程音频流）
    func startRecognition(sessionId: String, languageCode: String? = nil, sampleRate: Int = 16000, channels: Int = 1) throws {
        print("🎤 开始语音识别（远程音频流）")
        print("   Session ID: \(sessionId)")
        print("   采样率: \(sampleRate) Hz")
        print("   通道数: \(channels)")

        // 停止之前的识别任务
        stopRecognition()

        self.sessionId = sessionId
        self.sampleRate = Double(sampleRate)
        self.channels = AVAudioChannelCount(channels)

        // 创建音频格式
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: self.sampleRate,
            channels: self.channels,
            interleaved: false
        ) else {
            throw SpeechRecognitionError.audioEngineError
        }

        self.audioFormat = format
        print("✅ 音频格式已配置")

        // 使用指定语言或默认语言
        let language = languageCode ?? selectedLanguage
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language))

        guard let recognizer = recognizer else {
            throw SpeechRecognitionError.recognizerNotAvailable
        }

        guard recognizer.isAvailable else {
            throw SpeechRecognitionError.recognizerNotAvailable
        }

        // 创建识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.cannotCreateRequest
        }

        // 配置识别请求
        recognitionRequest.shouldReportPartialResults = true

        // 优先使用设备上识别（离线）
        if recognizer.supportsOnDeviceRecognition {
            recognitionRequest.requiresOnDeviceRecognition = true
            print("✅ 使用设备上识别（离线模式）")
        } else {
            print("⚠️ 设备上识别不可用，将使用在线识别")
        }

        // 开始识别任务
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let text = result.bestTranscription.formattedString
                let isFinal = result.isFinal

                print("📝 识别结果: \(text) (final: \(isFinal))")

                if isFinal {
                    self.delegate?.speechRecognizer(self, didRecognizeText: text, sessionId: sessionId, language: language)
                }
            }

            if let error = error {
                print("❌ 识别错误: \(error.localizedDescription)")
                self.delegate?.speechRecognizer(self, didFailWithError: error, sessionId: sessionId)
            }
        }

        print("✅ 识别任务已启动，等待音频数据")
    }

    /// 处理来自 iOS 的音频数据
    func processAudioData(_ audioData: Data) {
        guard let recognitionRequest = recognitionRequest else {
            print("⚠️ 识别请求未初始化，忽略音频数据")
            return
        }

        guard let audioFormat = audioFormat else {
            print("⚠️ 音频格式未配置")
            return
        }

        // 将 Data 转换为 AVAudioPCMBuffer
        guard let buffer = dataToAudioBuffer(audioData, format: audioFormat) else {
            print("⚠️ 无法转换音频数据")
            return
        }

        // 追加到识别请求
        recognitionRequest.append(buffer)
    }

    /// 停止识别
    func stopRecognition() {
        guard sessionId != nil else {
            return
        }

        print("🛑 停止语音识别")

        // 结束识别请求
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        // 取消识别任务（不要立即取消，等待最终结果）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.recognitionTask?.cancel()
            self?.recognitionTask = nil
        }

        sessionId = nil
        audioFormat = nil
    }

    // MARK: - Private Methods

    /// 将 Data 转换为 AVAudioPCMBuffer
    private func dataToAudioBuffer(_ data: Data, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let bytesPerSample = MemoryLayout<Int16>.size
        let channelCount = Int(format.channelCount)
        let frameCount = UInt32(data.count / (bytesPerSample * max(channelCount, 1)))

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }

        buffer.frameLength = frameCount

        guard let floatChannelData = buffer.floatChannelData else {
            return nil
        }

        // Shared protocol sends 16-bit PCM. Convert it to normalized Float32 samples
        // before appending so the Speech framework receives a standard processing format.
        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            guard let samples = bytes.bindMemory(to: Int16.self).baseAddress else {
                return
            }

            let totalFrames = Int(frameCount)
            for frame in 0..<totalFrames {
                for channel in 0..<channelCount {
                    let sampleIndex = frame * channelCount + channel
                    floatChannelData[channel][frame] = Float(samples[sampleIndex]) / Float(Int16.max)
                }
            }
        }

        return buffer
    }
}

// MARK: - Delegate Protocol

protocol MacSpeechRecognizerDelegate: AnyObject {
    func speechRecognizer(_ recognizer: MacSpeechRecognizer, didRecognizeText text: String, sessionId: String, language: String)
    func speechRecognizer(_ recognizer: MacSpeechRecognizer, didFailWithError error: Error, sessionId: String)
}

// MARK: - Errors

enum SpeechRecognitionError: Error {
    case recognizerNotAvailable
    case cannotCreateRequest
    case audioEngineError
    case permissionDenied

    var localizedDescription: String {
        switch self {
        case .recognizerNotAvailable:
            return "语音识别器不可用"
        case .cannotCreateRequest:
            return "无法创建识别请求"
        case .audioEngineError:
            return "音频引擎错误"
        case .permissionDenied:
            return "语音识别权限被拒绝"
        }
    }
}
