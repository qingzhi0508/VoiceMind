# 语音识别优化文档

## 优化内容

### A. 增大音频缓冲区（减少网络传输次数）

**修改文件**: `VoiceRelayiOS/VoiceRelayiOS/Speech/AudioStreamController.swift`

- 将 `bufferSize` 从 `1024` 增加到 `4096`
- **效果**:
  - 减少网络包数量约 75%
  - 降低网络传输开销
  - 提高音频数据的连续性
  - 更快的识别响应速度

### B. 启用部分结果实时反馈

**修改文件**:
1. `SharedCore/Sources/SharedCore/Protocol/MessageType.swift` - 添加 `partialResult` 消息类型
2. `SharedCore/Sources/SharedCore/Protocol/MessagePayloads.swift` - 添加 `PartialResultPayload`
3. `VoiceRelayMac/VoiceRelayMac/Network/ConnectionManager.swift` - 实现部分结果处理
4. `VoiceRelayMac/VoiceRelayMac/Speech/Engines/AppleSpeechEngine.swift` - 优化识别配置

**效果**:
- 实时反馈识别进度（部分结果）
- 减少最终结果等待时间（从 2 秒降到 0.5 秒）
- 更好的用户体验

### C. 其他优化

1. **Apple Speech 引擎优化**:
   - 启用自动标点（macOS 13+）
   - 优先使用设备上识别（离线模式）
   - 减少状态清理延迟

2. **iOS 端优化**:
   - 减少最终结果等待时间
   - 调整日志频率

## 架构设计 - 支持多模型

### 当前架构

项目已经设计了灵活的引擎架构，可以轻松添加新的语音识别模型：

```
SpeechRecognitionEngine (协议)
├── AppleSpeechEngine (Apple Speech Framework)
├── SenseVoiceEngine (Sherpa-ONNX + SenseVoice)
└── [你的新模型引擎]
```

### 添加新模型的步骤

#### 1. 创建新的引擎类

在 `VoiceRelayMac/VoiceRelayMac/Speech/Engines/` 目录下创建新文件，例如 `YourModelEngine.swift`：

```swift
import Foundation

class YourModelEngine: NSObject, SpeechRecognitionEngine {

    // MARK: - SpeechRecognitionEngine Protocol

    let identifier = "your-model"  // 唯一标识符
    let displayName = "Your Model"  // 显示名称
    let supportsStreaming = true    // 是否支持流式识别

    var supportedLanguages: [String] {
        return ["zh-CN", "en-US"]  // 支持的语言
    }

    var isAvailable: Bool {
        // 检查模型是否可用（已下载、权限等）
        return true
    }

    weak var delegate: SpeechRecognitionEngineDelegate?

    // MARK: - Private Properties

    private var currentSessionId: String?
    private var currentLanguage: String?
    // 添加你的模型相关属性

    // MARK: - Initialization

    override init() {
        super.init()
        // 初始化你的模型
    }

    // MARK: - SpeechRecognitionEngine Methods

    func initialize() async throws {
        print("🎤 初始化 Your Model 引擎")
        // 加载模型、初始化资源
        print("✅ Your Model 引擎初始化成功")
    }

    func startRecognition(sessionId: String, language: String) throws {
        print("🎤 Your Model 开始识别")
        print("   Session ID: \(sessionId)")
        print("   语言: \(language)")

        currentSessionId = sessionId
        currentLanguage = language

        // 启动识别
    }

    func processAudioData(_ data: Data) throws {
        guard currentSessionId != nil else {
            return
        }

        // 处理音频数据（16-bit PCM, 16kHz, 单声道）
        // 1. 转换音频格式（如果需要）
        // 2. 送入模型进行识别
        // 3. 如果有部分结果，调用 delegate

        // 示例：部分结果
        // delegate?.engine(self, didReceivePartialResult: "部分文本", sessionId: sessionId)
    }

    func stopRecognition() throws {
        guard let sessionId = currentSessionId,
              let language = currentLanguage else {
            return
        }

        print("🛑 Your Model 停止识别")

        // 完成识别，获取最终结果
        let finalText = "最终识别文本"

        if !finalText.isEmpty {
            delegate?.engine(self, didRecognizeText: finalText, sessionId: sessionId, language: language)
        }

        currentSessionId = nil
        currentLanguage = nil
    }
}
```

#### 2. 注册新引擎

在 `VoiceRelayMacApp.swift` 或相应的初始化位置注册你的引擎：

