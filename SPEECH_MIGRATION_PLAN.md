# iOS 到 Mac 语音流传输与本地识别技术方案

## 方案概述

将语音识别从 iOS 端迁移到 Mac 端，实现：
1. iOS 端捕获音频并流式传输到 Mac
2. Mac 端使用本地语音识别（优先系统 API，备选本地模型）
3. 识别结果返回给 Mac 应用进行文本注入

## 方案对比

### 方案一：macOS Speech 框架（推荐）✅

**优点：**
- ✅ 系统原生支持，无需额外依赖
- ✅ 支持离线识别（`supportsOnDeviceRecognition`）
- ✅ 支持多种语言（中文、英文、粤语等）
- ✅ 识别准确率高（Apple Neural Engine 加速）
- ✅ 自动标点符号
- ✅ 实时流式识别
- ✅ 零成本

**缺点：**
- ⚠️ 需要 macOS 10.15+
- ⚠️ 需要用户授权语音识别权限
- ⚠️ 离线识别需要 macOS 13+ 和 Apple Silicon

**技术要求：**
```swift
import Speech
import AVFoundation

// 检查支持情况
let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
print("支持设备上识别: \(recognizer?.supportsOnDeviceRecognition ?? false)")
```

### 方案二：Whisper 本地模型

**优点：**
- ✅ 完全离线
- ✅ 支持多语言
- ✅ 开源免费
- ✅ 准确率高

**缺点：**
- ❌ 需要集成 C++ 模型（whisper.cpp）
- ❌ 模型文件较大（39MB - 1.5GB）
- ❌ 需要较高的 CPU/GPU 资源
- ❌ 实时性较差（需要完整音频片段）
- ❌ 开发复杂度高

### 方案三：在线 API（不推荐）

**缺点：**
- ❌ 需要网络连接
- ❌ 有成本
- ❌ 隐私问题
- ❌ 延迟高

## 推荐方案：macOS Speech 框架

### 架构设计

```
┌─────────────┐                    ┌─────────────┐
│   iOS 端    │                    │   Mac 端    │
│             │                    │             │
│  麦克风捕获  │ ──音频流(PCM)──→  │  接收音频   │
│             │                    │      ↓      │
│             │                    │  Speech API │
│             │                    │      ↓      │
│             │ ←──识别结果────    │  返回文本   │
│             │                    │      ↓      │
│             │                    │  文本注入   │
└─────────────┘                    └─────────────┘
```

### 数据流设计

#### 1. 音频格式

**iOS 端输出格式：**
```swift
// 使用 AVAudioPCMBuffer
采样率: 16000 Hz (推荐) 或 44100 Hz
通道数: 1 (单声道)
位深度: 16-bit PCM
格式: Linear PCM
```

**传输格式：**
```
消息类型: .audioData
Payload: {
    sessionId: String,      // 会话 ID
    audioData: Data,        // PCM 音频数据
    sampleRate: Int,        // 采样率
    channels: Int,          // 通道数
    format: String          // "pcm16"
}
```

#### 2. 消息协议扩展

在 `SharedCore/Models/MessageType.swift` 中添加：

```swift
enum MessageType: String, Codable {
    // ... 现有类型
    case audioData          // iOS -> Mac: 音频数据流
    case audioStart         // iOS -> Mac: 开始音频流
    case audioEnd           // iOS -> Mac: 结束音频流
    case recognitionResult  // Mac -> iOS: 识别结果（可选，用于反馈）
}
```

### 实现步骤

#### 阶段一：验证 macOS Speech 可用性 ✅

1. 创建 `MacSpeechRecognizer.swift`（已完成）
2. 创建测试程序验证功能
3. 测试不同语言的识别效果
4. 测试离线识别能力

**测试代码：**
```swift
// 在 Mac 端运行
SpeechRecognitionTest.testSystemInfo()
SpeechRecognitionTest.testAvailability()
```

#### 阶段二：iOS 端音频流传输

**修改 iOS 端 `SpeechController`：**

