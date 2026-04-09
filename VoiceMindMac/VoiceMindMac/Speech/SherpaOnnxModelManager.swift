import Foundation
import Combine

/// 模型下载/安装状态
enum ModelState: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case extracting
    case installed
    case failed(String)
}

/// Sherpa-ONNX 模型下载与安装管理器
@MainActor
class SherpaOnnxModelManager: ObservableObject {
    static let shared = SherpaOnnxModelManager()

    /// 每个模型 ID 对应的状态
    @Published var modelStates: [String: ModelState] = [:]

    /// 当前选中的模型 ID（已安装）
    @Published var selectedModelId: String? {
        didSet {
            UserDefaults.standard.selectedSherpaModel = selectedModelId
        }
    }

    /// 引擎单例，模型选择后由此引擎执行识别
    let engine = SherpaOnnxEngine()

    private var downloadTask: URLSessionDownloadTask?
    private var cancellables = Set<AnyCancellable>()

    init() {
        // 初始化每个模型的状态
        for model in SherpaOnnxModelDefinition.catalog {
            let state = isModelInstalled(model) ? ModelState.installed : .notDownloaded
            modelStates[model.id] = state
        }

        // 恢复上次选择的模型
        let saved = UserDefaults.standard.selectedSherpaModel
        if let saved, modelStates[saved] == .installed {
            selectedModelId = saved
        }

        // 如果引擎已配置好模型，标记第一个匹配的为 installed
        if engine.isAvailable {
            markMatchingModelAsInstalled()
        }
    }

    // MARK: - Public

    /// 下载并安装模型
    func download(model: SherpaOnnxModelDefinition) {
        if case .downloading = modelStates[model.id] { return }

        modelStates[model.id] = .downloading(progress: 0)

        let configDir = modelConfigDirectory()
        let archiveName = model.modelName + ".tar.bz2"
        let archiveURL = configDir.appendingPathComponent(archiveName)
        let remoteURL = URL(string: model.downloadURL)!

        // 清理旧文件
        try? FileManager.default.removeItem(at: archiveURL)
        let modelDir = configDir.appendingPathComponent(model.modelName)
        try? FileManager.default.removeItem(at: modelDir)

        let task = URLSession.shared.downloadTask(with: remoteURL) { [weak self] tempURL, response, error in
            guard let self else { return }

            if let error {
                Task { @MainActor in
                    self.modelStates[model.id] = .failed(error.localizedDescription)
                }
                return
            }

            guard let tempURL else {
                Task { @MainActor in
                    self.modelStates[model.id] = .failed("下载文件为空")
                }
                return
            }

            do {
                // 移动到目标路径
                try FileManager.default.moveItem(at: tempURL, to: archiveURL)

                Task { @MainActor in
                    self.extractAndConfigure(model: model, archiveURL: archiveURL, configDir: configDir)
                }
            } catch {
                Task { @MainActor in
                    self.modelStates[model.id] = .failed("保存下载文件失败: \(error.localizedDescription)")
                }
            }
        }

        // 监听进度
        let observation = task.progress.publisher(for: \.fractionCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                guard let self else { return }
                if case .downloading = self.modelStates[model.id] {
                    self.modelStates[model.id] = .downloading(progress: progress)
                }
            }
        cancellables.insert(observation)

        downloadTask = task
        task.resume()
    }

    /// 删除已安装的模型
    func deleteModel(model: SherpaOnnxModelDefinition) {
        let configDir = modelConfigDirectory()
        let modelDir = configDir.appendingPathComponent(model.modelName)
        let archiveURL = configDir.appendingPathComponent(model.modelName + ".tar.bz2")

        try? FileManager.default.removeItem(at: modelDir)
        try? FileManager.default.removeItem(at: archiveURL)

        modelStates[model.id] = .notDownloaded

        if selectedModelId == model.id {
            selectedModelId = nil
        }

        // 刷新引擎
        engine.reloadModelConfiguration()
    }

    /// 选中模型并激活引擎
    func selectModel(_ modelId: String) {
        guard modelStates[modelId] == .installed else { return }
        selectedModelId = modelId

        // 重新加载模型配置
        engine.reloadModelConfiguration()

        // 如果引擎可用，切换到 sherpa-onnx
        if engine.isAvailable {
            do {
                try SpeechRecognitionManager.shared.selectEngine(identifier: "sherpa-onnx")
            } catch {
                print("⚠️ 选择 Sherpa-ONNX 引擎失败: \(error)")
            }
        }
    }

