# sherpa-onnx 集成和 SenseVoice 引擎实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 集成 sherpa-onnx 库并实现 SenseVoice 语音识别引擎

**Architecture:** 使用 sherpa-onnx C++ 库通过 Objective-C 桥接到 Swift，实现 SenseVoiceEngine 作为 SpeechRecognitionEngine 协议的实现。支持流式音频处理和实时识别。

**Tech Stack:** Swift, Objective-C, C++ (sherpa-onnx), ONNX Runtime

---

## 前置条件

**已完成的组件：**
- ✅ SpeechRecognitionEngine 协议
- ✅ SpeechRecognitionManager
- ✅ AppleSpeechEngine
- ✅ SpeechErrors 定义
- ✅ ModelInfo 结构
- ✅ ModelManager
- ✅ ModelDownloader

**本计划实现：**
- sherpa-onnx 库集成
- Objective-C 桥接层
- SenseVoiceEngine 实现
- 音频格式转换

---

## 文件结构规划

### 新增文件

```
VoiceMindMac/
├── Frameworks/
│   └── sherpa-onnx.xcframework/          # sherpa-onnx 预编译库
│       ├── macos-arm64/
│       └── macos-x86_64/
├── VoiceMindMac/
│   ├── Speech/
│   │   ├── SherpaOnnx/
│   │   │   ├── SherpaOnnxBridge.h        # C 桥接头文件
│   │   │   ├── SherpaOnnxBridge.mm       # C++ 桥接实现
│   │   │   └── SherpaOnnxWrapper.swift   # Swift 封装
│   │   └── Engines/
│   │       └── SenseVoiceEngine.swift    # SenseVoice 引擎实现
│   └── VoiceMindMac-Bridging-Header.h   # Objective-C 桥接头文件
```

### 修改文件

```
VoiceMindMac/VoiceMindMac.xcodeproj/project.pbxproj  # 添加 xcframework 和桥接头文件
VoiceMindMac/VoiceMindMac/VoiceMindMacApp.swift     # 注册 SenseVoice 引擎
```

---

## Chunk 1: sherpa-onnx 库集成

### Task 1: 下载和集成 sherpa-onnx xcframework

**Files:**
- Create: `VoiceMindMac/Frameworks/sherpa-onnx.xcframework/`
- Modify: `VoiceMindMac/VoiceMindMac.xcodeproj/project.pbxproj`

**目标**: 下载 sherpa-onnx 预编译库并集成到 Xcode 项目

- [ ] **Step 1: 创建 Frameworks 目录**

```bash
mkdir -p VoiceMindMac/Frameworks
```

- [ ] **Step 2: 下载 sherpa-onnx xcframework**

根据 sherpa-onnx 文档，需要下载预编译的 macOS xcframework。

**注意**: 由于 sherpa-onnx 的 macOS xcframework 需要从官方源下载或自行编译，这一步需要手动完成。

参考链接：
- https://k2-fsa.github.io/sherpa/onnx/ios/build-sherpa-onnx-swift.html
- https://github.com/k2-fsa/sherpa-onnx/releases

下载后将 `sherpa-onnx.xcframework` 放置到 `VoiceMindMac/Frameworks/` 目录。

- [ ] **Step 3: 在 Xcode 中添加 xcframework**

打开 Xcode 项目：
1. 选择 VoiceMindMac target
2. 进入 "General" 标签
3. 在 "Frameworks, Libraries, and Embedded Content" 部分
4. 点击 "+" 按钮
5. 选择 "Add Other..." → "Add Files..."
6. 选择 `VoiceMindMac/Frameworks/sherpa-onnx.xcframework`
7. 确保 "Embed & Sign" 选项被选中

- [ ] **Step 4: 验证 xcframework 已添加**

```bash
xcodebuild -workspace VoiceMind.xcworkspace \
    -scheme VoiceMindMac \
    -configuration Debug \
    -showBuildSettings | grep FRAMEWORK_SEARCH_PATHS
```

Expected: 输出包含 Frameworks 目录路径

- [ ] **Step 5: 提交**

