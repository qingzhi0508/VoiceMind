import Foundation
import Speech
import AVFoundation

/// Mac 端本地麦克风语音识别器
class LocalSpeechRecognizer: NSObject {

    // MARK: - Properties

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private var selectedLanguage: String = "zh-CN"

    weak var delegate: LocalSpeechRecognizerDelegate?

    var isRecording: Bool {
        audioEngine.isRunning
    }

    // MARK: - Initialization

    override init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        super.init()
    }

    // MARK: - Public Methods

    /// 请求权限
    func requestPermission(completion: @escaping (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    /// 检查权限状态
    func checkPermission() -> Bool {
        return AVAudioApplication.shared.recordPermission == .granted
    }

    /// 开始本地录音识别
    func startRecording(languageCode: String? = nil) throws {
        print("🎤 开始本地录音识别")

        // 停止之前的识别
        stopRecording()

        let language = languageCode ?? selectedLanguage
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language))

        guard let recognizer = recognizer, recognizer.isAvailable else {
            throw SpeechRecognitionError.recognizerNotAvailable
        }

        // 创建识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.cannotCreateRequest
        }

        recognitionRequest.shouldReportPartialResults = true

        // 优先使用设备上识别（离线）
        if recognizer.supportsOnDeviceRecognition {
            recognitionRequest.requiresOnDeviceRecognition = true
            print("✅ 使用设备上识别（离线模式）")
        }

        // 获取麦克风输入
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // 安装音频 tap
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        // 开始识别任务
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let text = result.bestTranscription.formattedString
                let isFinal = result.isFinal

                print("📝 本地识别结果: \(text) (final: \(isFinal))")

                if isFinal {
                    self.delegate?.localSpeechRecognizer(self, didRecognizeText: text, isFinal: true)
                } else {
                    self.delegate?.localSpeechRecognizer(self, didRecognizeText: text, isFinal: false)
                }
            }

            if let error = error {
                print("❌ 本地识别错误: \(error.localizedDescription)")
                self.delegate?.localSpeechRecognizer(self, didFailWithError: error)
            }
        }

        // 配置并启动音频引擎
        audioEngine.prepare()
        try audioEngine.start()

        print("✅ 本地录音识别已启动")
    }

    /// 停止本地录音识别
    func stopRecording() {
        print("🛑 停止本地录音识别")

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        print("✅ 本地录音识别已停止")
    }
}

// MARK: - Delegate Protocol

protocol LocalSpeechRecognizerDelegate: AnyObject {
    func localSpeechRecognizer(_ recognizer: LocalSpeechRecognizer, didRecognizeText text: String, isFinal: Bool)
    func localSpeechRecognizer(_ recognizer: LocalSpeechRecognizer, didFailWithError error: Error)
}
