import Foundation
import Speech
import AVFoundation

enum LocalSpeechRecognitionStartPolicy {
    static func shouldStartImmediately(
        microphoneGranted: Bool,
        speechRecognitionGranted: Bool
    ) -> Bool {
        microphoneGranted && speechRecognitionGranted
    }

    static func shouldRequireOnDeviceRecognition(
        supportsOnDeviceRecognition: Bool
    ) -> Bool {
        false
    }
}

enum LocalSpeechRecognitionStopPolicy {
    static let cancellationDelay: TimeInterval = 1.0

    static func shouldStopExistingSessionBeforeStarting(
        isAudioEngineRunning: Bool,
        hasRecognitionTask: Bool,
        hasRecognitionRequest: Bool
    ) -> Bool {
        isAudioEngineRunning || hasRecognitionTask || hasRecognitionRequest
    }

    static func shouldSuppressErrorAfterStop(_ error: Error) -> Bool {
        let nsError = error as NSError
        let description = nsError.localizedDescription.lowercased()
        return nsError.code == 1110 || description.contains("no speech detected")
    }

    static func shouldCancelDelayedTask(
        scheduledSessionGeneration: Int,
        currentSessionGeneration: Int,
        isAudioEngineRunning: Bool
    ) -> Bool {
        scheduledSessionGeneration == currentSessionGeneration && !isAudioEngineRunning
    }
}

/// Mac 端本地麦克风语音识别器
class LocalSpeechRecognizer: NSObject {

    // MARK: - Properties

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var isStopping = false
    private var sessionGeneration = 0

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

    /// 请求麦克风和语音识别权限
    func requestPermissions(completion: @escaping (Bool, Bool) -> Void) {
        // 请求麦克风权限
        AVAudioApplication.requestRecordPermission { micGranted in
            guard micGranted else {
                DispatchQueue.main.async {
                    completion(false, false)
                }
                return
            }

            // 请求语音识别权限
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    completion(micGranted, status == .authorized)
                }
            }
        }
    }

    /// 检查麦克风权限状态
    func checkMicrophonePermission() -> Bool {
        return AVAudioApplication.shared.recordPermission == .granted
    }

    /// 检查语音识别权限状态
    func checkSpeechRecognitionPermission() -> Bool {
        return SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    /// 开始本地录音识别
    func startRecording(languageCode: String? = nil) throws {
        print("🎤 开始本地录音识别")

        isStopping = false

        // 检查麦克风权限
        guard checkMicrophonePermission() else {
            print("❌ 麦克风权限未授予")
            throw SpeechRecognitionError.permissionDenied
        }

        // 检查语音识别权限
        guard checkSpeechRecognitionPermission() else {
            print("❌ 语音识别权限未授予")
            throw SpeechRecognitionError.permissionDenied
        }

        // 只有旧会话真的存在时，才做一次优雅停止。
        if LocalSpeechRecognitionStopPolicy.shouldStopExistingSessionBeforeStarting(
            isAudioEngineRunning: audioEngine.isRunning,
            hasRecognitionTask: recognitionTask != nil,
            hasRecognitionRequest: recognitionRequest != nil
        ) {
            stopRecording()
        }

        let language = languageCode ?? selectedLanguage
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language))

        guard let recognizer = recognizer, recognizer.isAvailable else {
            throw SpeechRecognitionError.recognizerNotAvailable
        }

        // 创建识别请求
        sessionGeneration += 1
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.cannotCreateRequest
        }

        recognitionRequest.shouldReportPartialResults = true

        // 优先使用设备上识别（离线）
        if recognizer.supportsOnDeviceRecognition && LocalSpeechRecognitionStartPolicy.shouldRequireOnDeviceRecognition(
            supportsOnDeviceRecognition: recognizer.supportsOnDeviceRecognition
        ) {
            recognitionRequest.requiresOnDeviceRecognition = true
            print("✅ 使用设备上识别（离线模式）")
        } else if recognizer.supportsOnDeviceRecognition {
            print("✅ 支持设备上识别，允许系统按最佳路径自动选择")
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
                if self.isStopping && LocalSpeechRecognitionStopPolicy.shouldSuppressErrorAfterStop(error) {
                    print("ℹ️ 忽略停止录音后的识别收尾错误: \(error.localizedDescription)")
                    return
                }

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

        isStopping = true
        let scheduledSessionGeneration = sessionGeneration
        let taskToCancel = recognitionTask
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + LocalSpeechRecognitionStopPolicy.cancellationDelay) { [weak self] in
            guard let self = self else { return }

            defer {
                self.isStopping = false
            }

            guard LocalSpeechRecognitionStopPolicy.shouldCancelDelayedTask(
                scheduledSessionGeneration: scheduledSessionGeneration,
                currentSessionGeneration: self.sessionGeneration,
                isAudioEngineRunning: self.audioEngine.isRunning
            ) else {
                return
            }

            taskToCancel?.cancel()

            if self.recognitionTask === taskToCancel {
                self.recognitionTask = nil
            }
        }

        print("✅ 本地录音识别已停止")
    }
}

// MARK: - Delegate Protocol

protocol LocalSpeechRecognizerDelegate: AnyObject {
    func localSpeechRecognizer(_ recognizer: LocalSpeechRecognizer, didRecognizeText text: String, isFinal: Bool)
    func localSpeechRecognizer(_ recognizer: LocalSpeechRecognizer, didFailWithError error: Error)
}