```bash
git add VoiceMindMac/Frameworks/
git add VoiceMindMac/VoiceMindMac.xcodeproj/project.pbxproj
git commit -m "feat: add sherpa-onnx xcframework

Integrate sherpa-onnx precompiled library for macOS.
Support both arm64 and x86_64 architectures.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Chunk 2: Objective-C 桥接层

### Task 2: 创建 Objective-C 桥接头文件

**Files:**
- Create: `VoiceMindMac/VoiceMindMac/Speech/SherpaOnnx/SherpaOnnxBridge.h`

**目标**: 定义 Objective-C 桥接接口

- [ ] **Step 1: 创建 SherpaOnnx 目录**

```bash
mkdir -p VoiceMindMac/VoiceMindMac/Speech/SherpaOnnx
```

- [ ] **Step 2: 创建 SherpaOnnxBridge.h**

```objc
//
//  SherpaOnnxBridge.h
//  VoiceMindMac
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// sherpa-onnx 识别器的 Objective-C 桥接
@interface SherpaOnnxRecognizer : NSObject

/// 初始化识别器
/// @param modelPath 模型文件路径 (model.onnx)
/// @param tokensPath 词表文件路径 (tokens.txt)
/// @param sampleRate 采样率（通常为 16000）
- (nullable instancetype)initWithModelPath:(NSString *)modelPath
                                tokensPath:(NSString *)tokensPath
                                sampleRate:(int)sampleRate;

/// 接受音频波形数据
/// @param samples Float32 音频样本数组
/// @param count 样本数量
- (void)acceptWaveform:(const float *)samples count:(int)count;

/// 获取识别文本
/// @return 识别的文本结果
- (NSString *)getText;

/// 检查是否准备好获取结果
/// @return YES 如果有结果可用
- (BOOL)isReady;

/// 重置识别器状态
- (void)reset;

/// 释放资源
- (void)releaseResources;

@end

NS_ASSUME_NONNULL_END
```

- [ ] **Step 3: 在 Xcode 中添加文件到项目**

- [ ] **Step 4: 提交**

```bash
git add VoiceMindMac/VoiceMindMac/Speech/SherpaOnnx/SherpaOnnxBridge.h
git commit -m "feat: add SherpaOnnxBridge header file

Define Objective-C bridge interface for sherpa-onnx C++ library.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 3: 实现 Objective-C 桥接

**Files:**
- Create: `VoiceMindMac/VoiceMindMac/Speech/SherpaOnnx/SherpaOnnxBridge.mm`

**目标**: 实现 C++ 到 Objective-C 的桥接

- [ ] **Step 1: 创建 SherpaOnnxBridge.mm**

