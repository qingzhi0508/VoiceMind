import Foundation
import Darwin

/// Qwen3-ASR 本地语音识别引擎
/// 使用 sherpa-onnx 离线识别器 API
/// 离线模式：录音期间缓冲音频，停止时一次性解码
class Qwen3AsrEngine: NSObject, SpeechRecognitionEngine {

    // MARK: - SpeechRecognitionEngine Protocol

    let identifier = "qwen3-asr"

    var displayName: String {
        if isModelConfigured {
            return "Qwen3-ASR"
        }
        return "Qwen3-ASR (未安装)"
    }

    var supportedLanguages: [String] { ["zh-CN", "en-US", "ja-JP", "ko-KR"] }
    var supportsStreaming: Bool { false }

    var isAvailable: Bool {
        return isModelConfigured
    }

    weak var delegate: SpeechRecognitionEngineDelegate?

    // MARK: - Private Properties

    private var recognizerRaw: UnsafeMutableRawPointer?
    private var isModelConfigured: Bool = false
    private var currentSessionId: String?
    private var currentLanguage: String?
    private var audioBuffer = Data()
    private var configuredModelSize: String?

    // MARK: - SpeechRecognitionEngine Methods

    func initialize() async throws {
        checkModelConfiguration()
        if isModelConfigured {
            print("✅ Qwen3-ASR 引擎初始化完成, model=\(configuredModelSize ?? "unknown")")
        } else {
            print("⚠️ Qwen3-ASR 模型未下载")
        }
    }

    func startRecognition(sessionId: String, language: String) throws {
        print("🎤 Qwen3-ASR 开始识别 (缓冲模式), session=\(sessionId), lang=\(language)")

        guard isAvailable else {
            throw SpeechError.engineNotAvailable
        }

        // 停止之前的识别
        try? stopRecognition()

        currentSessionId = sessionId
        currentLanguage = language
        audioBuffer = Data()

        // 确保识别器已创建
        if recognizerRaw == nil {
            try createRecognizer()
        }
    }

    func processAudioData(_ data: Data) throws {
        guard currentSessionId != nil else { return }
        // 离线模式：仅缓冲音频数据
        audioBuffer.append(data)
    }

    func stopRecognition() throws {
        guard let sessionId = currentSessionId else { return }

        print("🛑 Qwen3-ASR 停止识别, 缓冲音频 \(audioBuffer.count) 字节")

        defer {
            currentSessionId = nil
            currentLanguage = nil
            audioBuffer = Data()
        }

        guard let recognizer = recognizerRaw else {
            print("⚠️ Qwen3-ASR 识别器未初始化")
            return
        }

        guard !audioBuffer.isEmpty else {
            print("⚠️ Qwen3-ASR 音频缓冲为空")
            return
        }

        // 转换 PCM16 → Float32
        let samples = SherpaOnnxPCM16Converter.floatSamples(from: audioBuffer)
        guard !samples.isEmpty else { return }

        let language = currentLanguage ?? "zh-CN"

        // 创建离线流
        guard let streamRaw = SherpaOnnxSafeBridge.createOfflineStream(recognizer) else {
            print("❌ Qwen3-ASR 创建离线流失败")
            return
        }

        // 输入音频
        samples.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            SherpaOnnxSafeBridge.acceptWaveformOffline(streamRaw, sampleRate: 16000, samples: baseAddress, count: Int32(buffer.count))
        }

        // 解码（可能需要几秒）
        print("⏳ Qwen3-ASR 解码中...")
        SherpaOnnxSafeBridge.decodeOfflineStream(recognizer, stream: streamRaw)

        // 获取结果
        if let text = SherpaOnnxSafeBridge.getOfflineStreamResultText(streamRaw) {
            let trimmed = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if !trimmed.isEmpty {
                print("🎯 Qwen3-ASR 结果: \(trimmed)")
                delegate?.engine(self, didRecognizeText: trimmed, sessionId: sessionId, language: language)
            } else {
                print("⚠️ Qwen3-ASR 识别结果为空")
            }
        } else {
            print("⚠️ Qwen3-ASR 未获得识别结果")
        }

