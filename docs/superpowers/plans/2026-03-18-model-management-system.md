# 模型管理系统实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现模型管理系统，支持从 HuggingFace 下载、存储和管理语音识别模型

**Architecture:** 基于文件系统的模型存储，使用 URLSession 进行下载，JSON 格式的元数据管理。ModelManager 单例负责所有模型操作，ModelInfo 结构体描述模型元数据。

**Tech Stack:** Swift, Foundation (URLSession, FileManager), Codable

---

## 文件结构规划

### 新增文件

```
VoiceMindMac/VoiceMindMac/
├── Models/
│   ├── ModelInfo.swift                  # 模型信息结构体
│   ├── ModelManager.swift               # 模型管理器（下载、存储、查询）
│   └── ModelDownloader.swift            # 模型下载器（处理 HTTP 下载）
└── Extensions/
    └── UserDefaults+Speech.swift        # 设置持久化扩展
```

### 模型存储位置

```
~/Library/Application Support/VoiceMindMac/Models/
├── sensevoice-small/
│   ├── model.onnx
│   ├── tokens.txt
│   ├── config.json
│   └── metadata.json
└── models-registry.json
```

---

## Chunk 1: 模型信息结构和存储管理

### Task 1: 创建 ModelInfo 结构体

**Files:**
- Create: `VoiceMindMac/VoiceMindMac/Models/ModelInfo.swift`

**目标**: 定义模型元数据结构

- [ ] **Step 1: 创建 Models 目录**

```bash
mkdir -p VoiceMindMac/VoiceMindMac/Models
```

- [ ] **Step 2: 创建 ModelInfo.swift**

```swift
import Foundation

/// 模型信息结构体
struct ModelInfo: Codable, Identifiable {
    /// 模型唯一标识符
    let id: String

    /// 显示名称
    let name: String

    /// 引擎类型（sensevoice, whisper 等）
    let engineType: String

    /// 版本号
    let version: String

    /// 支持的语言列表
    let languages: [String]

    /// 模型大小（字节）
    let size: Int64

    /// 下载 URL（基础路径）
    let downloadURL: URL

    /// 本地存储路径（已下载时）
    var localPath: URL?

    /// 是否已下载
    var isDownloaded: Bool {
        guard let path = localPath else { return false }
        return FileManager.default.fileExists(atPath: path.path)
    }

    /// 描述信息
    let description: String

    /// 需要下载的文件列表
    let files: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, engineType, version, languages, size
        case downloadURL, localPath, description, files
    }
}

/// 预定义的模型列表
extension ModelInfo {
    static let predefinedModels: [ModelInfo] = [
        ModelInfo(
            id: "sensevoice-small",
            name: "SenseVoice Small",
            engineType: "sensevoice",
            version: "1.0",
            languages: ["zh-CN", "en-US", "ja-JP", "ko-KR", "yue-CN"],
            size: 85_000_000, // 约 85MB
            downloadURL: URL(string: "https://huggingface.co/FunAudioLLM/SenseVoiceSmall/resolve/main/")!,
            localPath: nil,
            description: "多语言语音识别模型，支持50+语言",
            files: ["model.onnx", "tokens.txt", "config.json"]
        )
    ]
}
```

- [ ] **Step 3: 在 Xcode 中添加文件到项目**

打开 Xcode，右键点击 VoiceMindMac 组，选择 "Add Files to VoiceMindMac"，添加 Models 文件夹。

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
git add VoiceMindMac/VoiceMindMac/Models/ModelInfo.swift
git commit -m "feat: add ModelInfo structure for model metadata

Define model information structure with Codable support.
Include predefined model list for SenseVoice Small.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 2: 创建 ModelDownloader

**Files:**
- Create: `VoiceMindMac/VoiceMindMac/Models/ModelDownloader.swift`

**目标**: 实现模型文件下载功能

- [ ] **Step 1: 创建 ModelDownloader.swift**

