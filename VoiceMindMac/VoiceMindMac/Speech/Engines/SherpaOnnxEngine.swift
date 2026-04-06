import Foundation
import AVFoundation
import Combine

/// Sherpa-ONNX 语音识别引擎
/// 基于 https://github.com/k2-fsa/sherpa-onnx 的本地语音识别引擎
/// 需要先构建并集成 sherpa-onnx XCFramework 才能使用
class SherpaOnnxEngine: NSObject, SpeechRecognitionEngine {

    // MARK: - SpeechRecognitionEngine Protocol

    let identifier = "sherpa-onnx"

    var displayName: String {
        if isLibraryLoaded {
            return "Sherpa-ONNX"
        }
        return "Sherpa-ONNX (未安装)"
    }

    var supportsStreaming: Bool { true }

    var supportedLanguages: [String] {
        // Sherpa-ONNX 支持多语言，具体取决于下载的模型
        // 这里列出常用语言，实际支持情况取决于模型文件
        return [
            "zh-CN",  // 中文
            "en-US",  // 英文
            "yue-CN", // 粤语
            "ja-JP",  // 日语
            "ko-KR",  // 韩语
            "fr-FR",  // 法语
            "de-DE",  // 德语
            "es-ES",  // 西班牙语
        ]
    }

    /// 引擎是否可用（需要已加载 sherpa-onnx 库且模型已配置）
    var isAvailable: Bool {
        return isLibraryLoaded && isModelConfigured
    }

    weak var delegate: SpeechRecognitionEngineDelegate?

    // MARK: - Private Properties

    /// 库是否已加载
    private var isLibraryLoaded: Bool = false

    /// 模型是否已配置
    private var isModelConfigured: Bool = false

    /// 当前会话 ID
    private var currentSessionId: String?

    /// 当前语言
    private var currentLanguage: String?

    /// Sherpa-ONNX C 库句柄（用于存储创建的识别器）
    private var recognizerHandle: OpaquePointer?

    /// 音频样本率
    private let sampleRate: Int32 = 16000

    /// 模型路径
    private var modelPath: String?

    /// 模型配置
    private struct ModelConfig {
        let encoder: String  // encoder.onnx 路径
        let decoder: String  // decoder.onnx 路径
        let tokens: String   // tokens.txt 路径
        let language: String
    }

    private var currentModelConfig: ModelConfig?

    // MARK: - 初始化

    override init() {
        super.init()
        checkLibraryAvailability()
    }

    // MARK: - Library Loading

    /// 检查 sherpa-onnx 库是否可用
    private func checkLibraryAvailability() {
        // 检查是否可以通过 dlopen 加载 sherpa-onnx 库
        // 或者检查库文件是否存在
        let libraryPaths = [
            Bundle.main.path(forResource: "libsherpa-onnx", ofType: "dylib"),
            Bundle.main.path(forResource: "libsherpa-onnx", ofType: "a"),
            "/usr/local/lib/libsherpa-onnx.dylib",
            "/opt/homebrew/lib/libsherpa-onnx.dylib"
        ]

        for path in libraryPaths {
            if let path = path, FileManager.default.fileExists(atPath: path) {
                isLibraryLoaded = true
                print("✅ Sherpa-ONNX 库已找到: \(path)")
                break
            }
        }

        if !isLibraryLoaded {
            print("⚠️ Sherpa-ONNX 库未找到，请先构建并集成 sherpa-onnx XCFramework")
        }

        // 检查模型配置
        checkModelConfiguration()
    }

    /// 检查模型配置
    private func checkModelConfiguration() {
        // 尝试从配置目录加载模型信息
        let configDir = getModelConfigDirectory()
        let configFile = configDir.appendingPathComponent("model.config")

        if FileManager.default.fileExists(atPath: configFile.path) {
            // 从配置文件读取模型路径
            do {
                let configData = try Data(contentsOf: configFile)
                if let config = try? JSONDecoder().decode(ModelConfigJSON.self, from: configData) {
                    currentModelConfig = ModelConfig(
                        encoder: config.encoderPath,
                        decoder: config.decoderPath,
                        tokens: config.tokensPath,
                        language: config.language
                    )
                    isModelConfigured = true
                    print("✅ Sherpa-ONNX 模型已配置: \(config.language)")
                }
            } catch {
                print("⚠️ 读取模型配置失败: \(error)")
            }
        } else {
            print("⚠️ 未找到模型配置文件")
        }
    }

