# SenseVoice 语音识别引擎集成设计

**日期**: 2026-03-18
**版本**: 1.0
**状态**: 设计阶段

## 1. 概述

### 1.1 目标

在 VoiceRelayMac 项目中集成 SenseVoiceSmall 语音识别模型，作为 Apple Speech 框架的可选替代方案，并建立可扩展的多引擎架构，支持未来添加更多语音识别模型。

### 1.2 背景

当前 VoiceRelayMac 使用 Apple 的 Speech 框架进行语音识别。为了提供更多选择和更好的多语言支持，需要集成第三方语音识别模型。SenseVoiceSmall 是一个多任务语音理解模型，支持 50+ 语言，性能优秀且适合本地部署。

### 1.3 关键决策

- **运行位置**: 仅在 Mac 端运行 SenseVoiceSmall
- **音频来源**: 从 iPhone 接收音频流（保持现有架构）
- **离线支持**: 首次启动时下载模型，后续完全离线运行
- **技术方案**: 使用 sherpa-onnx 框架 + Swift 桥接
- **扩展性**: 支持多模型管理和引擎切换

## 2. 整体架构

### 2.1 架构层次

```
┌─────────────────────────────────────────────────────────┐
│                    VoiceRelayMac App                     │
├─────────────────────────────────────────────────────────┤
│  UI Layer (MenuBar, Settings)                           │
├─────────────────────────────────────────────────────────┤
│  Speech Recognition Manager                             │
│  ├─ Engine Registry (管理多个识别引擎)                    │
│  ├─ Engine Selector (选择当前使用的引擎)                  │
│  └─ Audio Router (路由音频到对应引擎)                     │
├─────────────────────────────────────────────────────────┤
│  Recognition Engines (识别引擎层)                         │
│  ├─ AppleSpeechEngine (现有的 Apple Speech)             │
│  └─ SenseVoiceEngine (新增的 SenseVoice)                │
│      └─ sherpa-onnx Swift Wrapper                       │
├─────────────────────────────────────────────────────────┤
│  Model Management (模型管理层)                           │
│  ├─ Model Downloader (下载模型)                          │
│  ├─ Model Storage (存储管理)                             │
│  └─ Model Registry (模型注册表)                          │
├─────────────────────────────────────────────────────────┤
│  Native Libraries                                        │
│  └─ sherpa-onnx (C++ library)                           │
└─────────────────────────────────────────────────────────┘
```

### 2.2 数据流

```
iPhone 音频采集
    ↓
通过 WebSocket 发送到 Mac
    ↓
SpeechRecognitionManager 接收
    ↓
根据用户设置选择引擎
    ↓
┌─────────────┬──────────────┐
│ Apple Speech│ SenseVoice   │
└─────────────┴──────────────┘
    ↓              ↓
识别结果返回
    ↓
注入到 Mac 光标位置
```

## 3. 核心组件设计

### 3.1 SpeechRecognitionEngine 协议

统一的识别引擎接口，所有引擎都必须实现此协议。

```swift
protocol SpeechRecognitionEngine {
    /// 引擎唯一标识符
    var identifier: String { get }

    /// 引擎显示名称
    var displayName: String { get }

    /// 支持的语言列表
    var supportedLanguages: [String] { get }

    /// 是否可用（模型已下载、权限已授予等）
    var isAvailable: Bool { get }

    /// 是否支持流式识别
    var supportsStreaming: Bool { get }

    /// 初始化引擎
    func initialize() async throws

    /// 开始识别
    func startRecognition(sessionId: String, language: String) throws

    /// 处理音频数据（流式）
    func processAudioData(_ data: Data) throws

    /// 停止识别
    func stopRecognition() throws

    /// 设置代理
    var delegate: SpeechRecognitionEngineDelegate? { get set }
}
```

### 3.2 SpeechRecognitionEngineDelegate 协议

