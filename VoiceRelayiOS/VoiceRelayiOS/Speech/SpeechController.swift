import Foundation
import Speech
import AVFoundation

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
        AVAudioSession.sharedInstance().requestRecordPermission { micGranted in
            guard micGranted else {
                completion(false)
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
        let micGranted = AVAudioSession.sharedInstance().recordPermission == .granted
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
            state = .listening
        } catch {
            delegate?.speechController(self, didFailWithError: error)
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()

        state = .processing

        // Wait up to 2 seconds for final result
        finalResultTimer?.invalidate()
        finalResultTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
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
                if result.isFinal {
                    self.handleFinalResult(result.bestTranscription.formattedString)
                }
            }

            if let error = error {
                self.delegate?.speechController(self, didFailWithError: error)
                self.cleanup()
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
        guard let sessionId = currentSessionId else { return }

        state = .sending

        let finalText = text ?? recognitionTask?.result?.bestTranscription.formattedString ?? ""

        delegate?.speechController(self, didRecognizeText: finalText, language: selectedLanguage)

        cleanup()
        currentSessionId = nil
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
}