```swift
import Foundation

/// 模型下载器
class ModelDownloader: NSObject {

    /// 下载进度回调
    typealias ProgressHandler = (Double) -> Void

    /// 下载完成回调
    typealias CompletionHandler = (Result<URL, Error>) -> Void

    private var downloadTask: URLSessionDownloadTask?
    private var progressHandler: ProgressHandler?
    private var completionHandler: CompletionHandler?

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5 minutes
        config.timeoutIntervalForResource = 3600 // 1 hour
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    /// 下载文件
    /// - Parameters:
    ///   - url: 下载 URL
    ///   - destinationURL: 目标文件路径
    ///   - progress: 进度回调
    ///   - completion: 完成回调
    func downloadFile(
        from url: URL,
        to destinationURL: URL,
        progress: @escaping ProgressHandler,
        completion: @escaping CompletionHandler
    ) {
        self.progressHandler = progress
        self.completionHandler = completion

        print("📥 开始下载: \(url.lastPathComponent)")
        print("   目标路径: \(destinationURL.path)")

        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
    }

    /// 取消下载
    func cancel() {
        downloadTask?.cancel()
        downloadTask = nil
        print("❌ 下载已取消")
    }
}

// MARK: - URLSessionDownloadDelegate

extension ModelDownloader: URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let destinationURL = downloadTask.originalRequest?.url else {
            completionHandler?(.failure(ModelError.downloadFailed("无法获取目标 URL")))
            return
        }

        do {
            // 移动文件到目标位置
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: location, to: destinationURL)

            print("✅ 下载完成: \(destinationURL.lastPathComponent)")
            completionHandler?(.success(destinationURL))
        } catch {
            print("❌ 移动文件失败: \(error.localizedDescription)")
            completionHandler?(.failure(error))
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.progressHandler?(progress)
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            print("❌ 下载失败: \(error.localizedDescription)")
            completionHandler?(.failure(error))
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
git add VoiceMindMac/VoiceMindMac/Models/ModelDownloader.swift
git commit -m "feat: add ModelDownloader for HTTP file downloads

Implement URLSession-based downloader with progress tracking.
Support cancellation and error handling.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 3: 创建 ModelManager

**Files:**
- Create: `VoiceMindMac/VoiceMindMac/Models/ModelManager.swift`

**目标**: 实现模型管理核心功能

- [ ] **Step 1: 创建 ModelManager.swift（第一部分：基础结构）**

```swift
import Foundation

/// 模型管理器
class ModelManager {
    static let shared = ModelManager()

    /// 模型存储根目录
    private let modelsDirectory: URL

    /// 模型注册表文件
    private let registryFile: URL

    /// 已注册的模型
    private var models: [String: ModelInfo] = [:]

    /// 串行队列保护并发访问
    private let queue = DispatchQueue(label: "com.voicerelay.modelmanager", qos: .userInitiated)

    private init() {
        // 获取 Application Support 目录
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        // 创建模型存储目录
        modelsDirectory = appSupport
            .appendingPathComponent("VoiceMindMac")
            .appendingPathComponent("Models")

        registryFile = modelsDirectory.appendingPathComponent("models-registry.json")

        // 确保目录存在
        try? FileManager.default.createDirectory(
            at: modelsDirectory,
            withIntermediateDirectories: true
        )

        // 加载模型注册表
        loadRegistry()

        print("📁 模型存储目录: \(modelsDirectory.path)")
    }

    // MARK: - Registry Management

    /// 加载模型注册表
    private func loadRegistry() {
        guard FileManager.default.fileExists(atPath: registryFile.path) else {
            // 首次运行，使用预定义模型列表
            models = Dictionary(
                uniqueKeysWithValues: ModelInfo.predefinedModels.map { ($0.id, $0) }
            )
            saveRegistry()
            return
        }

        do {
            let data = try Data(contentsOf: registryFile)
            let modelArray = try JSONDecoder().decode([ModelInfo].self, from: data)
            models = Dictionary(uniqueKeysWithValues: modelArray.map { ($0.id, $0) })
            print("✅ 加载模型注册表: \(models.count) 个模型")
        } catch {
            print("❌ 加载模型注册表失败: \(error.localizedDescription)")
            // 使用预定义列表作为后备
            models = Dictionary(
                uniqueKeysWithValues: ModelInfo.predefinedModels.map { ($0.id, $0) }
            )
        }
    }