```swift
protocol SpeechRecognitionEngineDelegate: AnyObject {
    /// 识别成功
    func engine(_ engine: SpeechRecognitionEngine,
                didRecognizeText text: String,
                sessionId: String,
                language: String)

    /// 识别失败
    func engine(_ engine: SpeechRecognitionEngine,
                didFailWithError error: Error,
                sessionId: String)

    /// 部分结果（可选，用于实时显示）
    func engine(_ engine: SpeechRecognitionEngine,
                didReceivePartialResult text: String,
                sessionId: String)
}
```

### 3.3 SpeechRecognitionManager

管理所有识别引擎，负责引擎注册、选择和音频路由。

```swift
class SpeechRecognitionManager {
    static let shared = SpeechRecognitionManager()

    /// 已注册的引擎
    private var engines: [String: SpeechRecognitionEngine] = [:]

    /// 当前选中的引擎
    private(set) var currentEngine: SpeechRecognitionEngine?

    /// 注册引擎
    func registerEngine(_ engine: SpeechRecognitionEngine)

    /// 选择引擎
    func selectEngine(identifier: String) throws

    /// 获取所有可用引擎
    func availableEngines() -> [SpeechRecognitionEngine]

    /// 开始识别（使用当前引擎）
    func startRecognition(sessionId: String, language: String) throws

    /// 处理音频数据
    func processAudioData(_ data: Data) throws

    /// 停止识别
    func stopRecognition() throws
}
```

### 3.4 ModelInfo 结构

```swift
struct ModelInfo: Codable {
    let id: String              // 模型唯一标识
    let name: String            // 显示名称
    let engineType: String      // 引擎类型（sensevoice, whisper 等）
    let version: String         // 版本号
    let languages: [String]     // 支持的语言
    let size: Int64             // 模型大小（字节）
    let downloadURL: URL        // 下载地址
    var localPath: URL?         // 本地路径（已下载）
    var isDownloaded: Bool      // 是否已下载
    let description: String     // 描述信息
}
```

### 3.5 ModelManager

管理模型的下载、存储和删除。

```swift
class ModelManager {
    static let shared = ModelManager()

    /// 获取所有可用模型列表
    func availableModels() async throws -> [ModelInfo]

    /// 下载模型
    func downloadModel(_ modelInfo: ModelInfo,
                       progress: @escaping (Double) -> Void) async throws

    /// 删除模型
    func deleteModel(_ modelInfo: ModelInfo) throws

    /// 获取已下载的模型
    func downloadedModels() -> [ModelInfo]

    /// 获取模型存储路径
    func modelStoragePath() -> URL

    /// 检查模型是否已下载
    func isModelDownloaded(engineType: String) -> Bool

    /// 获取模型路径
    func getModelPath(engineType: String) -> URL?
}
```

## 4. sherpa-onnx 集成

### 4.1 库集成方式

使用预编译的 xcframework，支持 macOS arm64 和 x86_64 架构。

**目录结构：**
```
VoiceRelayMac/
├── Frameworks/
│   └── sherpa-onnx.xcframework/
│       ├── macos-arm64/
│       └── macos-x86_64/
├── Speech/
│   ├── Engines/
│   │   ├── SpeechRecognitionEngine.swift
│   │   ├── AppleSpeechEngine.swift
│   │   └── SenseVoiceEngine.swift
│   ├── SherpaOnnx/
│   │   ├── SherpaOnnxBridge.h        // C 桥接头文件
│   │   ├── SherpaOnnxBridge.m        // C 桥接实现
│   │   └── SherpaOnnxWrapper.swift   // Swift 封装
│   └── SpeechRecognitionManager.swift
```

### 4.2 C 桥接层

由于 sherpa-onnx 是 C++ 库，需要通过 Objective-C 桥接到 Swift。

