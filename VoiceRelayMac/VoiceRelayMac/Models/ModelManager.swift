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
            .appendingPathComponent("VoiceRelayMac")
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
}
