# SenseVoice 集成实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 VoiceMindMac 中集成 SenseVoiceSmall 语音识别模型，建立可扩展的多引擎架构

**Architecture:** 基于协议的引擎抽象层，支持多个语音识别引擎（Apple Speech、SenseVoice）。使用 sherpa-onnx 通过 C 桥接集成 ONNX 模型。模型管理系统负责下载和存储。

**Tech Stack:** Swift, sherpa-onnx (C++), Objective-C 桥接, ONNX Runtime, SwiftUI

---

## 文件结构规划

### 新增文件

```
VoiceMindMac/VoiceMindMac/
├── Speech/
│   ├── Engines/
│   │   ├── SpeechRecognitionEngine.swift          # 引擎协议定义
│   │   ├── AppleSpeechEngine.swift                # Apple Speech 适配器
│   │   └── SenseVoiceEngine.swift                 # SenseVoice 引擎
│   ├── SpeechRecognitionManager.swift             # 引擎管理器
│   ├── SpeechErrors.swift                         # 错误定义
│   └── SherpaOnnx/
│       ├── SherpaOnnxBridge.h                     # C 桥接头文件
│       ├── SherpaOnnxBridge.m                     # C 桥接实现
│       └── SherpaOnnxWrapper.swift                # Swift 封装
├── Models/
│   ├── ModelInfo.swift                            # 模型信息结构
│   ├── ModelManager.swift                         # 模型管理器
│   └── ModelDownloader.swift                      # 模型下载器
├── Settings/
│   ├── SpeechEngineSettingsView.swift             # 引擎设置界面
│   └── ModelManagementView.swift                  # 模型管理界面
└── Extensions/
    └── UserDefaults+Speech.swift                  # 设置持久化

VoiceMindMacTests/
├── SpeechRecognitionManagerTests.swift
├── ModelManagerTests.swift
└── AudioFormatConversionTests.swift
```

### 修改文件

```
VoiceMindMac/VoiceMindMac/
├── Network/ConnectionManager.swift                # 集成 SpeechRecognitionManager
├── VoiceMindMacApp.swift                         # 初始化引擎
└── Speech/MacSpeechRecognizer.swift               # 重构为 AppleSpeechEngine
```

---

## Chunk 1: 基础架构 - 协议和错误定义

### Task 1: 创建语音识别引擎协议

**Files:**
- Create: `VoiceMindMac/VoiceMindMac/Speech/Engines/SpeechRecognitionEngine.swift`

- [ ] **Step 1: 创建 Speech/Engines 目录**

```bash
mkdir -p VoiceMindMac/VoiceMindMac/Speech/Engines
```

- [ ] **Step 2: 创建 SpeechRecognitionEngine.swift 文件**

```swift
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
```

- [ ] **Step 3: 在 Xcode 中添加文件到项目**

打开 Xcode，右键点击 `Speech` 文件夹，选择 "Add Files to VoiceMindMac"，添加 `Engines` 文件夹。

- [ ] **Step 4: 验证编译**

```bash
cd VoiceMindMac
xcodebuild -workspace ../VoiceMind.xcworkspace \
    -scheme VoiceMindMac \
    -configuration Debug \
    build
```

Expected: 编译成功

- [ ] **Step 5: 提交**

```bash
git add VoiceMindMac/VoiceMindMac/Speech/Engines/SpeechRecognitionEngine.swift
git commit -m "feat: add SpeechRecognitionEngine protocol

Define unified interface for speech recognition engines.
Supports multiple engines (Apple Speech, SenseVoice, etc.)

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 2: 创建错误定义

**Files:**
- Create: `VoiceMindMac/VoiceMindMac/Speech/SpeechErrors.swift`

- [ ] **Step 1: 创建 SpeechErrors.swift 文件**

```swift
import Foundation