    private func getModelConfigDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("VoiceMind/Models/SherpaOnnx")
    }

    // MARK: - SpeechRecognitionEngine Methods

    func initialize() async throws {
        guard isLibraryLoaded else {
            throw SpeechError.engineNotAvailable
        }

        print("🎤 Sherpa-ONNX 引擎初始化中...")

        // 如果模型未配置，尝试设置默认模型
        if !isModelConfigured {
            try await setupDefaultModel()
        }

        guard isModelConfigured else {
            throw SpeechError.recognitionFailed("Sherpa-ONNX 模型未配置")
        }

        print("✅ Sherpa-ONNX 引擎初始化成功")
    }

    /// 设置默认模型
    private func setupDefaultModel() async throws {
        // 默认使用流式 Whisper 模型
        // 模型需要预先下载到 Models 目录
        let modelDir = getModelConfigDirectory()

        // 创建目录
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)

        // 检查 Models 目录下是否有 sherpa-onnx 模型
        let models = findAvailableModels(in: modelDir)

        if let bestModel = models.first {
            currentModelConfig = bestModel
            isModelConfigured = true
            saveModelConfig(bestModel)
            print("✅ 已选择模型: \(bestModel.language)")
        } else {
            print("⚠️ 未在 \(modelDir.path) 找到 Sherpa-ONNX 模型")
            print("📥 请下载 Sherpa-ONNX 模型并放置在该目录下")
        }
    }

    /// 查找可用的 Sherpa-ONNX 模型
    private func findAvailableModels(in directory: URL) -> [ModelConfig] {
        var configs: [ModelConfig] = []

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return configs
        }

        for item in contents {
            let configFile = item.appendingPathComponent("model.config")
            if FileManager.default.fileExists(atPath: configFile.path) {
                if let configData = try? Data(contentsOf: configFile),
                   let config = try? JSONDecoder().decode(ModelConfigJSON.self, from: configData) {
                    configs.append(ModelConfig(
                        encoder: config.encoderPath,
                        decoder: config.decoderPath,
                        tokens: config.tokensPath,
                        language: config.language
                    ))
                }
            }
        }

        return configs
    }

    /// 保存模型配置
    private func saveModelConfig(_ config: ModelConfig) {
        let configDir = getModelConfigDirectory()
        let configFile = configDir.appendingPathComponent("model.config")

        let jsonConfig = ModelConfigJSON(
            encoderPath: config.encoder,
            decoderPath: config.decoder,
            tokensPath: config.tokens,
            language: config.language
        )

        if let data = try? JSONEncoder().encode(jsonConfig) {
            try? data.write(to: configFile)
        }
    }

    func startRecognition(sessionId: String, language: String) throws {
        print("🎤 Sherpa-ONNX 开始识别")
        print("   Session ID: \(sessionId)")
        print("   语言: \(language)")

        guard isAvailable else {
            throw SpeechError.engineNotAvailable
        }

        // 停止之前的识别
        try? stopRecognition()

        currentSessionId = sessionId
        currentLanguage = language

        // 确保使用正确的语言模型
        if let config = currentModelConfig, config.language != language {
            // 尝试查找匹配语言的模型
            if let matchingModel = findModel(for: language) {
                currentModelConfig = matchingModel
                saveModelConfig(matchingModel)
            }
        }

        guard let config = currentModelConfig else {
            throw SpeechError.recognitionFailed("未配置语言模型")
        }

        // 初始化 Sherpa-ONNX 识别器
        // 注意：这里需要调用 Sherpa-ONNX C API
        try initializeRecognizer(config: config)

        print("✅ Sherpa-ONNX 识别器已启动")
    }

    /// 初始化 Sherpa-ONNX 识别器
    private func initializeRecognizer(config: ModelConfig) throws {
        // TODO: 调用 Sherpa-ONNX C API 创建识别器
        //
        // Sherpa-ONNX C API 概览:
        //
        // // 创建特征提取配置
        // SherpaOnnxOnlineRecognizerConfig config;
        // config.feature_config.sample_rate = 16000;
        // config.feature_config.feature_dim = 80;
        // config.model_config.encoder = encoder_path;
        // config.model_config.decoder = decoder_path;
        // config.model_config.tokens = tokens_path;
        // config.model_config.num_threads = 4;
        // config.model_config.provider = "cpu"; // 或 "metal" for Apple Silicon
        //
        // // 创建识别器
        // recognizerHandle = SherpaOnnxCreateOnlineRecognizer(&config);
        //
        // // 创建流
        // SherpaOnnxOnlineStream *stream = SherpaOnnxCreateOnlineStream(recognizerHandle);
        //
        // // 开始识别
        // SherpaOnnxOnlineRecognizer Accept(recognizerHandle, stream);
        //
        // // 输入音频 (16kHz, 16-bit PCM)
        // SherpaOnnxOnlineRecognizer InputFeed(recognizerHandle, stream, samples, num_samples);
        //
        // // 获取结果
        // const char* text = SherpaOnnxOnlineRecognizer GetResult(recognizerHandle, stream);

        print("🔧 Sherpa-ONNX C API 调用待实现")
        print("   模型路径: \(config.encoder)")
    }

    func processAudioData(_ data: Data) throws {
        guard let handle = recognizerHandle else {
            throw SpeechError.engineNotInitialized
        }

        // TODO: 调用 Sherpa-ONNX C API 输入音频
        //
        // Sherpa-ONNX C API 音频输入:
        //
        // // 将 Data 转换为 float 样本
        // let samples = data.withUnsafeBytes { buffer -> [Float] in
        //     guard let baseAddress = buffer.bindMemory(to: Int16.self).baseAddress else {
        //         return []
        //     }
        //     return (0..<buffer.count/2).map { Float(baseAddress[$0]) / Float(Int16.max) }
        // }
        //
        // // 输入音频
        // SherpaOnnxOnlineRecognizer InputFeed(handle, stream, samples, Int32(samples.count));
        //
        // // 触发识别（每输入一定量音频后调用）
        // SherpaOnnxOnlineRecognizer Decode(handle, stream);
        //
        // // 获取部分结果
        // let result = SherpaOnnxOnlineRecognizer GetResult(handle, stream)
        // if let text = result.text {
        //     delegate?.engine(self, didReceivePartialResult: String(cString: text), sessionId: currentSessionId ?? "")
        // }

        // 示例：每 0.5 秒触发一次识别
        let bytesPerSample = MemoryLayout<Int16>.size
        let frameCount = data.count / bytesPerSample
        let durationSeconds = Double(frameCount) / Double(sampleRate)

        if durationSeconds >= 0.5 {
            // 触发解码
            decodeCurrentStream()
        }
    }

    /// 解码当前音频流
    private func decodeCurrentStream() {
        // TODO: 调用 Sherpa-ONNX 解码
        //
        // SherpaOnnxOnlineRecognizer Decode(recognizerHandle, stream);
        //
        // // 获取结果
        // let result = SherpaOnnxOnlineRecognizer GetResult(recognizerHandle, stream);
        // if result.is_final {
        //     delegate?.engine(self, didRecognizeText: String(cString: result.text), ...)
        // } else {
        //     delegate?.engine(self, didReceivePartialResult: String(cString: result.text), ...)
        // }
    }

    func stopRecognition() throws {
        guard currentSessionId != nil else {
            return
        }

        print("🛑 Sherpa-ONNX 停止识别")

        // TODO: 清理 Sherpa-ONNX 资源
        //
        // // 释放流
        // SherpaOnnxDestroyOnlineStream(recognizerHandle, stream);
        //
        // // 销毁识别器
        // SherpaOnnxDestroyOnlineRecognizer(recognizerHandle);
        // recognizerHandle = nil;

        recognizerHandle = nil
        currentSessionId = nil
        currentLanguage = nil

        print("🧹 Sherpa-ONNX 状态已清理")
    }

    // MARK: - Model Management

    /// 下载并配置模型
    /// - Parameter modelInfo: 模型信息（URL 或本地路径）
    func downloadAndSetupModel(from url: URL) async throws {
        let modelDir = getModelConfigDirectory().appendingPathComponent(url.lastPathComponent)

        print("📥 正在下载 Sherpa-ONNX 模型...")
        print("   源: \(url)")
        print("   目标: \(modelDir.path)")

        // 使用 URLSession 下载模型
        let (tempURL, _) = try await URLSession.shared.download(from: url)

        // 创建目录
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)

        // 解压（如果是 .tar.bz2 或 .zip）
        // 注意：这里需要使用 Process 或第三方库来解压
        // 简化处理：假设下载的是已解压的模型文件夹

        // 更新配置
        // TODO: 根据下载的模型更新配置

        print("✅ Sherpa-ONNX 模型下载完成")
        isModelConfigured = true
    }

    /// 获取支持 Whisper 的语言代码
    private func findModel(for language: String) -> ModelConfig? {
        let modelDir = getModelConfigDirectory()
        let models = findAvailableModels(in: modelDir)
        return models.first { $0.language == language }
    }

    // MARK: - Debug

    /// 打印引擎状态
    func logStatus() {
        print("📊 Sherpa-ONNX 引擎状态:")
        print("   库已加载: \(isLibraryLoaded)")
        print("   模型已配置: \(isModelConfigured)")
        if let config = currentModelConfig {
            print("   当前模型语言: \(config.language)")
            print("   Encoder: \(config.encoder)")
        }
    }
}