```objc
//
//  SherpaOnnxBridge.mm
//  VoiceMindMac
//

#import "SherpaOnnxBridge.h"
#import <sherpa-onnx/c-api/c-api.h>

@implementation SherpaOnnxRecognizer {
    SherpaOnnxOnlineRecognizer *_recognizer;
    SherpaOnnxOnlineStream *_stream;
}

- (nullable instancetype)initWithModelPath:(NSString *)modelPath
                                tokensPath:(NSString *)tokensPath
                                sampleRate:(int)sampleRate {
    self = [super init];
    if (self) {
        // 配置识别器参数
        SherpaOnnxOnlineRecognizerConfig config;
        memset(&config, 0, sizeof(config));

        // 设置模型路径
        config.model_config.sense_voice.model = [modelPath UTF8String];
        config.model_config.tokens = [tokensPath UTF8String];
        config.model_config.num_threads = 2;
        config.model_config.provider = "cpu";
        config.model_config.debug = 0;

        // 设置特征提取参数
        config.feat_config.sample_rate = sampleRate;
        config.feat_config.feature_dim = 80;

        // 创建识别器
        _recognizer = SherpaOnnxCreateOnlineRecognizer(&config);
        if (_recognizer == NULL) {
            NSLog(@"❌ Failed to create sherpa-onnx recognizer");
            return nil;
        }

        // 创建音频流
        _stream = SherpaOnnxCreateOnlineStream(_recognizer);
        if (_stream == NULL) {
            NSLog(@"❌ Failed to create sherpa-onnx stream");
            SherpaOnnxDestroyOnlineRecognizer(_recognizer);
            return nil;
        }

        NSLog(@"✅ sherpa-onnx recognizer initialized");
    }
    return self;
}

- (void)acceptWaveform:(const float *)samples count:(int)count {
    if (_stream != NULL) {
        SherpaOnnxOnlineStreamAcceptWaveform(_stream, 16000, samples, count);
    }
}

- (NSString *)getText {
    if (_recognizer == NULL || _stream == NULL) {
        return @"";
    }

    const SherpaOnnxOnlineRecognizerResult *result =
        SherpaOnnxGetOnlineStreamResult(_recognizer, _stream);

    if (result == NULL) {
        return @"";
    }

    NSString *text = [NSString stringWithUTF8String:result->text];
    SherpaOnnxDestroyOnlineRecognizerResult(result);

    return text ? text : @"";
}

- (BOOL)isReady {
    if (_recognizer == NULL || _stream == NULL) {
        return NO;
    }

    return SherpaOnnxIsOnlineStreamReady(_recognizer, _stream) != 0;
}

- (void)reset {
    if (_stream != NULL) {
        SherpaOnnxOnlineStreamReset(_stream);
    }
}

- (void)releaseResources {
    if (_stream != NULL) {
        SherpaOnnxDestroyOnlineStream(_stream);
        _stream = NULL;
    }

    if (_recognizer != NULL) {
        SherpaOnnxDestroyOnlineRecognizer(_recognizer);
        _recognizer = NULL;
    }
}

- (void)dealloc {
    [self releaseResources];
}

@end
```

- [ ] **Step 2: 在 Xcode 中添加文件到项目**

确保文件类型为 "Objective-C++ Source"（.mm 扩展名）

- [ ] **Step 3: 创建或更新 Bridging Header**

创建 `VoiceMindMac/VoiceMindMac/VoiceMindMac-Bridging-Header.h`:

```objc
//
//  VoiceMindMac-Bridging-Header.h
//  VoiceMindMac
//

#import "Speech/SherpaOnnx/SherpaOnnxBridge.h"
```

在 Xcode 项目设置中：
1. 选择 VoiceMindMac target
2. Build Settings → Swift Compiler - General
3. 设置 "Objective-C Bridging Header" 为 `VoiceMindMac/VoiceMindMac-Bridging-Header.h`

- [ ] **Step 4: 验证编译**

```bash
xcodebuild -workspace VoiceMind.xcworkspace \
    -scheme VoiceMindMac \
    -configuration Debug \
    build
```

Expected: 编译成功

- [ ] **Step 5: 提交**

```bash
git add VoiceMindMac/VoiceMindMac/Speech/SherpaOnnx/SherpaOnnxBridge.mm
git add VoiceMindMac/VoiceMindMac/VoiceMindMac-Bridging-Header.h
git add VoiceMindMac/VoiceMindMac.xcodeproj/project.pbxproj
git commit -m "feat: implement SherpaOnnxBridge C++ to Objective-C bridge

Implement bridge layer between sherpa-onnx C++ API and Objective-C.
Add bridging header for Swift interoperability.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Chunk 3: SenseVoice 引擎实现

### Task 4: 创建 SenseVoiceEngine

**Files:**
- Create: `VoiceMindMac/VoiceMindMac/Speech/Engines/SenseVoiceEngine.swift`

**目标**: 实现 SenseVoice 语音识别引擎

- [ ] **Step 1: 创建 SenseVoiceEngine.swift**

```swift
import Foundation

/// SenseVoice 语音识别引擎
/// 使用 sherpa-onnx 运行 SenseVoiceSmall 模型
class SenseVoiceEngine: NSObject, SpeechRecognitionEngine {

    // MARK: - SpeechRecognitionEngine Protocol

    let identifier = "sensevoice"
    let displayName = "SenseVoice"
    let supportsStreaming = true