    /// 取消下载
    func cancelDownload(modelId: String) {
        downloadTask?.cancel()
        downloadTask = nil
        modelStates[modelId] = .notDownloaded
    }

    // MARK: - Private

    private func extractAndConfigure(model: SherpaOnnxModelDefinition, archiveURL: URL, configDir: URL) {
        modelStates[model.id] = .extracting

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            do {
                // 解压 tar.bz2
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
                process.arguments = ["xjf", archiveURL.path, "-C", configDir.path]
                try process.run()
                process.waitUntilExit()

                guard process.terminationStatus == 0 else {
                    throw NSError(domain: "SherpaOnnxModelManager", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "解压失败 (exit code \(process.terminationStatus))"])
                }

                // 删除压缩包
                try? FileManager.default.removeItem(at: archiveURL)

                // 清理非 int8 的 onnx 文件（节省空间）
                let modelDir = configDir.appendingPathComponent(model.modelName)
                Self.cleanupLargeOnnxFiles(in: modelDir)

                Task { @MainActor in
                    // 写 model.config
                    self.writeModelConfig(for: model, in: configDir)
                    self.modelStates[model.id] = .installed
                    self.engine.reloadModelConfiguration()
                }
            } catch {
                Task { @MainActor in
                    self.modelStates[model.id] = .failed(error.localizedDescription)
                }
            }
        }
    }

    /// 删除非 int8 的 .onnx 文件以节省磁盘空间
    nonisolated private static func cleanupLargeOnnxFiles(in directory: URL) {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
        ) else { return }

        for file in contents {
            let name = file.lastPathComponent
            if name.hasSuffix(".onnx") && !name.contains(".int8.onnx") {
                // 删除非 int8 版本（它们通常大 3-4 倍）
                try? FileManager.default.removeItem(at: file)
                print("🗑️ 已删除大文件: \(name)")
            }
        }
    }

    /// 写入 model.config 文件
    private func writeModelConfig(for model: SherpaOnnxModelDefinition, in configDir: URL) {
        let modelDir = configDir.appendingPathComponent(model.modelName)

        // 使用 resolveModel 找到实际文件
        guard let runtimeModel = SherpaOnnxRuntimeModelResolver.resolveModel(in: modelDir.path) else {
            print("⚠️ 解压后未找到有效模型文件")
            return
        }

        let encoderPath: String
        let decoderPath: String
        let tokensPath: String

        switch runtimeModel {
        case .streamingParaformer(let enc, let dec, let tok):
            encoderPath = enc
            decoderPath = dec
            tokensPath = tok
        case .streamingTransducer(let enc, let dec, _, let tok):
            encoderPath = enc
            decoderPath = dec
            tokensPath = tok
        }

        let config = ModelConfigJSON(
            encoderPath: encoderPath,
            decoderPath: decoderPath,
            tokensPath: tokensPath,
            language: model.languages.first ?? "zh-CN"
        )

        let configFile = configDir.appendingPathComponent("model.config")
        if let data = try? JSONEncoder().encode(config) {
            try? data.write(to: configFile)
            print("✅ model.config 已写入: \(configFile.path)")
        }
    }

    /// 检查模型是否已安装
    private func isModelInstalled(_ model: SherpaOnnxModelDefinition) -> Bool {
        let modelDir = modelConfigDirectory().appendingPathComponent(model.modelName)
        return FileManager.default.fileExists(atPath: modelDir.path)
            && SherpaOnnxRuntimeModelResolver.resolveModel(in: modelDir.path) != nil
    }

    /// 如果引擎已可用，标记匹配的模型为已安装
    private func markMatchingModelAsInstalled() {
        let configDir = modelConfigDirectory()
        for model in SherpaOnnxModelDefinition.catalog {
            if isModelInstalled(model) {
                modelStates[model.id] = .installed
            }
        }
    }

    /// 获取模型配置目录（sandbox container 内）
    private func modelConfigDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("VoiceMind/Models/SherpaOnnx")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    /// 用户选择的 sherpa 模型 ID
    var selectedSherpaModel: String? {
        get { string(forKey: "selectedSherpaModel") }
        set { set(newValue, forKey: "selectedSherpaModel") }
    }
}
