import Foundation
import Speech
import AVFoundation
import UIKit

protocol SpeechControllerDelegate: AnyObject {
    func speechController(_ controller: SpeechController, didChangeState state: RecognitionState)
    func speechController(_ controller: SpeechController, didRecognizeText text: String, language: String)
    func speechController(_ controller: SpeechController, didFailWithError error: Error)
}

class SpeechController: NSObject {
    weak var delegate: SpeechControllerDelegate?

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?

    private var currentSessionId: String?
    private var finalResultTimer: Timer?
    private var lastRecognizedText: String = ""

    private(set) var state: RecognitionState = .idle {
        didSet {
            delegate?.speechController(self, didChangeState: state)
        }
    }

    var selectedLanguage: String = "zh-CN" {
        didSet {
            recognizer = SFSpeechRecognizer(locale: Locale(identifier: selectedLanguage))
        }
    }

    override init() {
        super.init()
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: selectedLanguage))
    }

    func requestPermissions(completion: @escaping (Bool) -> Void) {
        // Request microphone permission
        AVAudioApplication.requestRecordPermission { micGranted in
            guard micGranted else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            // Request speech recognition permission
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    completion(status == .authorized)
                }
            }
        }
    }

    func checkPermissions() -> Bool {
        let micGranted = AVAudioApplication.shared.recordPermission == .granted
        let speechGranted = SFSpeechRecognizer.authorizationStatus() == .authorized
        return micGranted && speechGranted
    }

    func startListening(sessionId: String) {
        guard checkPermissions() else {
            delegate?.speechController(self, didFailWithError: NSError(domain: "SpeechController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Permissions not granted"]))
            return
        }

        currentSessionId = sessionId

        do {
            try startRecognition()
            // 触发震动（在主线程执行）
            DispatchQueue.main.async {
                UIDevice.current.playHapticFeedback(.medium)
            }
            state = .listening
        } catch {
            delegate?.speechController(self, didFailWithError: error)
        }
    }

    @discardableResult
    func startManualListening() throws -> String {
        guard checkPermissions() else {
            throw NSError(domain: "SpeechController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Permissions not granted"])
        }

        let sessionId = UUID().uuidString
        currentSessionId = sessionId

        do {
            try startRecognition()
            // 触发震动（在主线程执行）
            DispatchQueue.main.async {
                UIDevice.current.playHapticFeedback(.medium)
            }
            state = .listening
            return sessionId
        } catch {
            currentSessionId = nil
            throw error
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()

        state = .processing

        // 缩短等待时间（从2秒减少到0.5秒），因为有部分结果实时反馈
        finalResultTimer?.invalidate()
        finalResultTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.finishRecognition()
        }
    }

    private func startRecognition() throws {
        // Cancel previous task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "SpeechController", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
        }

        recognitionRequest.shouldReportPartialResults = true

        // Create recognition task
        recognitionTask = recognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                // Store latest result
                self.lastRecognizedText = result.bestTranscription.formattedString
                if result.isFinal {
                    self.handleFinalResult(result.bestTranscription.formattedString)
                }
            }

            if let error = error {
                if self.state == .processing || self.state == .sending,
                   !self.lastRecognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.finishRecognition(with: self.lastRecognizedText)
                    return
                }

                self.delegate?.speechController(self, didFailWithError: error)
                self.resetAfterFailure()
            }
        }

        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func handleFinalResult(_ text: String) {
        finalResultTimer?.invalidate()
        finishRecognition(with: text)
    }

    private func finishRecognition(with text: String? = nil) {
        state = .sending

        let finalText = text ?? lastRecognizedText

        if !finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            delegate?.speechController(self, didRecognizeText: finalText, language: selectedLanguage)
        }

        cleanup()
        currentSessionId = nil
        lastRecognizedText = ""
        state = .idle
    }

    private func cleanup() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest = nil
        recognitionTask = nil
        finalResultTimer?.invalidate()
        finalResultTimer = nil
    }

    private func resetAfterFailure() {
        cleanup()
        currentSessionId = nil
        lastRecognizedText = ""
        state = .idle
    }
}

extension UIDevice {
    enum HapticFeedbackStyle {
        case light
        case medium
        case heavy
        case success
        case warning
        case error
    }
    
    func playHapticFeedback(_ style: HapticFeedbackStyle) {
        let generator: UIFeedbackGenerator
        
        switch style {
        case .light:
            generator = UIImpactFeedbackGenerator(style: .light)
        case .medium:
            generator = UIImpactFeedbackGenerator(style: .medium)
        case .heavy:
            generator = UIImpactFeedbackGenerator(style: .heavy)
        case .success:
            generator = UINotificationFeedbackGenerator()
            (generator as? UINotificationFeedbackGenerator)?.notificationOccurred(.success)
            return
        case .warning:
            generator = UINotificationFeedbackGenerator()
            (generator as? UINotificationFeedbackGenerator)?.notificationOccurred(.warning)
            return
        case .error:
            generator = UINotificationFeedbackGenerator()
            (generator as? UINotificationFeedbackGenerator)?.notificationOccurred(.error)
            return
        }
        
        generator.prepare()
        (generator as? UIImpactFeedbackGenerator)?.impactOccurred()
    }
}
