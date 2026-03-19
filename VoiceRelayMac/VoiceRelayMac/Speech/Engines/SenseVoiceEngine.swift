import Foundation

/// SenseVoice 语音识别引擎
/// 使用 sherpa-onnx Offline API 运行 SenseVoiceSmall 模型
class SenseVoiceEngine: NSObject, SpeechRecognitionEngine {

    // MARK: - SpeechRecognitionEngine Protocol

    let identifier = "sensevoice"
    let displayName = "SenseVoice"
    let supportsStreaming = true  // 虽然是离线模型，但支持音频累积

    var supportedLanguages: [String] {
        return ["zh-CN", "en-US", "ja-JP", "ko-KR", "yue-CN"]
    }

    var isAvailable: Bool {
        // 检查ModelManager是否初始化成功
        guard ModelManager.shared.isInitialized else {
            return false
        }
        return ModelManager.shared.isModelDownloaded(engineType: "sensevoice")
    }

    weak var delegate: SpeechRecognitionEngineDelegate?

    // MARK: - Private Properties

    private var recognizer: SherpaOnnxRecognizer?
    private var currentSessionId: String?
    private var currentLanguage: String?
    private var audioBuffer: [Float] = []

    // 音频处理参数
    private let sampleRate: Int = 16000

    // MARK: - Initialization

    override init() {
        super.init()
    }

    // MARK: - SpeechRecognitionEngine Methods

    func initialize() async throws {
        print("🎤 初始化 SenseVoice 引擎")

        guard let modelPath = ModelManager.shared.getModelPath(engineType: "sensevoice") else {
            print("❌ SenseVoice 模型未找到")
            throw SenseVoiceError.modelNotFound
        }

        let modelFile = modelPath.appendingPathComponent("model.onnx")
        let tokensFile = modelPath.appendingPathComponent("tokens.txt")

        // 验证文件存在
        guard FileManager.default.fileExists(atPath: modelFile.path),
              FileManager.default.fileExists(atPath: tokensFile.path) else {
            print("❌ 模型文件不完整")
            throw SenseVoiceError.invalidModelPath
        }

        print("📁 模型路径: \(modelFile.path)")
        print("📁 词表路径: \(tokensFile.path)")

        // 验证 tokens 文件内容，避免 sherpa-onnx 内部崩溃
        try validateTokensFile(tokensFile)

        // 默认使用中文
        let language = "zh"

        // 创建识别器
        recognizer = SherpaOnnxRecognizer(
            modelPath: modelFile.path,
            tokensPath: tokensFile.path,
            language: language,
            sampleRate: Int32(sampleRate)
        )

        guard recognizer != nil else {
            print("❌ 创建 sherpa-onnx 识别器失败")
            throw SenseVoiceError.modelLoadFailed
        }

        print("✅ SenseVoice 引擎初始化成功")
    }

    func startRecognition(sessionId: String, language: String) throws {
        print("🎤 SenseVoice 开始识别")
        print("   Session ID: \(sessionId)")
        print("   语言: \(language)")

        guard let recognizer = recognizer else {
            throw SenseVoiceError.notInitialized
        }

        currentSessionId = sessionId
        currentLanguage = language
        audioBuffer.removeAll()

        // 重置识别器状态
        recognizer.reset()

        print("✅ SenseVoice 识别已启动（累积模式）")
    }

    func processAudioData(_ data: Data) throws {
        guard recognizer != nil else {
            throw SenseVoiceError.notInitialized
        }

        guard currentSessionId != nil else {
            return
        }

        // 将 Int16 PCM 转换为 Float32 并累积
        let samples = convertToFloat32(data)
        audioBuffer.append(contentsOf: samples)

        print("📊 累积音频: \(audioBuffer.count) 样本 (\(Double(audioBuffer.count) / Double(sampleRate)) 秒)")
    }