// MARK: - Helper Types

/// 模型配置的 JSON 表示
private struct ModelConfigJSON: Codable {
    let encoderPath: String
    let decoderPath: String
    let tokensPath: String
    let language: String
}

// MARK: - Sherpa-ONNX C API (待实现)
// 以下是需要导入的 C API 声明，在实际集成时需要创建 bridging header
//
// typedef struct SherpaOnnxOnlineRecognizerConfig {
//     SherpaOnnxFeatureConfig feature_config;
//     SherpaOnnxModelConfig model_config;
//     SherpaOnnxDecoderConfig decoder_config;
//     SherpaOnnxEndpointConfig endpoint_config;
// } SherpaOnnxOnlineRecognizerConfig;
//
// typedef struct SherpaOnnxOnlineRecognizer SherpaOnnxOnlineRecognizer;
//
// SherpaOnnxOnlineRecognizer *SherpaOnnxCreateOnlineRecognizer(
//     const SherpaOnnxOnlineRecognizerConfig *config);
//
// void SherpaOnnxDestroyOnlineRecognizer(
//     SherpaOnnxOnlineRecognizer *recognizer);
//
// SherpaOnnxOnlineStream *SherpaOnnxCreateOnlineStream(
//     SherpaOnnxOnlineRecognizer *recognizer);
//
// void SherpaOnnxDestroyOnlineStream(
//     SherpaOnnxOnlineRecognizer *recognizer,
//     SherpaOnnxOnlineStream *stream);
//
// int SherpaOnnxOnlineRecognizerAcceptWaveform(
//     SherpaOnnxOnlineRecognizer *recognizer,
//     SherpaOnnxOnlineStream *stream,
//     const float *samples,
//     int n);
//
// void SherpaOnnxOnlineRecognizerDecode(
//     SherpaOnnxOnlineRecognizer *recognizer,
//     SherpaOnnxOnlineStream *stream);
//
// const SherpaOnnxOnlineRecognizerResult *
// SherpaOnnxOnlineRecognizerGetResult(
//     SherpaOnnxOnlineRecognizer *recognizer,
//     SherpaOnnxOnlineStream *stream);
//
// void SherpaOnnxOnlineRecognizerResultFree(
//     const SherpaOnnxOnlineRecognizerResult *result);