```swift
// 注册语音识别引擎
let yourModelEngine = YourModelEngine()
Task {
    try? await yourModelEngine.initialize()
}
speechManager.registerEngine(yourModelEngine)
```

#### 3. 选择引擎

用户可以通过 UI 或配置选择使用哪个引擎：

```swift
try speechManager.selectEngine(identifier: "your-model")
```

### 引擎协议说明

#### 必须实现的属性

- `identifier`: 唯一标识符（如 "apple-speech", "sensevoice", "whisper"）
- `displayName`: 用户可见的显示名称
- `supportedLanguages`: 支持的语言列表（如 ["zh-CN", "en-US"]）
- `isAvailable`: 引擎是否可用（模型已下载、权限已授予等）
- `supportsStreaming`: 是否支持流式识别
- `delegate`: 用于回调识别结果

#### 必须实现的方法

1. **initialize()**: 异步初始化引擎（加载模型、申请权限等）
2. **startRecognition(sessionId:language:)**: 开始识别会话
3. **processAudioData(_:)**: 处理音频数据（16-bit PCM, 16kHz, 单声道）
4. **stopRecognition()**: 停止识别并返回最终结果

#### 代理回调

通过 `SpeechRecognitionEngineDelegate` 回调识别结果：

```swift
// 最终结果（必须）
delegate?.engine(self, didRecognizeText: text, sessionId: sessionId, language: language)

// 部分结果（可选，用于实时反馈）
delegate?.engine(self, didReceivePartialResult: text, sessionId: sessionId)

// 错误（可选）
delegate?.engine(self, didFailWithError: error, sessionId: sessionId)
```

## 常见模型集成示例

### 1. Whisper (OpenAI)

```swift
class WhisperEngine: NSObject, SpeechRecognitionEngine {
    let identifier = "whisper"
    let displayName = "Whisper"

    // 使用 whisper.cpp 或 CoreML 版本
    // 累积音频后批量识别
}
```

### 2. Vosk

```swift
class VoskEngine: NSObject, SpeechRecognitionEngine {
    let identifier = "vosk"
    let displayName = "Vosk"

    // 使用 Vosk iOS/macOS SDK
    // 支持流式识别
}
```

### 3. 自定义 ONNX 模型

```swift
class CustomONNXEngine: NSObject, SpeechRecognitionEngine {
    let identifier = "custom-onnx"
    let displayName = "Custom ONNX"

    // 使用 ONNX Runtime
    // 参考 SenseVoiceEngine 的实现
}
```

## 性能优化建议

### 1. 音频缓冲区大小

- **小缓冲区 (1024-2048)**: 更低延迟，但网络开销大
- **中缓冲区 (4096-8192)**: 平衡延迟和效率（推荐）
- **大缓冲区 (16384+)**: 最低网络开销，但延迟较高

### 2. 识别模式

- **流式识别**: 实时反馈，适合对话场景
- **批量识别**: 累积音频后识别，适合离线模型

### 3. 模型选择

- **Apple Speech**: 系统集成，质量高，但需要网络（除非下载离线包）
- **SenseVoice**: 离线模型，速度快，支持多语言
- **Whisper**: 高质量，但速度较慢，适合批量处理
- **Vosk**: 轻量级，离线，速度快

## 测试建议

1. **延迟测试**: 测量从说话到文字插入的总延迟
2. **准确率测试**: 测试不同语速、口音的识别准确率
3. **网络测试**: 测试不同网络条件下的表现
4. **电池测试**: 测试不同引擎的电池消耗

## 故障排查

### 识别速度慢

1. 检查网络连接（如果使用在线识别）
2. 检查音频缓冲区大小
3. 检查是否启用了部分结果
4. 尝试切换到离线模型

### 识别不准确

1. 检查麦克风权限
2. 检查音频格式配置
3. 检查语言设置
4. 尝试不同的识别引擎

### 连接问题

1. 检查 WebSocket 连接状态
2. 检查 HMAC 验证
3. 检查防火墙设置
4. 查看日志输出

## 未来改进方向

1. **混合识别**: 同时使用多个引擎，选择最佳结果
2. **自适应缓冲**: 根据网络状况动态调整缓冲区大小
3. **模型热切换**: 运行时切换引擎无需重启
4. **结果后处理**: 标点、大小写、数字转换等
5. **语音活动检测 (VAD)**: 自动检测说话开始/结束