        // 销毁流
        SherpaOnnxSafeBridge.destroyOfflineStream(streamRaw)
    }

    // MARK: - Model Management

    /// 重新检查模型配置（下载/删除后调用）
    func reloadModelConfiguration() {
        // 清理旧的识别器
        if let recognizer = recognizerRaw {
            SherpaOnnxSafeBridge.destroyOfflineRecognizer(recognizer)
            recognizerRaw = nil
        }
        isModelConfigured = false
        configuredModelSize = nil
        checkModelConfiguration()
    }

    // MARK: - Private

    private func checkModelConfiguration() {
        for model in Qwen3AsrModelDefinition.catalog {
            let modelDir = getModelDirectory(for: model.size)
            if isModelDownloaded(in: modelDir, model: model) {
                isModelConfigured = true
                configuredModelSize = model.size
                print("✅ Qwen3-ASR 模型已配置: \(model.displayName) at \(modelDir.path)")
                return
            }
        }

        print("⚠️ Qwen3-ASR 未找到可用模型")
    }

    private func isModelDownloaded(in dir: URL, model: Qwen3AsrModelDefinition) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: dir.path) else { return false }

        for file in model.requiredFiles {
            let filePath = dir.appendingPathComponent(file)
            guard fm.fileExists(atPath: filePath.path) else {
                return false
            }
        }

        // 检查 tokenizer 目录
        let tokenizerPath = dir.appendingPathComponent(model.tokenizerDir)
        guard fm.fileExists(atPath: tokenizerPath.path) else {
            // 也检查 tokenizer.json 文件
            let tokenizerFile = dir.appendingPathComponent("tokenizer.json")
            return fm.fileExists(atPath: tokenizerFile.path)
        }

        return true
    }

    private func createRecognizer() throws {
        guard let modelSize = configuredModelSize,
              let model = Qwen3AsrModelDefinition.catalog.first(where: { $0.size == modelSize }) else {
            throw SpeechError.recognitionFailed("Qwen3-ASR 模型未配置")
        }

        let modelDir = getModelDirectory(for: modelSize)
        let convFrontend = modelDir.appendingPathComponent("conv_frontend.onnx").path
        let encoder = modelDir.appendingPathComponent("encoder.int8.onnx").path
        let decoder = modelDir.appendingPathComponent("decoder.int8.onnx").path

        // tokenizer 可能是目录或文件
        let tokenizerDir = modelDir.appendingPathComponent("tokenizer").path
        let tokenizerFile = modelDir.appendingPathComponent("tokenizer.json").path
        let tokenizer: String
        if FileManager.default.fileExists(atPath: tokenizerDir) {
            tokenizer = tokenizerDir
        } else {
            tokenizer = tokenizerFile
        }

        let numThreads = max(1, Int32(ProcessInfo.processInfo.processorCount / 2))

        var errorMsg: NSString?
        let rawPtr = SherpaOnnxSafeBridge.createOfflineQwen3Recognizer(
            withConvFrontend: convFrontend,
            encoder: encoder,
            decoder: decoder,
            tokenizer: tokenizer,
            maxTotalLen: 512,
            maxNewTokens: 128,
            temperature: 1e-6,
            topP: 0.8,
            seed: 42,
            numThreads: numThreads,
            error: &errorMsg
        )

        if let msg = errorMsg {
            print("❌ Qwen3-ASR 创建识别器失败: \(msg)")
        }

        guard let rawPtr else {
            throw SpeechError.recognitionFailed("无法创建 Qwen3-ASR 识别器: \(errorMsg ?? "unknown")")
        }

        recognizerRaw = rawPtr
        print("✅ Qwen3-ASR 识别器创建成功")
    }

    func getModelDirectory(for size: String) -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("VoiceMind/Models/Qwen3Asr/qwen3-asr-\(size)")
    }

    deinit {
        if let recognizer = recognizerRaw {
            SherpaOnnxSafeBridge.destroyOfflineRecognizer(recognizer)
        }
    }
}