```swift
class SpeechController {
    // 添加音频流传输
    func startStreaming(sessionId: String) {
        // 1. 配置音频格式
        let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )

        // 2. 安装音频 tap
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, time in
            // 3. 将 buffer 转换为 Data
            let audioData = self.bufferToData(buffer)

            // 4. 发送到 Mac
            self.sendAudioData(audioData, sessionId: sessionId)
        }

        // 5. 启动音频引擎
        try? audioEngine.start()
    }

    private func bufferToData(_ buffer: AVAudioPCMBuffer) -> Data {
        let audioBuffer = buffer.audioBufferList.pointee.mBuffers
        return Data(bytes: audioBuffer.mData!, count: Int(audioBuffer.mDataByteSize))
    }
}
```

#### 阶段三：Mac 端接收和识别

**修改 Mac 端 `ConnectionManager`：**

```swift
class ConnectionManager {
    private let speechRecognizer = MacSpeechRecognizer()

    func handleAudioStart(_ payload: AudioStartPayload) {
        try? speechRecognizer.startRecognition(
            sessionId: payload.sessionId,
            languageCode: payload.language
        )
    }

    func handleAudioData(_ payload: AudioDataPayload) {
        speechRecognizer.processAudioData(payload.audioData)
    }

    func handleAudioEnd(_ payload: AudioEndPayload) {
        speechRecognizer.stopRecognition()
    }
}
```

#### 阶段四：优化和测试

1. **延迟优化**：
   - 使用流式识别（`shouldReportPartialResults = true`）
   - 减小音频缓冲区大小
   - 优化网络传输

2. **准确率优化**：
   - 使用合适的采样率（16kHz 或 44.1kHz）
   - 启用设备上识别
   - 添加自定义词汇表（如果需要）

3. **错误处理**：
   - 网络中断恢复
   - 识别失败重试
   - 权限检查

### 权限配置

**Mac 端 `Info.plist`：**
```xml
<key>NSMicrophoneUsageDescription</key>
<string>VoiceMind 需要麦克风权限进行语音识别</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>VoiceMind 需要语音识别权限将语音转换为文字</string>
```

### 性能指标

**预期性能：**
- 延迟：< 500ms（本地网络）
- 准确率：> 95%（中文普通话）
- CPU 使用：< 20%（Apple Silicon）
- 内存使用：< 100MB

### 备选方案：Whisper.cpp

如果 macOS Speech 不满足需求，可以使用 Whisper：

**集成步骤：**
1. 添加 whisper.cpp 作为子模块
2. 下载模型文件（推荐 base 或 small）
3. 创建 Swift 桥接
4. 实现音频转录

**示例代码：**
```swift
// 使用 whisper.cpp
import WhisperKit // 或自己封装

class WhisperRecognizer {
    func transcribe(audioFile: URL) async -> String {
        // 实现 Whisper 转录
    }
}
```

## 测试计划

### 单元测试
- [ ] macOS Speech 可用性测试
- [ ] 音频格式转换测试
- [ ] 网络传输测试
- [ ] 识别准确率测试

### 集成测试
- [ ] iOS -> Mac 完整流程测试
- [ ] 多语言识别测试
- [ ] 长时间运行稳定性测试
- [ ] 网络中断恢复测试

### 性能测试
- [ ] 延迟测试
- [ ] CPU/内存使用测试
- [ ] 并发识别测试

## 实施时间表

- **第 1 天**：验证 macOS Speech 可用性 ✅
- **第 2 天**：实现 iOS 音频流传输
- **第 3 天**：实现 Mac 端接收和识别
- **第 4 天**：集成测试和优化
- **第 5 天**：文档和发布

## 风险和缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| macOS Speech 不支持离线 | 中 | 降级到在线识别或使用 Whisper |
| 音频传输延迟高 | 高 | 优化缓冲区大小，使用 UDP（可选）|
| 识别准确率低 | 高 | 调整音频参数，添加自定义词汇 |
| 权限被拒绝 | 中 | 提供清晰的权限说明和引导 |

## 结论

**推荐使用 macOS Speech 框架**，原因：
1. ✅ 系统原生，集成简单
2. ✅ 支持离线识别（macOS 13+）
3. ✅ 准确率高，性能好
4. ✅ 零成本，无需额外模型

**下一步行动：**
1. 运行测试程序验证 Speech 框架可用性
2. 如果可用，继续实现音频流传输
3. 如果不可用，评估 Whisper 方案
