import Foundation

/// 语音识别管理器
/// 负责管理多个识别引擎，处理引擎注册、选择和音频路由
class SpeechRecognitionManager {
    static let shared = SpeechRecognitionManager()

    /// 串行队列，保护共享状态的线程安全
    private let queue = DispatchQueue(label: "com.voicerelay.speechmanager", qos: .userInitiated)

    /// 已注册的引擎
    private var engines: [String: SpeechRecognitionEngine] = [:]

    /// 当前选中的引擎
    private(set) var currentEngine: SpeechRecognitionEngine?

    /// 当前会话 ID
    private var currentSessionId: String?

    private init() {}

    // MARK: - Engine Management

    /// 注册引擎
    /// - Parameter engine: 要注册的引擎
    func registerEngine(_ engine: SpeechRecognitionEngine) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.engines[engine.identifier] = engine
            print("✅ 注册语音识别引擎: \(engine.displayName) (\(engine.identifier))")

            // 如果是第一个引擎，自动选中
            if self.currentEngine == nil {
                try? self.selectEngine(identifier: engine.identifier)
            }
        }
    }

    /// 选择引擎
    /// - Parameter identifier: 引擎标识符
    func selectEngine(identifier: String) throws {
        try queue.sync {
            guard let engine = engines[identifier] else {
                throw SpeechError.noAvailableEngine
            }

            currentEngine = engine
            print("🎯 选择语音识别引擎: \(engine.displayName)")
        }
    }

    /// 获取所有可用引擎
    /// - Returns: 可用引擎列表
    func availableEngines() -> [SpeechRecognitionEngine] {
        return queue.sync {
            Array(engines.values)
        }
    }

    /// 获取引擎
    /// - Parameter identifier: 引擎标识符
    /// - Returns: 引擎实例
    func getEngine(identifier: String) -> SpeechRecognitionEngine? {
        return queue.sync {
            engines[identifier]
        }
    }

    // MARK: - Recognition Control

    /// 开始识别（使用当前引擎）
    /// - Parameters:
    ///   - sessionId: 会话 ID
    ///   - language: 识别语言
    func startRecognition(sessionId: String, language: String) throws {
        try queue.sync {
            guard let engine = currentEngine else {
                throw SpeechError.noEngineSelected
            }

            // 如果当前引擎不可用，尝试降级到 Apple Speech
            if !engine.isAvailable {
                if engine.identifier != "apple-speech" {
                    print("⚠️ \(engine.displayName) 不可用，降级到 Apple Speech")
                    try selectEngine(identifier: "apple-speech")
                    guard let fallbackEngine = currentEngine else {
                        throw SpeechError.noAvailableEngine
                    }
                    try fallbackEngine.startRecognition(sessionId: sessionId, language: language)
                    currentSessionId = sessionId
                    print("🎤 开始识别 - 引擎: \(fallbackEngine.displayName), 会话: \(sessionId), 语言: \(language)")
                    return
                } else {
                    throw SpeechError.engineNotAvailable
                }
            }

            try engine.startRecognition(sessionId: sessionId, language: language)
            currentSessionId = sessionId
            print("🎤 开始识别 - 引擎: \(engine.displayName), 会话: \(sessionId), 语言: \(language)")
        }
    }

    /// 处理音频数据
    /// - Parameter data: 音频数据
    func processAudioData(_ data: Data) throws {
        try queue.sync {
            guard let engine = currentEngine else {
                throw SpeechError.noEngineSelected
            }

            try engine.processAudioData(data)
        }
    }

    /// 停止识别
    func stopRecognition() throws {
        try queue.sync {
            guard let engine = currentEngine else {
                throw SpeechError.noEngineSelected
            }

            try engine.stopRecognition()
            print("🛑 停止识别 - 引擎: \(engine.displayName)")
            currentSessionId = nil
        }
    }

    // MARK: - Debugging

    /// 打印引擎状态
    func logEngineStatus() {
        queue.sync {
            print("📊 语音识别引擎状态:")
            for (id, engine) in engines {
                let status = engine.isAvailable ? "✅" : "❌"
                print("  \(status) \(engine.displayName) (\(id))")
            }
            if let current = currentEngine {
                print("  🎯 当前使用: \(current.displayName)")
            }
        }
    }
}