    var supportedLanguages: [String] {
        return ["zh-CN", "en-US", "ja-JP", "ko-KR", "yue-CN"]
    }

    var isAvailable: Bool {
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
    private let bufferSize: Int = 1600  // 100ms @ 16kHz

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

        // 创建识别器
        recognizer = SherpaOnnxRecognizer(
            modelPath: modelFile.path,
            tokensPath: tokensFile.path,
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

        print("✅ SenseVoice 识别已启动")
    }

    func processAudioData(_ data: Data) throws {
        guard let recognizer = recognizer else {
            throw SenseVoiceError.notInitialized
        }

        guard currentSessionId != nil else {
            return
        }

        // 将 Int16 PCM 转换为 Float32
        let samples = convertToFloat32(data)
        audioBuffer.append(contentsOf: samples)

        // 每累积一定量的音频就送入识别器
        if audioBuffer.count >= bufferSize {
            recognizer.acceptWaveform(audioBuffer, count: Int32(audioBuffer.count))
            audioBuffer.removeAll()

            // 检查是否有部分结果
            if recognizer.isReady() {
                let text = recognizer.getText()
                if !text.isEmpty {
                    print("📝 SenseVoice 部分结果: \(text)")
                    if let sessionId = currentSessionId {
                        delegate?.engine(self, didReceivePartialResult: text, sessionId: sessionId)
                    }
                }
            }
        }
    }

    func stopRecognition() throws {
        guard let recognizer = recognizer,
              let sessionId = currentSessionId,
              let language = currentLanguage else {
            return
        }

        print("🛑 SenseVoice 停止识别")

        // 处理剩余的音频
        if !audioBuffer.isEmpty {
            recognizer.acceptWaveform(audioBuffer, count: Int32(audioBuffer.count))
            audioBuffer.removeAll()
        }

        // 获取最终结果
        let finalText = recognizer.getText()

        if !finalText.isEmpty {
            print("📝 SenseVoice 最终结果: \(finalText)")
            delegate?.engine(self, didRecognizeText: finalText, sessionId: sessionId, language: language)
        } else {
            print("⚠️ SenseVoice 未识别到文本")
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
}
```

- [ ] **Step 2: 在 Xcode 中添加文件到项目**

- [ ] **Step 3: 验证编译**

```bash
xcodebuild -workspace VoiceMind.xcworkspace \
    -scheme VoiceMindMac \
    -configuration Debug \
    build
```

Expected: 编译成功

- [ ] **Step 4: 提交**

```bash
git add VoiceMindMac/VoiceMindMac/Speech/Engines/SenseVoiceEngine.swift
git commit -m "feat: implement SenseVoiceEngine

Implement SenseVoice speech recognition engine using sherpa-onnx.
Support streaming audio processing and real-time recognition.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 5: 集成 SenseVoice 到应用启动

**Files:**
- Modify: `VoiceMindMac/VoiceMindMac/VoiceMindMacApp.swift`

**目标**: 在应用启动时注册 SenseVoice 引擎

- [ ] **Step 1: 读取 VoiceMindMacApp.swift**

- [ ] **Step 2: 修改 initializeSpeechEngine() 方法**

在现有的 Apple Speech 引擎注册后添加 SenseVoice 引擎注册：

```swift
private func initializeSpeechEngine() async {
    // 初始化模型管理器
    let modelManager = ModelManager.shared
    if !modelManager.isInitialized {
        print("⚠️ 模型管理器初始化失败，模型下载功能将不可用")
    } else {
        print("✅ 模型管理器已初始化")
    }

    // 注册 Apple Speech 引擎
    let appleSpeech = AppleSpeechEngine()
    do {
        try await appleSpeech.initialize()
        SpeechRecognitionManager.shared.registerEngine(appleSpeech)
        print("✅ Apple Speech 引擎已注册")
    } catch {
        print("❌ Apple Speech 引擎初始化失败: \(error.localizedDescription)")
    }

    // 如果 SenseVoice 模型已下载，注册它
    if modelManager.isModelDownloaded(engineType: "sensevoice") {
        print("📦 检测到 SenseVoice 模型，正在初始化...")
        let senseVoice = SenseVoiceEngine()
        do {
            try await senseVoice.initialize()
            SpeechRecognitionManager.shared.registerEngine(senseVoice)
            print("✅ SenseVoice 引擎已注册")
        } catch {
            print("❌ SenseVoice 引擎初始化失败: \(error.localizedDescription)")
        }
    } else {
        print("ℹ️ SenseVoice 模型未下载，跳过引擎注册")
    }

    // 恢复上次选择的引擎
    let savedEngine = UserDefaults.standard.selectedSpeechEngine
    do {
        try SpeechRecognitionManager.shared.selectEngine(identifier: savedEngine)
        print("✅ 已选择引擎: \(savedEngine)")
    } catch {
        print("⚠️ 无法选择引擎 \(savedEngine)，使用默认引擎")
        try? SpeechRecognitionManager.shared.selectEngine(identifier: "apple-speech")
    }

    // 设置 ConnectionManager 的语音识别代理
    connectionManager.setupSpeechRecognition()
}
```

- [ ] **Step 3: 验证编译**

```bash
xcodebuild -workspace VoiceMind.xcworkspace \
    -scheme VoiceMindMac \
    -configuration Debug \
    build
```

Expected: 编译成功

- [ ] **Step 4: 提交**

```bash
git add VoiceMindMac/VoiceMindMac/VoiceMindMacApp.swift
git commit -m "feat: register SenseVoice engine at app startup

Automatically register SenseVoice engine if model is downloaded.
Restore previously selected engine from UserDefaults.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## 验证

运行应用后应该看到：

**如果 SenseVoice 模型未下载：**
```
✅ 模型管理器已初始化
✅ Apple Speech 引擎已注册
ℹ️ SenseVoice 模型未下载，跳过引擎注册
✅ 已选择引擎: apple-speech
```

**如果 SenseVoice 模型已下载：**
```
✅ 模型管理器已初始化
✅ Apple Speech 引擎已注册
📦 检测到 SenseVoice 模型，正在初始化...
🎤 初始化 SenseVoice 引擎
📁 模型路径: ~/Library/Application Support/VoiceMindMac/Models/sensevoice-small/model.onnx
📁 词表路径: ~/Library/Application Support/VoiceMindMac/Models/sensevoice-small/tokens.txt
✅ SenseVoice 引擎初始化成功
✅ SenseVoice 引擎已注册
✅ 已选择引擎: sensevoice
```

可以通过以下方式测试：
1. 运行应用，检查启动日志
2. 使用 iPhone 连接并发送音频
3. 验证语音识别功能正常工作

## 注意事项

### sherpa-onnx 库获取

sherpa-onnx 的 macOS xcframework 需要从以下途径获取：

1. **从 GitHub Releases 下载**：
   - https://github.com/k2-fsa/sherpa-onnx/releases
   - 查找 macOS 相关的预编译包

2. **自行编译**：
   - 参考：https://k2-fsa.github.io/sherpa/onnx/ios/build-sherpa-onnx-swift.html
   - 需要 CMake 和 Xcode 命令行工具

3. **使用 Swift Package Manager**（如果支持）：
   - 检查是否有 SPM 支持

### 模型文件

SenseVoice Small 模型需要从 HuggingFace 下载：
- https://huggingface.co/FunAudioLLM/SenseVoiceSmall

需要的文件：
- `model.onnx` - 主模型文件
- `tokens.txt` - 词表文件
- `config.json` - 配置文件（可选）

### 性能考虑

- SenseVoice Small 模型约 85MB
- 运行时内存约 200-300MB
- CPU 使用率约 10-20%（Apple Silicon）
- 实时识别延迟约 100-200ms

### 兼容性

- macOS 13.0+
- 支持 arm64 和 x86_64 架构
- 需要 Xcode 14.0+

## 下一步

完成本计划后，可以：
1. 实现设置界面，让用户选择识别引擎
2. 实现模型管理界面，让用户下载和管理模型
3. 添加更多语音识别引擎（Whisper、Paraformer 等）
4. 优化性能和识别准确率