/// 语音识别相关错误
enum SpeechError: LocalizedError {
    case noEngineSelected
    case noAvailableEngine
    case engineNotAvailable
    case engineNotInitialized
    case invalidAudioFormat
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .noEngineSelected:
            return "未选择语音识别引擎"
        case .noAvailableEngine:
            return "没有可用的语音识别引擎"
        case .engineNotAvailable:
            return "当前引擎不可用"
        case .engineNotInitialized:
            return "引擎未初始化"
        case .invalidAudioFormat:
            return "无效的音频格式"
        case .recognitionFailed(let reason):
            return "识别失败: \(reason)"
        }
    }
}

/// SenseVoice 引擎错误
enum SenseVoiceError: LocalizedError {
    case modelNotFound
    case modelLoadFailed
    case notInitialized
    case invalidModelPath
    case audioConversionFailed

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "SenseVoice 模型未找到"
        case .modelLoadFailed:
            return "SenseVoice 模型加载失败"
        case .notInitialized:
            return "SenseVoice 引擎未初始化"
        case .invalidModelPath:
            return "无效的模型路径"
        case .audioConversionFailed:
            return "音频格式转换失败"
        }
    }
}

/// 模型管理错误
enum ModelError: LocalizedError {
    case downloadFailed(String)
    case modelNotFound
    case invalidModel
    case storageError
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let reason):
            return "模型下载失败: \(reason)"
        case .modelNotFound:
            return "模型未找到"
        case .invalidModel:
            return "无效的模型文件"
        case .storageError:
            return "存储错误"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        }
    }
}
```

- [ ] **Step 2: 在 Xcode 中添加文件到项目**

- [ ] **Step 3: 验证编译**

```bash
xcodebuild -workspace ../VoiceMind.xcworkspace \
    -scheme VoiceMindMac \
    -configuration Debug \
    build
```

Expected: 编译成功

- [ ] **Step 4: 提交**

```bash
git add VoiceMindMac/VoiceMindMac/Speech/SpeechErrors.swift
git commit -m "feat: add speech recognition error definitions

Define error types for speech engines and model management

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 3: 创建 SpeechRecognitionManager

**Files:**
- Create: `VoiceMindMac/VoiceMindMac/Speech/SpeechRecognitionManager.swift`

- [ ] **Step 1: 创建 SpeechRecognitionManager.swift 文件**

```swift
import Foundation

/// 语音识别管理器
/// 负责管理多个识别引擎，处理引擎注册、选择和音频路由
class SpeechRecognitionManager {
    static let shared = SpeechRecognitionManager()

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
        engines[engine.identifier] = engine
        print("✅ 注册语音识别引擎: \(engine.displayName) (\(engine.identifier))")

        // 如果是第一个引擎，自动选中
        if currentEngine == nil {
            try? selectEngine(identifier: engine.identifier)
        }
    }

    /// 选择引擎
    /// - Parameter identifier: 引擎标识符
    func selectEngine(identifier: String) throws {
        guard let engine = engines[identifier] else {
            throw SpeechError.noAvailableEngine
        }

        currentEngine = engine
        print("🎯 选择语音识别引擎: \(engine.displayName)")
    }

    /// 获取所有可用引擎
    /// - Returns: 可用引擎列表
    func availableEngines() -> [SpeechRecognitionEngine] {
        return Array(engines.values)
    }

    /// 获取引擎
    /// - Parameter identifier: 引擎标识符
    /// - Returns: 引擎实例
    func getEngine(identifier: String) -> SpeechRecognitionEngine? {
        return engines[identifier]
    }

    // MARK: - Recognition Control

    /// 开始识别（使用当前引擎）
    /// - Parameters:
    ///   - sessionId: 会话 ID
    ///   - language: 识别语言
    func startRecognition(sessionId: String, language: String) throws {
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
            } else {
                throw SpeechError.engineNotAvailable
            }
        } else {
            try engine.startRecognition(sessionId: sessionId, language: language)
        }

        currentSessionId = sessionId
        print("🎤 开始识别 - 引擎: \(engine.displayName), 会话: \(sessionId), 语言: \(language)")
    }

    /// 处理音频数据
    /// - Parameter data: 音频数据
    func processAudioData(_ data: Data) throws {
        guard let engine = currentEngine else {
            throw SpeechError.noEngineSelected
        }

        try engine.processAudioData(data)
    }

    /// 停止识别
    func stopRecognition() throws {
        guard let engine = currentEngine else {
            throw SpeechError.noEngineSelected
        }

        try engine.stopRecognition()
        print("🛑 停止识别 - 引擎: \(engine.displayName)")
        currentSessionId = nil
    }

    // MARK: - Debugging

    /// 打印引擎状态
    func logEngineStatus() {
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
```

