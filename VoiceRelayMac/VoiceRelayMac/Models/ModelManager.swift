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

    /// 正在下载的模型 ID 集合
    private var downloadingModels: Set<String> = []

    /// 活跃下载器，防止被提前释放
    private var activeDownloaders: [UUID: ModelDownloader] = [:]

    /// 初始化错误
    private var initializationError: Error?

    /// 是否正确初始化
    var isInitialized: Bool { initializationError == nil }

    /// 串行队列保护并发访问
    private let queue = DispatchQueue(label: "com.voicerelay.modelmanager", qos: .userInitiated)
    private let queueKey = DispatchSpecificKey<Void>()

    private init() {
        queue.setSpecific(key: queueKey, value: ())
        // 获取 Application Support 目录
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            initializationError = ModelError.storageError
            modelsDirectory = URL(fileURLWithPath: "/tmp/VoiceRelayMac/Models")
            registryFile = modelsDirectory.appendingPathComponent("models-registry.json")
            print("❌ 无法访问 Application Support 目录，使用临时目录")
            loadRegistry()
            return
        }

        // 创建模型存储目录
        modelsDirectory = appSupport
            .appendingPathComponent("VoiceRelayMac")
            .appendingPathComponent("Models")

        registryFile = modelsDirectory.appendingPathComponent("models-registry.json")

        // 确保目录存在
        do {
            try FileManager.default.createDirectory(
                at: modelsDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            initializationError = error
            print("❌ 创建模型目录失败: \(error.localizedDescription)")
            loadRegistry()
            return
        }

        // 加载模型注册表
        loadRegistry()

        print("📁 模型存储目录: \(modelsDirectory.path)")
    }

    @discardableResult
    private func syncOnQueue<T>(_ work: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            return try work()
        }
        return try queue.sync(execute: work)
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
            // 保存新的注册表以修复损坏的文件
            saveRegistry()
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

    // MARK: - Query Methods

    /// 获取所有可用模型
    func availableModels() -> [ModelInfo] {
        guard isInitialized else {
            print("⚠️ ModelManager 未正确初始化")
            return []
        }
        return syncOnQueue {
            Array(models.values).sorted { $0.name < $1.name }
        }
    }

    /// 获取已下载的模型
    func downloadedModels() -> [ModelInfo] {
        guard isInitialized else {
            print("⚠️ ModelManager 未正确初始化")
            return []
        }
        return syncOnQueue {
            models.values.filter { $0.isDownloaded }
        }
    }

    /// 检查模型是否已下载
    /// - Parameter engineType: 引擎类型
    /// - Returns: 是否已下载
    func isModelDownloaded(engineType: String) -> Bool {
        guard isInitialized else {
            print("⚠️ ModelManager 未正确初始化")
            return false
        }
        return syncOnQueue {
            models.values.first { $0.engineType == engineType }?.isDownloaded ?? false
        }
    }

    /// 获取模型路径
    /// - Parameter engineType: 引擎类型
    /// - Returns: 模型目录路径
    func getModelPath(engineType: String) -> URL? {
        guard isInitialized else {
            print("⚠️ ModelManager 未正确初始化")
            return nil
        }
        return syncOnQueue {
            // 优先使用默认模型
            if let defaultModel = getDefaultModel(engineType: engineType),
               defaultModel.isDownloaded,
               let localPath = defaultModel.localPath {
                return localPath
            }
            
            // 如果没有默认模型或默认模型未下载，使用第一个已下载的模型
            guard let model = models.values.first(where: { $0.engineType == engineType && $0.isDownloaded }),
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

    // MARK: - Model Selection

    /// 设置默认模型
    /// - Parameters:
    ///   - engineType: 引擎类型
    ///   - modelId: 模型ID
    func setDefaultModel(engineType: String, modelId: String) {
        guard isInitialized else {
            print("⚠️ ModelManager 未正确初始化")
            return
        }

        syncOnQueue {
            UserDefaults.standard.set(modelId, forKey: "defaultModel.\(engineType)")
            print("✅ 设置默认模型: \(modelId) 用于引擎: \(engineType)")
        }
    }

    /// 获取默认模型
    /// - Parameter engineType: 引擎类型
    /// - Returns: 默认模型信息
    func getDefaultModel(engineType: String) -> ModelInfo? {
        guard isInitialized else {
            print("⚠️ ModelManager 未正确初始化")
            return nil
        }

        return syncOnQueue {
            let defaultModelId = UserDefaults.standard.string(forKey: "defaultModel.\(engineType)")
            return defaultModelId.flatMap { models[$0] }
        }
    }

    /// 获取引擎的可用模型
    /// - Parameter engineType: 引擎类型
    /// - Returns: 模型列表
    func modelsForEngine(_ engineType: String) -> [ModelInfo] {
        guard isInitialized else {
            print("⚠️ ModelManager 未正确初始化")
            return []
        }

        return syncOnQueue {
            models.values.filter { $0.engineType == engineType }
        }
    }

    // MARK: - Download Methods

    /// 下载模型
    /// - Parameters:
    ///   - modelInfo: 模型信息
    ///   - progress: 进度回调（0.0 - 1.0）
    func downloadModel(
        _ modelInfo: ModelInfo,
        progress: @escaping (Double) -> Void
    ) async throws {
        guard isInitialized else {
            print("⚠️ ModelManager 未正确初始化")
            throw ModelError.storageError
        }

        // 检查是否已在下载
        try syncOnQueue {
            if downloadingModels.contains(modelInfo.id) {
                throw ModelError.downloadFailed("模型正在下载中")
            }
            downloadingModels.insert(modelInfo.id)
        }

        // 确保下载完成后清理状态
        defer {
            syncOnQueue {
                downloadingModels.remove(modelInfo.id)
            }
        }

        print("📦 开始下载模型: \(modelInfo.name)")

        // 创建模型目录
        let modelDir = modelsDirectory.appendingPathComponent(modelInfo.id)

        do {
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
            syncOnQueue {
                models[modelInfo.id] = updatedModel
                saveRegistry()
            }

            print("✅ 模型下载完成: \(modelInfo.name)")
        } catch {
            // 清理部分下载的文件
            print("❌ 下载失败，清理部分文件: \(error.localizedDescription)")
            try? FileManager.default.removeItem(at: modelDir)
            throw error
        }
    }

    /// 下载单个文件
    private func downloadFile(
        from url: URL,
        to destinationURL: URL,
        fileProgress: @escaping (Double) -> Void
    ) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let downloader = ModelDownloader()
            let downloadId = UUID()
            syncOnQueue {
                activeDownloaders[downloadId] = downloader
            }

            downloader.downloadFile(
                from: url,
                to: destinationURL,
                progress: fileProgress
            ) { [weak self] result in
                guard let self else { return }
                self.syncOnQueue {
                    self.activeDownloaders.removeValue(forKey: downloadId)
                }

                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Delete Methods

    /// 删除模型
    /// - Parameter modelInfo: 模型信息
    func deleteModel(_ modelInfo: ModelInfo) throws {
        guard isInitialized else {
            print("⚠️ ModelManager 未正确初始化")
            throw ModelError.storageError
        }

        try syncOnQueue {
            guard let localPath = modelInfo.localPath else {
                throw ModelError.modelNotFound
            }

            print("🗑️ 删除模型: \(modelInfo.name)")

            // 删除模型目录
            try FileManager.default.removeItem(at: localPath)

            // 更新注册表
            var updatedModel = modelInfo
            updatedModel.localPath = nil
            models[modelInfo.id] = updatedModel
            saveRegistry()

            print("✅ 模型已删除: \(modelInfo.name)")
        }
    }

    /// 标记模型损坏并清理本地文件
    /// - Parameter engineType: 引擎类型
    func invalidateDownloadedModel(engineType: String) {
        guard isInitialized else {
            print("⚠️ ModelManager 未正确初始化")
            return
        }

        syncOnQueue {
            guard let model = models.values.first(where: {
                $0.engineType == engineType && $0.localPath != nil
            }) else {
                return
            }

            if let localPath = model.localPath {
                do {
                    try FileManager.default.removeItem(at: localPath)
                    print("🧹 已清理损坏模型目录: \(localPath.path)")
                } catch {
                    print("⚠️ 清理模型目录失败: \(error.localizedDescription)")
                }
            }

            var updatedModel = model
            updatedModel.localPath = nil
            models[model.id] = updatedModel

            let defaultKey = "defaultModel.\(engineType)"
            if UserDefaults.standard.string(forKey: defaultKey) == model.id {
                UserDefaults.standard.removeObject(forKey: defaultKey)
            }

            saveRegistry()
        }
    }
}
