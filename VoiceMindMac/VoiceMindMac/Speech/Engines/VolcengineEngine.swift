import Foundation

/// 火山引擎云端 ASR 语音识别引擎
/// 通过 WebSocket 二进制协议连接火山引擎大模型 ASR 服务
class VolcengineEngine: NSObject, SpeechRecognitionEngine {

    // MARK: - SpeechRecognitionEngine Protocol

    let identifier = "volcengine"
    var displayName: String { "火山引擎 ASR" }
    var supportedLanguages: [String] { ["zh-CN", "en-US", "ja-JP", "yue-CN"] }
    var supportsStreaming: Bool { true }

    var isAvailable: Bool {
        let appId = UserDefaults.standard.volcengineAppId
        let accessKey = UserDefaults.standard.volcengineAccessKey
        return !appId.isEmpty && !accessKey.isEmpty
    }

    weak var delegate: SpeechRecognitionEngineDelegate?

    // MARK: - Private Properties

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var currentSessionId: String?
    private var currentLanguage: String?
    private var sequence: Int32 = 0
    private var receiveTask: Task<Void, Never>?
    private var lastPartialText: String = ""
    private var cleanupTask: Task<Void, Never>?

    // MARK: - SpeechRecognitionEngine Methods

    func initialize() async throws {
        print("✅ 火山引擎 ASR 引擎初始化完成")
    }

    func startRecognition(sessionId: String, language: String) throws {
        print("🎤 火山引擎 ASR 开始识别, session=\(sessionId), lang=\(language)")

        guard isAvailable else {
            throw SpeechError.recognitionFailed("火山引擎未配置，请在设置中填写 App ID 和 Access Key")
        }

        // 清理旧连接（不触发 stopRecognition 的 delegate 回调）
        forceCleanup()

        currentSessionId = sessionId
        currentLanguage = language
        sequence = 1
        lastPartialText = ""

        // 创建 WebSocket 连接
        let appId = UserDefaults.standard.volcengineAppId
        let accessKey = UserDefaults.standard.volcengineAccessKey
        let resourceId = UserDefaults.standard.volcengineResourceId
        let connectId = UUID().uuidString

        guard let url = URL(string: VolcengineBinaryProtocol.websocketURL) else {
            throw SpeechError.recognitionFailed("无效的 WebSocket URL")
        }

        var request = URLRequest(url: url)
        for (key, value) in VolcengineBinaryProtocol.buildRequestHeaders(
            appId: appId,
            accessKey: accessKey,
            resourceId: resourceId,
            connectId: connectId
        ) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        urlSession = session

        let wsTask = session.webSocketTask(with: request)
        webSocketTask = wsTask
        wsTask.resume()

        // 启动接收循环
        receiveTask = Task { [weak self] in
            self?.receiveLoop()
        }

        // 发送配置帧
        let configFrame = VolcengineBinaryProtocol.buildConfigFrame(language: language)
        wsTask.send(.data(configFrame)) { error in
            if let error {
                print("❌ 火山引擎发送配置帧失败: \(error.localizedDescription)")
            } else {
                print("✅ 火山引擎配置帧已发送")
            }
        }
    }

    func processAudioData(_ data: Data) throws {
        guard let wsTask = webSocketTask else {
            return
        }

        sequence += 1
        let frame = VolcengineBinaryProtocol.buildAudioFrame(audioData: data, sequence: sequence)

        wsTask.send(.data(frame)) { error in
            if let error {
                print("⚠️ 火山引擎发送音频失败: \(error.localizedDescription)")
            }
        }
    }

    func stopRecognition() throws {
        guard let sessionId = currentSessionId else { return }

        let capturedLanguage = currentLanguage

        // 发送结束帧
        if let wsTask = webSocketTask {
            let finishFrame = VolcengineBinaryProtocol.buildFinishFrame()
            wsTask.send(.data(finishFrame)) { error in
                if let error {
                    print("⚠️ 火山引擎发送结束帧失败: \(error.localizedDescription)")
                } else {
                    print("✅ 火山引擎结束帧已发送")
                }
            }
        }

        // 延迟关闭连接，等待最终结果返回
        let sessionIdToMatch = sessionId
        cleanupTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 秒后关闭
            guard let self, self.currentSessionId == nil else { return }
            self.cleanupConnection()
        }

        // 如果有最后的 partial result，作为最终结果发送
        if !lastPartialText.isEmpty, let language = capturedLanguage {
            delegate?.engine(self, didRecognizeText: lastPartialText, sessionId: sessionId, language: language)
        }

        currentSessionId = nil
        currentLanguage = nil
    }

    // MARK: - Private Methods

    /// 强制清理旧连接，不触发 delegate 回调
    private func forceCleanup() {
        // 取消待执行的延迟清理
        cleanupTask?.cancel()
        cleanupTask = nil

        cleanupConnection()

        currentSessionId = nil
        currentLanguage = nil
        lastPartialText = ""
    }

    private func receiveLoop() {
        func receiveNext() {
            guard let wsTask = self.webSocketTask else { return }

            wsTask.receive { [weak self] result in
                guard let self else { return }

                switch result {
                case .success(let message):
                    switch message {
                    case .data(let data):
                        self.handleServerData(data)
                    case .string(let text):
                        print("⚠️ 火山引擎收到非预期的文本消息: \(text.prefix(200))")
                    @unknown default:
                        break
                    }
                    receiveNext()

                case .failure(let error):
                    print("⚠️ 火山引擎 WebSocket 接收错误: \(error.localizedDescription)")
                }
            }
        }

        receiveNext()
    }

    private func handleServerData(_ data: Data) {
        let responses = VolcengineBinaryProtocol.parseServerResponse(data)

        guard let sessionId = currentSessionId else { return }

        for response in responses {
            if response.isFinal {
                print("🎯 火山引擎最终结果: \(response.text)")
                if let language = currentLanguage {
                    delegate?.engine(self, didRecognizeText: response.text, sessionId: sessionId, language: language)
                }
                cleanupConnection()
            } else {
                lastPartialText = response.text
                delegate?.engine(self, didReceivePartialResult: response.text, sessionId: sessionId)
            }
        }
    }

    private func cleanupConnection() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
    }
}

// MARK: - URLSessionWebSocketDelegate

extension VolcengineEngine: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("✅ 火山引擎 WebSocket 已连接")
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("🔌 火山引擎 WebSocket 已关闭, code=\(closeCode.rawValue)")
        if let reason, let reasonString = String(data: reason, encoding: .utf8) {
            print("   reason: \(reasonString)")
        }
    }
}
