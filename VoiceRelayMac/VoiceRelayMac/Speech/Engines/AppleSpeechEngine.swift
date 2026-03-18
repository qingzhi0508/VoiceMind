import Foundation
import Speech
import AVFoundation

/// Apple Speech 引擎 - 适配器，将 Apple Speech 框架适配到 SpeechRecognitionEngine 协议
class AppleSpeechEngine: NSObject, SpeechRecognitionEngine {

    // MARK: - SpeechRecognitionEngine Protocol

    let identifier = "apple-speech"
    let displayName = "Apple Speech"
    let supportsStreaming = true

    var supportedLanguages: [String] {
        return SFSpeechRecognizer.supportedLocales().map { $0.identifier }
    }

    var isAvailable: Bool {
        guard let recognizer = currentRecognizer else { return false }
        return recognizer.isAvailable && SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    weak var delegate: SpeechRecognitionEngineDelegate?

    // MARK: - Private Properties

    private var currentRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioFormat: AVAudioFormat?

    private var currentSessionId: String?
    private var currentLanguage: String?

    // MARK: - Initialization

    override init() {
        super.init()
        // 默认使用中文识别器
        currentRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        checkAvailability()
    }

    // MARK: - SpeechRecognitionEngine Methods

    func initialize() async throws {
        // 请求权限
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard status == .authorized else {
            throw SpeechError.recognitionFailed("语音识别权限未授予")
        }

        print("✅ Apple Speech 引擎初始化成功")
    }

    func startRecognition(sessionId: String, language: String) throws {
        print("🎤 Apple Speech 开始识别")
        print("   Session ID: \(sessionId)")
        print("   语言: \(language)")

        // 停止之前的识别
        try? stopRecognition()

        // 创建对应语言的识别器
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language))
        guard let recognizer = recognizer else {
            throw SpeechError.recognitionFailed("不支持的语言: \(language)")
        }

        guard recognizer.isAvailable else {
            throw SpeechError.engineNotAvailable
        }

        currentRecognizer = recognizer
        currentSessionId = sessionId
        currentLanguage = language

        // 创建音频格式（16kHz, 单声道, Float32）
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw SpeechError.invalidAudioFormat
        }

        audioFormat = format

        // 创建识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.recognitionFailed("无法创建识别请求")
        }

        // 配置识别请求
        recognitionRequest.shouldReportPartialResults = true

        // 添加任务提示，优化识别速度
        if #available(macOS 13.0, *) {
            recognitionRequest.addsPunctuation = true  // 自动添加标点
        }

        // 优先使用设备上识别（离线）
        if recognizer.supportsOnDeviceRecognition {
            recognitionRequest.requiresOnDeviceRecognition = true
            print("✅ 使用设备上识别（离线模式）")
        } else {
            print("⚠️ 设备上识别不可用，将使用在线识别")
        }

        // 开始识别任务
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else {
                print("⚠️ Apple Speech 回调: self 已释放")
                return
            }
            guard let sessionId = self.currentSessionId else {
                print("⚠️ Apple Speech 回调: sessionId 为空")
                return
            }
            guard let language = self.currentLanguage else {
                print("⚠️ Apple Speech 回调: language 为空")
                return
            }

            print("🔔 Apple Speech 识别回调触发")

            if let result = result {
                let text = result.bestTranscription.formattedString
                let isFinal = result.isFinal

                if isFinal {
                    print("📝 Apple Speech 最终结果: \(text)")
                    self.delegate?.engine(self, didRecognizeText: text, sessionId: sessionId, language: language)
                } else {
                    print("📝 Apple Speech 部分结果: \(text)")
                    self.delegate?.engine(self, didReceivePartialResult: text, sessionId: sessionId)
                }
            } else {
                print("⚠️ Apple Speech 回调: result 为空")
            }

            if let error = error {
                print("❌ Apple Speech 识别错误: \(error.localizedDescription)")
                self.delegate?.engine(self, didFailWithError: error, sessionId: sessionId)
            }
        }

        print("✅ Apple Speech 识别任务已启动")
    }

    func processAudioData(_ data: Data) throws {
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.engineNotInitialized
        }

        guard let audioFormat = audioFormat else {
            throw SpeechError.invalidAudioFormat
        }

        // 将 Data 转换为 AVAudioPCMBuffer
        guard let buffer = dataToAudioBuffer(data, format: audioFormat) else {
            throw SpeechError.recognitionFailed("音频数据转换失败")
        }

        print("🎵 处理音频数据: \(data.count) 字节 -> \(buffer.frameLength) 帧")

        // 追加到识别请求
        recognitionRequest.append(buffer)
    }

    func stopRecognition() throws {
        guard currentSessionId != nil else {
            return
        }

        print("🛑 Apple Speech 停止识别")

        // 结束识别请求（会触发最终结果回调）
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        // 缩短延迟清理时间（从2秒减少到0.5秒），因为有部分结果实时反馈
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.recognitionTask?.cancel()
            self?.recognitionTask = nil
            self?.currentSessionId = nil
            self?.currentLanguage = nil
            self?.audioFormat = nil
            print("🧹 Apple Speech 状态已清理")
        }
    }

    // MARK: - Private Helper Methods

    /// 检查可用性（用于初始化时的诊断）
    private func checkAvailability() {
        guard let recognizer = currentRecognizer else {
            print("❌ 语音识别器初始化失败")
            return
        }

        print("✅ 语音识别器可用")
        print("   语言: \(recognizer.locale.identifier)")
        print("   支持设备上识别: \(recognizer.supportsOnDeviceRecognition)")
    }

    /// 将 Data 转换为 AVAudioPCMBuffer
    /// - Parameters:
    ///   - data: 音频数据（16-bit PCM）
    ///   - format: 目标音频格式（Float32）
    /// - Returns: AVAudioPCMBuffer 或 nil
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

        // 将 16-bit PCM 转换为归一化的 Float32 样本
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
