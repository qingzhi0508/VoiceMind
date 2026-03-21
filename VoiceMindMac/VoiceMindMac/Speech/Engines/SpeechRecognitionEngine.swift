import Foundation

/// 语音识别引擎协议
/// 所有语音识别引擎（Apple Speech、SenseVoice 等）都必须实现此协议
protocol SpeechRecognitionEngine: AnyObject {
    /// 引擎唯一标识符（如 "apple-speech", "sensevoice"）
    var identifier: String { get }

    /// 引擎显示名称（如 "Apple Speech", "SenseVoice"）
    var displayName: String { get }

    /// 支持的语言列表（如 ["zh-CN", "en-US"]）
    var supportedLanguages: [String] { get }

    /// 是否可用（模型已下载、权限已授予等）
    var isAvailable: Bool { get }

    /// 是否支持流式识别
    var supportsStreaming: Bool { get }

    /// 代理
    var delegate: SpeechRecognitionEngineDelegate? { get set }

    /// 初始化引擎（异步，可能需要加载模型）
    func initialize() async throws

    /// 开始识别
    /// - Parameters:
    ///   - sessionId: 会话 ID
    ///   - language: 识别语言
    func startRecognition(sessionId: String, language: String) throws

    /// 处理音频数据（流式）
    /// - Parameter data: 音频数据（16-bit PCM, 16kHz, 单声道）
    func processAudioData(_ data: Data) throws

    /// 停止识别
    func stopRecognition() throws
}

/// 语音识别引擎代理协议
protocol SpeechRecognitionEngineDelegate: AnyObject {
    /// 识别成功
    /// - Parameters:
    ///   - engine: 引擎实例
    ///   - text: 识别的文本
    ///   - sessionId: 会话 ID
    ///   - language: 识别语言
    func engine(
        _ engine: SpeechRecognitionEngine,
        didRecognizeText text: String,
        sessionId: String,
        language: String
    )

    /// 识别失败
    /// - Parameters:
    ///   - engine: 引擎实例
    ///   - error: 错误信息
    ///   - sessionId: 会话 ID
    func engine(
        _ engine: SpeechRecognitionEngine,
        didFailWithError error: Error,
        sessionId: String
    )

    /// 部分结果（可选，用于实时显示）
    /// - Parameters:
    ///   - engine: 引擎实例
    ///   - text: 部分识别文本
    ///   - sessionId: 会话 ID
    func engine(
        _ engine: SpeechRecognitionEngine,
        didReceivePartialResult text: String,
        sessionId: String
    )
}