**SherpaOnnxBridge.h：**
```objc
#import <Foundation/Foundation.h>

@interface SherpaOnnxRecognizer : NSObject

- (instancetype)initWithModelPath:(NSString *)modelPath
                       tokensPath:(NSString *)tokensPath
                       sampleRate:(int)sampleRate;

- (void)acceptWaveform:(const float *)samples
                 count:(int)count;

- (NSString *)getText;

- (BOOL)isReady;

- (void)reset;

- (void)release;

@end
```

### 4.3 SenseVoiceEngine 实现

```swift
class SenseVoiceEngine: SpeechRecognitionEngine {
    let identifier = "sensevoice"
    let displayName = "SenseVoice"
    let supportedLanguages = ["zh-CN", "en-US", "ja-JP", "ko-KR", "yue-CN"]
    let supportsStreaming = true

    weak var delegate: SpeechRecognitionEngineDelegate?

    private var recognizer: SherpaOnnxRecognizer?
    private var currentSessionId: String?
    private var audioBuffer: [Float] = []

    var isAvailable: Bool {
        return ModelManager.shared.isModelDownloaded(engineType: "sensevoice")
    }

    func initialize() async throws {
        guard let modelPath = ModelManager.shared.getModelPath(engineType: "sensevoice") else {
            throw SenseVoiceError.modelNotFound
        }

        recognizer = SherpaOnnxRecognizer(
            modelPath: modelPath.appendingPathComponent("model.onnx").path,
            tokensPath: modelPath.appendingPathComponent("tokens.txt").path,
            sampleRate: 16000
        )
    }

    func startRecognition(sessionId: String, language: String) throws {
        guard let recognizer = recognizer else {
            throw SenseVoiceError.notInitialized
        }

        currentSessionId = sessionId
        audioBuffer.removeAll()
        recognizer.reset()
    }

    func processAudioData(_ data: Data) throws {
        guard let recognizer = recognizer else {
            throw SenseVoiceError.notInitialized
        }

        // 将 Int16 PCM 转换为 Float32
        let samples = convertToFloat32(data)
        audioBuffer.append(contentsOf: samples)

        // 每累积一定量的音频就送入识别器
        if audioBuffer.count >= 1600 { // 100ms @ 16kHz
            recognizer.acceptWaveform(audioBuffer, count: Int32(audioBuffer.count))
            audioBuffer.removeAll()

            // 检查是否有结果
            if recognizer.isReady() {
                let text = recognizer.getText()
                if !text.isEmpty {
                    delegate?.engine(self,
                                   didReceivePartialResult: text,
                                   sessionId: currentSessionId ?? "")
                }
            }
        }
    }

    func stopRecognition() throws {
        guard let recognizer = recognizer,
              let sessionId = currentSessionId else {
            return
        }

        // 处理剩余的音频
        if !audioBuffer.isEmpty {
            recognizer.acceptWaveform(audioBuffer, count: Int32(audioBuffer.count))
            audioBuffer.removeAll()
        }

        // 获取最终结果
        let finalText = recognizer.getText()

        if !finalText.isEmpty {
            delegate?.engine(self,
                           didRecognizeText: finalText,
                           sessionId: sessionId,
                           language: "zh-CN")
        }

        currentSessionId = nil
    }

    private func convertToFloat32(_ data: Data) -> [Float] {
        let int16Array = data.withUnsafeBytes {
            Array(UnsafeBufferPointer<Int16>(
                start: $0.baseAddress?.assumingMemoryBound(to: Int16.self),
                count: data.count / 2
            ))
        }

        return int16Array.map { Float($0) / Float(Int16.max) }
    }
}
```

### 4.4 音频格式处理

**关键点：**
- iPhone 发送的是 16-bit PCM 音频（16kHz, 单声道）
- sherpa-onnx 需要 Float32 格式
- 需要进行格式转换和归一化（Int16 → Float32，范围 -1.0 到 1.0）

## 5. 模型管理系统

### 5.1 模型存储结构