    /// 保存模型注册表
    private func saveRegistry() {
        do {
            let modelArray = Array(models.values)
            let data = try JSONEncoder().encode(modelArray)
            try data.write(to: registryFile)
            print("💾 保存模型注册表")
        } catch {
            print("❌ 保存模型注册表失败: \(error.localizedDescription)")
        }
    }
}
```

- [ ] **Step 2: 添加查询方法**

在 ModelManager.swift 中添加：

```swift
    // MARK: - Query Methods

    /// 获取所有可用模型
    func availableModels() -> [ModelInfo] {
        return queue.sync {
            Array(models.values).sorted { $0.name < $1.name }
        }
    }

    /// 获取已下载的模型
    func downloadedModels() -> [ModelInfo] {
        return queue.sync {
            models.values.filter { $0.isDownloaded }
        }
    }

    /// 检查模型是否已下载
    /// - Parameter engineType: 引擎类型
    /// - Returns: 是否已下载
    func isModelDownloaded(engineType: String) -> Bool {
        return queue.sync {
            models.values.first { $0.engineType == engineType }?.isDownloaded ?? false
        }
    }

    /// 获取模型路径
    /// - Parameter engineType: 引擎类型
    /// - Returns: 模型目录路径
    func getModelPath(engineType: String) -> URL? {
        return queue.sync {
            guard let model = models.values.first(where: { $0.engineType == engineType }),
                  model.isDownloaded,
                  let localPath = model.localPath else {
                return nil
            }
            return localPath
        }
    }

    /// 获取模型存储根目录
    func modelStoragePath() -> URL {
        return modelsDirectory
    }
```

- [ ] **Step 3: 添加下载方法**

在 ModelManager.swift 中添加：

```swift
    // MARK: - Download Methods

    /// 下载模型
    /// - Parameters:
    ///   - modelInfo: 模型信息
    ///   - progress: 进度回调（0.0 - 1.0）
    func downloadModel(
        _ modelInfo: ModelInfo,
        progress: @escaping (Double) -> Void
    ) async throws {
        print("📦 开始下载模型: \(modelInfo.name)")

        // 创建模型目录
        let modelDir = modelsDirectory.appendingPathComponent(modelInfo.id)
        try FileManager.default.createDirectory(
            at: modelDir,
            withIntermediateDirectories: true
        )

        // 下载所有文件
        let totalFiles = modelInfo.files.count
        var completedFiles = 0

        for fileName in modelInfo.files {
            let fileURL = modelInfo.downloadURL.appendingPathComponent(fileName)
            let destinationURL = modelDir.appendingPathComponent(fileName)

            print("📥 下载文件: \(fileName)")

            try await downloadFile(
                from: fileURL,
                to: destinationURL,
                fileProgress: { fileProgress in
                    let overallProgress = (Double(completedFiles) + fileProgress) / Double(totalFiles)
                    progress(overallProgress)
                }
            )

            completedFiles += 1
            progress(Double(completedFiles) / Double(totalFiles))
        }

        // 保存元数据
        var updatedModel = modelInfo
        updatedModel.localPath = modelDir

        let metadataURL = modelDir.appendingPathComponent("metadata.json")
        let metadataData = try JSONEncoder().encode(updatedModel)
        try metadataData.write(to: metadataURL)

        // 更新注册表
        queue.sync {
            models[modelInfo.id] = updatedModel
            saveRegistry()
        }

        print("✅ 模型下载完成: \(modelInfo.name)")
    }

    /// 下载单个文件
    private func downloadFile(
        from url: URL,
        to destinationURL: URL,
        fileProgress: @escaping (Double) -> Void
    ) async throws {
        let (tempURL, response) = try await URLSession.shared.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ModelError.downloadFailed("HTTP 错误")
        }

        // 移动文件到目标位置
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
    }
```

- [ ] **Step 4: 添加删除方法**

在 ModelManager.swift 中添加：

```swift
    // MARK: - Delete Methods

    /// 删除模型
    /// - Parameter modelInfo: 模型信息
    func deleteModel(_ modelInfo: ModelInfo) throws {
        guard let localPath = modelInfo.localPath else {
            throw ModelError.modelNotFound
        }

        print("🗑️ 删除模型: \(modelInfo.name)")

        // 删除模型目录
        try FileManager.default.removeItem(at: localPath)

        // 更新注册表
        queue.sync {
            var updatedModel = modelInfo
            updatedModel.localPath = nil
            models[modelInfo.id] = updatedModel
            saveRegistry()
        }

        print("✅ 模型已删除: \(modelInfo.name)")
    }