- [ ] **Step 2: 在 Xcode 中添加文件到项目**

- [ ] **Step 3: 验证编译**

```bash
xcodebuild -workspace ../VoiceMind.xcworkspace \
    -scheme VoiceMindMac \
    -configuration Debug \
    build
```

Expected: 编译成功

- [ ] **Step 4: 提交**

```bash
git add VoiceMindMac/VoiceMindMac/Speech/SpeechRecognitionManager.swift
git commit -m "feat: add SpeechRecognitionManager

Manage multiple speech recognition engines.
Support engine registration, selection, and audio routing.
Implement fallback strategy to Apple Speech.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Chunk 2: Apple Speech 引擎适配

### Task 4: 重构 MacSpeechRecognizer 为 AppleSpeechEngine

**Files:**
- Create: `VoiceMindMac/VoiceMindMac/Speech/Engines/AppleSpeechEngine.swift`
- Modify: `VoiceMindMac/VoiceMindMac/Speech/MacSpeechRecognizer.swift` (保留作为参考)

- [ ] **Step 1: 创建 AppleSpeechEngine.swift 文件**

```swift
import Foundation
import Speech
import AVFoundation

/// Apple Speech 引擎适配器
/// 将现有的 MacSpeechRecognizer 适配到 SpeechRecognitionEngine 协议
class AppleSpeechEngine: NSObject, SpeechRecognitionEngine {

    // MARK: - SpeechRecognitionEngine Protocol

    let identifier = "apple-speech"
    let displayName = "Apple Speech"
    let supportedLanguages = ["zh-CN", "en-US", "ja-JP", "ko-KR"]
    let supportsStreaming = true