    func stopRecognition() throws {
        guard let recognizer = recognizer,
              let sessionId = currentSessionId,
              let language = currentLanguage else {
            return
        }

        print("🛑 SenseVoice 停止识别")
        print("   累积音频总量: \(audioBuffer.count) 样本 (\(Double(audioBuffer.count) / Double(sampleRate)) 秒)")

        // 如果有累积的音频，进行识别
        if !audioBuffer.isEmpty {
            // 将累积的音频送入识别器
            recognizer.acceptWaveform(audioBuffer, count: Int32(audioBuffer.count))

            // 触发识别
            recognizer.decode()

            // 获取识别结果
            let text = recognizer.getText()
            let detectedLang = recognizer.getLanguage()
            let emotion = recognizer.getEmotion()
            let event = recognizer.getEvent()

            print("📝 SenseVoice 识别结果:")
            print("   文本: \(text)")
            print("   语言: \(detectedLang)")
            print("   情感: \(emotion)")
            print("   事件: \(event)")

            if !text.isEmpty {
                delegate?.engine(self, didRecognizeText: text, sessionId: sessionId, language: language)
            } else {
                print("⚠️ SenseVoice 未识别到文本")
            }

            audioBuffer.removeAll()
        } else {
            print("⚠️ 没有累积的音频数据")
        }

        currentSessionId = nil
        currentLanguage = nil
    }

    // MARK: - Private Helper Methods

    /// 将 Int16 PCM 转换为 Float32
    /// - Parameter data: 16-bit PCM 音频数据
    /// - Returns: Float32 音频样本数组（归一化到 -1.0 ~ 1.0）
    private func convertToFloat32(_ data: Data) -> [Float] {
        let int16Array = data.withUnsafeBytes {
            Array(UnsafeBufferPointer<Int16>(
                start: $0.baseAddress?.assumingMemoryBound(to: Int16.self),
                count: data.count / 2
            ))
        }

        return int16Array.map { Float($0) / Float(Int16.max) }
    }

    /// 基础校验 tokens 文件，避免加载不完整/错误文件导致崩溃
    private func validateTokensFile(_ url: URL) throws {
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else {
            print("❌ tokens 文件为空")
            throw SenseVoiceError.invalidTokensFile
        }

        guard let content = String(data: data, encoding: .utf8) else {
            print("❌ tokens 文件不是有效的 UTF-8 文本")
            throw SenseVoiceError.invalidTokensFile
        }

        let lowered = content.prefix(256).lowercased()
        if lowered.contains("<!doctype") || lowered.contains("<html") || lowered.contains("not found") || lowered.contains("accessdenied") {
            print("❌ tokens 文件疑似下载为 HTML/错误内容")
            throw SenseVoiceError.invalidTokensFile
        }

        let lines = content.split(whereSeparator: \.isNewline)
        guard !lines.isEmpty else {
            print("❌ tokens 文件没有有效内容")
            throw SenseVoiceError.invalidTokensFile
        }

        var ids = Set<Int>()
        var minId = Int.max
        var maxId = Int.min

        for lineSub in lines {
            let line = lineSub.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                continue
            }

            let parts = line.split { $0 == " " || $0 == "\t" }
            guard parts.count >= 2 else {
                print("❌ tokens 行格式错误: \(line)")
                throw SenseVoiceError.invalidTokensFile
            }

            let first = String(parts.first ?? "")
            let last = String(parts.last ?? "")

            let id: Int?
            if let lastId = Int(last) {
                id = lastId
            } else if let firstId = Int(first) {
                id = firstId
            } else {
                print("❌ tokens 行缺少编号: \(line)")
                throw SenseVoiceError.invalidTokensFile
            }

            guard let tokenId = id else {
                throw SenseVoiceError.invalidTokensFile
            }

            ids.insert(tokenId)
            minId = min(minId, tokenId)
            maxId = max(maxId, tokenId)
        }

        guard !ids.isEmpty, minId == 0, maxId == ids.count - 1 else {
            print("❌ tokens 编号不连续或起始不是 0: min=\(minId), max=\(maxId), count=\(ids.count)")
            throw SenseVoiceError.invalidTokensFile
        }
    }
}