```

- [ ] **Step 5: 在 Xcode 中添加文件到项目**

- [ ] **Step 6: 验证编译**

```bash
xcodebuild -workspace ../VoiceMind.xcworkspace \
    -scheme VoiceMindMac \
    -configuration Debug \
    build
```

Expected: 编译成功

- [ ] **Step 7: 提交**

```bash
git add VoiceMindMac/VoiceMindMac/Models/ModelManager.swift
git commit -m "feat: add ModelManager for model lifecycle management

Implement model registry, download, query, and deletion.
Support async downloads with progress tracking.
Store models in Application Support directory.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Chunk 2: 设置持久化和集成

### Task 4: 创建 UserDefaults 扩展

**Files:**
- Create: `VoiceMindMac/VoiceMindMac/Extensions/UserDefaults+Speech.swift`

**目标**: 实现语音识别设置的持久化

- [ ] **Step 1: 创建 Extensions 目录**

```bash
mkdir -p VoiceMindMac/VoiceMindMac/Extensions
```

- [ ] **Step 2: 创建 UserDefaults+Speech.swift**

```swift
import Foundation

extension UserDefaults {
    /// 选中的语音识别引擎
    var selectedSpeechEngine: String {
        get { string(forKey: "selectedEngine") ?? "apple-speech" }
        set { set(newValue, forKey: "selectedEngine") }
    }

    /// 是否自动下载模型
    var autoDownloadModels: Bool {
        get { bool(forKey: "autoDownloadModels") }
        set { set(newValue, forKey: "autoDownloadModels") }
    }

    /// 上次检查模型更新的时间
    var lastModelUpdateCheck: Date? {
        get { object(forKey: "lastModelUpdateCheck") as? Date }
        set { set(newValue, forKey: "lastModelUpdateCheck") }
    }
}
```

- [ ] **Step 3: 在 Xcode 中添加文件到项目**

- [ ] **Step 4: 验证编译**

```bash
xcodebuild -workspace ../VoiceMind.xcworkspace \
    -scheme VoiceMindMac \
    -configuration Debug \
    build
```

Expected: 编译成功

- [ ] **Step 5: 提交**

```bash
git add VoiceMindMac/VoiceMindMac/Extensions/UserDefaults+Speech.swift
git commit -m "feat: add UserDefaults extension for speech settings

Add persistent storage for selected engine and model preferences.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 5: 集成 ModelManager 到应用启动

**Files:**
- Modify: `VoiceMindMac/VoiceMindMac/VoiceMindMacApp.swift`

**目标**: 在应用启动时初始化 ModelManager

- [ ] **Step 1: 读取 VoiceMindMacApp.swift**

- [ ] **Step 2: 在 initializeSpeechEngine() 中添加 ModelManager 初始化**

在现有的 `initializeSpeechEngine()` 方法开始处添加：

```swift
private func initializeSpeechEngine() async {
    // 初始化模型管理器（确保目录创建）
    _ = ModelManager.shared
    print("✅ 模型管理器已初始化")

    // 现有的 AppleSpeechEngine 初始化代码...
    let appleSpeech = AppleSpeechEngine()
    // ...
}
```

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
git add VoiceMindMac/VoiceMindMac/VoiceMindMacApp.swift
git commit -m "feat: initialize ModelManager at app startup

Ensure model storage directory is created on first launch.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## 验证

运行应用后应该看到：
- 启动日志显示 "✅ 模型管理器已初始化"
- 启动日志显示 "📁 模型存储目录: ~/Library/Application Support/VoiceMindMac/Models"
- 启动日志显示 "✅ 加载模型注册表: 1 个模型"
- 模型目录已创建
- models-registry.json 文件已创建

可以通过以下命令验证：

```bash
ls -la ~/Library/Application\ Support/VoiceMindMac/Models/
cat ~/Library/Application\ Support/VoiceMindMac/Models/models-registry.json
```

## 注意事项

- 模型管理系统已完成，但 SenseVoice 引擎的实现需要 sherpa-onnx 库
- 当前可以使用 ModelManager 查询和管理模型元数据
- 实际的模型下载功能已实现，但需要 UI 界面来触发
- 下一步可以实现设置界面，让用户下载和管理模型