```
~/Library/Application Support/VoiceRelayMac/Models/
├── sensevoice-small/
│   ├── model.onnx           (主模型文件)
│   ├── tokens.txt           (词表文件)
│   ├── config.json          (配置文件)
│   └── metadata.json        (元数据)
├── whisper-base/            (未来扩展)
│   └── ...
└── models-registry.json     (模型注册表)
```

### 5.2 ModelManager 实现要点

**功能：**
- 从 HuggingFace 下载模型文件
- 显示下载进度
- 管理本地模型存储
- 提供模型元数据查询
- 支持模型删除

**下载流程：**
1. 创建模型目录
2. 依次下载 model.onnx、tokens.txt、config.json
3. 每个文件下载时报告进度
4. 下载完成后保存 metadata.json
5. 更新模型注册表

### 5.3 预定义模型列表

```swift
private let predefinedModels: [ModelInfo] = [
    ModelInfo(
        id: "sensevoice-small",
        name: "SenseVoice Small",
        engineType: "sensevoice",
        version: "1.0",
        languages: ["zh-CN", "en-US", "ja-JP", "ko-KR", "yue-CN"],
        size: 85_000_000, // 约 85MB
        downloadURL: URL(string: "https://huggingface.co/FunAudioLLM/SenseVoiceSmall/resolve/main/")!,
        localPath: nil,
        isDownloaded: false,
        description: "多语言语音识别模型，支持50+语言"
    )
]
```

## 6. 与现有系统集成

### 6.1 AppleSpeechEngine 适配

将现有的 `MacSpeechRecognizer` 改造为 `AppleSpeechEngine`，实现 `SpeechRecognitionEngine` 协议。保留原有的实现逻辑，只需适配接口。

### 6.2 ConnectionManager 集成

在 `ConnectionManager` 中使用 `SpeechRecognitionManager`：

```swift
class ConnectionManager {
    private let speechManager = SpeechRecognitionManager.shared

    func handleMessage(_ message: Message) {
        switch message.type {
        case "startListen":
            try? speechManager.startRecognition(
                sessionId: message.sessionId,
                language: message.language ?? "zh-CN"
            )

        case "audioData":
            if let audioData = message.audioData {
                try? speechManager.processAudioData(audioData)
            }

        case "stopListen":
            try? speechManager.stopRecognition()
        }
    }
}
```