    var isAvailable: Bool {
        return SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    weak var delegate: SpeechRecognitionEngineDelegate?

    // MARK: - Properties

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private var currentSessionId: String?
    private var selectedLanguage: String = "zh-CN"

    // 音频格式参数
    private var audioFormat: AVAudioFormat?
    private var sampleRate: Double = 16000
    private var channels: AVAudioChannelCount = 1

    // MARK: - Initialization

    override init() {
        super.init()
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        checkAvailability()
    }

    // MARK: - SpeechRecognitionEngine Methods

    func initialize() async throws {
        // Apple Speech 不需要额外初始化
        // 只需要请求权限
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard status == .authorized else {
            throw SpeechError.engineNotAvailable
        }

        print("✅ Apple Speech 引擎初始化成功")
    }

    func startRecognition(sessionId: String, language: String) throws {
        print("🎤 Apple Speech 开始识别")
        print("   Session ID: \(sessionId)")
        print("   语言: \(language)")

        // 停止之前的识别任务
        stopRecognition()

        self.currentSessionId = sessionId
        self.selectedLanguage = language
        self.sampleRate = 16000
        self.channels = 1

        // 创建音频格式
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: self.sampleRate,
            channels: self.channels,
            interleaved: false
        ) else {
            throw SpeechError.invalidAudioFormat
        }

        self.audioFormat = format

        // 使用指定语言
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language))

        guard let recognizer = recognizer else {
            throw SpeechError.engineNotAvailable
        }

        guard recognizer.isAvailable else {
            throw SpeechError.engineNotAvailable
        }

        self.speechRecognizer = recognizer

        // 创建识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.recognitionFailed("无法创建识别请求")
        }

        // 配置识别请求
        recognitionRequest.shouldReportPartialResults = true

        // 优先使用设备上识别（离线）
        if recognizer.supportsOnDeviceRecognition {
            recognitionRequest.requiresOnDeviceRecognition = true
            print("✅ 使用设备上识别（离线模式）")
        } else {
            print("⚠️ 设备上识别不可用，将使用在线识别")
        }

        // 开始识别任务
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let text = result.bestTranscription.formattedString
                let isFinal = result.isFinal

                if isFinal {
                    self.delegate?.engine(
                        self,
                        didRecognizeText: text,
                        sessionId: sessionId,
                        language: language
                    )
                } else {
                    self.delegate?.engine(
                        self,
                        didReceivePartialResult: text,
                        sessionId: sessionId
                    )
                }
            }

            if let error = error {
                print("❌ Apple Speech 识别错误: \(error.localizedDescription)")
                self.delegate?.engine(
                    self,
                    didFailWithError: error,
                    sessionId: sessionId
                )
            }
        }

        print("✅ Apple Speech 识别任务已启动，等待音频数据")
    }

    func processAudioData(_ data: Data) throws {
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.engineNotInitialized
        }

        guard let audioFormat = audioFormat else {
            throw SpeechError.invalidAudioFormat
        }

        // 将 Data 转换为 AVAudioPCMBuffer
        guard let buffer = dataToAudioBuffer(data, format: audioFormat) else {
            throw SpeechError.invalidAudioFormat
        }

        // 追加到识别请求
        recognitionRequest.append(buffer)
    }

    func stopRecognition() throws {
        guard currentSessionId != nil else {
            return
        }

        print("🛑 Apple Speech 停止识别")

        // 结束识别请求
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        // 取消识别任务（延迟取消，等待最终结果）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.recognitionTask?.cancel()
            self?.recognitionTask = nil
        }

        currentSessionId = nil
        audioFormat = nil
    }

    // MARK: - Private Methods

    private func checkAvailability() {
        guard let recognizer = speechRecognizer else {
            print("❌ Apple Speech 识别器初始化失败")
            return
        }

        print("✅ Apple Speech 识别器可用")
        print("   语言: \(recognizer.locale.identifier)")
        print("   支持设备上识别: \(recognizer.supportsOnDeviceRecognition)")
    }

    /// 将 Data 转换为 AVAudioPCMBuffer
    private func dataToAudioBuffer(_ data: Data, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let bytesPerSample = MemoryLayout<Int16>.size
        let channelCount = Int(format.channelCount)
        let frameCount = UInt32(data.count / (bytesPerSample * max(channelCount, 1)))

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }

        buffer.frameLength = frameCount

        guard let floatChannelData = buffer.floatChannelData else {
            return nil
        }

        // 将 16-bit PCM 转换为归一化的 Float32
        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            guard let samples = bytes.bindMemory(to: Int16.self).baseAddress else {
                return
            }

            let totalFrames = Int(frameCount)
            for frame in 0..<totalFrames {
                for channel in 0..<channelCount {
                    let sampleIndex = frame * channelCount + channel
                    floatChannelData[channel][frame] = Float(samples[sampleIndex]) / Float(Int16.max)
                }
            }
        }

        return buffer
    }
}
```

- [ ] **Step 2: 在 Xcode 中添加文件到项目**

- [ ] **Step 3: 验证编译**

```bash
xcodebuild -workspace ../VoiceMind.xcworkspace \
    -scheme VoiceMindMac \
    -configuration Debug \
    build
```

Expected: 编译成功

- [ ] **Step 4: 提交**

```bash
git add VoiceMindMac/VoiceMindMac/Speech/Engines/AppleSpeechEngine.swift
git commit -m "feat: add AppleSpeechEngine adapter

Adapt existing MacSpeechRecognizer to SpeechRecognitionEngine protocol.
Preserve all existing functionality.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