### 6.3 应用启动初始化

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 注册 Apple Speech 引擎
        let appleSpeech = AppleSpeechEngine()
        SpeechRecognitionManager.shared.registerEngine(appleSpeech)

        // 如果 SenseVoice 模型已下载，注册它
        Task {
            if ModelManager.shared.isModelDownloaded(engineType: "sensevoice") {
                let senseVoice = SenseVoiceEngine()
                try? await senseVoice.initialize()
                SpeechRecognitionManager.shared.registerEngine(senseVoice)
            }
        }

        // 恢复上次选择的引擎
        let savedEngine = UserDefaults.standard.string(forKey: "selectedEngine") ?? "apple-speech"
        try? SpeechRecognitionManager.shared.selectEngine(identifier: savedEngine)
    }
}
```

### 6.4 设置持久化

```swift
extension UserDefaults {
    var selectedSpeechEngine: String {
        get { string(forKey: "selectedEngine") ?? "apple-speech" }
        set { set(newValue, forKey: "selectedEngine") }
    }
}
```

### 6.5 错误处理和降级策略

如果当前选中的引擎不可用，自动降级到 Apple Speech：

```swift
func startRecognition(sessionId: String, language: String) throws {
    guard let engine = currentEngine else {
        throw SpeechError.noEngineSelected
    }

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
}
```

## 7. 用户界面

### 7.1 设置窗口

新增"语音识别"设置页面：

**识别引擎选择：**
- 单选按钮：Apple Speech / SenseVoice
- 显示每个引擎的状态（可用/不可用）
- 显示当前使用的引擎

**模型管理：**
- 可用模型列表
- 每个模型显示：
  - 名称和描述
  - 支持的语言
  - 模型大小
  - 下载状态（未下载/下载中/已下载）
- 下载按钮和进度条
- 删除按钮（已下载的模型）

### 7.2 MenuBar 菜单

保持简洁，不添加额外的设置项。用户通过设置窗口管理引擎和模型。

## 8. 技术细节

### 8.1 依赖库

- **sherpa-onnx**: 语音识别推理引擎
- **现有依赖**: Speech.framework, AVFoundation, Network.framework

### 8.2 性能考虑

- **内存占用**: SenseVoice Small 模型约 85MB，运行时内存约 200-300MB
- **CPU 使用**: 实时识别时 CPU 使用率约 10-20%（Apple Silicon）
- **延迟**: 端到端延迟约 100-200ms

### 8.3 兼容性

- **macOS 版本**: 13.0+ (与现有要求一致)
- **架构**: arm64 和 x86_64 通用二进制
- **向后兼容**: 完全兼容现有的 Apple Speech 功能

## 9. 测试策略

### 9.1 单元测试

- SpeechRecognitionEngine 协议实现测试
- ModelManager 下载和存储测试
- 音频格式转换测试

### 9.2 集成测试

- 引擎切换测试
- 音频流处理测试
- 错误处理和降级测试

### 9.3 性能测试

- 识别准确率对比（Apple Speech vs SenseVoice）
- 识别速度测试
- 内存和 CPU 使用率测试

## 10. 实施计划

### 阶段 1: 基础架构（2-3 天）
- 实现 SpeechRecognitionEngine 协议
- 实现 SpeechRecognitionManager
- 适配现有的 MacSpeechRecognizer 为 AppleSpeechEngine

### 阶段 2: sherpa-onnx 集成（3-4 天）
- 集成 sherpa-onnx 库
- 实现 C 桥接层
- 实现 SenseVoiceEngine

### 阶段 3: 模型管理（2-3 天）
- 实现 ModelManager
- 实现模型下载功能
- 实现模型存储管理

### 阶段 4: UI 集成（2-3 天）
- 实现设置界面
- 实现模型管理界面
- 集成到现有应用

### 阶段 5: 测试和优化（2-3 天）
- 单元测试和集成测试
- 性能测试和优化
- Bug 修复

**总计**: 约 11-16 天

## 11. 风险和缓解

### 风险 1: sherpa-onnx 集成复杂度
**缓解**: 参考 sherpa-onnx 官方 iOS 示例，使用成熟的桥接方案

### 风险 2: 模型下载失败
**缓解**: 实现重试机制，提供备用下载源

### 风险 3: 识别准确率不如预期
**缓解**: 保留 Apple Speech 作为默认选项，用户可自由切换

### 风险 4: 性能问题
**缓解**: 在后台线程处理识别，避免阻塞主线程

## 12. 未来扩展

### 12.1 支持更多模型
- Whisper (OpenAI)
- Paraformer (阿里)
- 其他 ONNX 格式的语音模型

### 12.2 高级功能
- 自定义词表
- 热词增强
- 说话人分离
- 情感识别（SenseVoice 已支持）

### 12.3 性能优化
- 模型量化（减小体积）
- GPU 加速（Metal）
- 批处理优化

## 13. 参考资料

- [SenseVoice HuggingFace](https://huggingface.co/FunAudioLLM/SenseVoiceSmall)
- [sherpa-onnx Documentation](https://k2-fsa.github.io/sherpa/onnx/sense-voice/index.html)
- [sherpa-onnx iOS Guide](https://k2-fsa.github.io/sherpa/onnx/ios/build-sherpa-onnx-swift.html)
- [Running Speech Models with Swift](https://carlosmbe.medium.com/running-speech-models-with-swift-using-sherpa-onnx-for-apple-development-d31fdbd0898f)
