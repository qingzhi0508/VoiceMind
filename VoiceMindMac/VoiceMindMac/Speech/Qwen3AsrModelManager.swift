import Foundation
import Combine

/// Qwen3-ASR 模型下载与安装管理器
/// 复用 SherpaOnnxModelManager 的模式
@MainActor
class Qwen3AsrModelManager: ObservableObject {
    static let shared = Qwen3AsrModelManager()

    @Published var modelStates: [String: ModelState] = [:]
    @Published var selectedModelId: String? {
        didSet {
            if let selectedModelId {
                let model = Qwen3AsrModelDefinition.catalog.first { $0.id == selectedModelId }
                UserDefaults.standard.selectedQwen3AsrModelSize = model?.size ?? "0.6b"
            }
        }
    }

    let engine = Qwen3AsrEngine()

    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var cancellables = Set<AnyCancellable>()

    init() {
        for model in Qwen3AsrModelDefinition.catalog {
            let state = isModelInstalled(model) ? ModelState.installed : .notDownloaded
            modelStates[model.id] = state
        }

        // 恢复上次选择的模型
        let savedSize = UserDefaults.standard.selectedQwen3AsrModelSize
        if let model = Qwen3AsrModelDefinition.catalog.first(where: { $0.size == savedSize }),
           modelStates[model.id] == .installed {
            selectedModelId = model.id
        }

        // 如果引擎已配置好，标记匹配的模型为 installed
        if engine.isAvailable {
            markMatchingModelAsInstalled()
        }
    }

    // MARK: - Public

    func download(model: Qwen3AsrModelDefinition) {
        if case .downloading = modelStates[model.id] { return }
        modelStates[model.id] = .downloading(progress: 0)

        let modelDir = engine.getModelDirectory(for: model.size)
        try? FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)

        Task {
            do {
                // 1. 从 HuggingFace API 获取文件列表
                let files = try await fetchModelFileList(modelId: model.huggingFaceModelId)
                let relevantFiles = filterRelevantFiles(files)

                if relevantFiles.isEmpty {
                    modelStates[model.id] = .failed("HuggingFace 未找到模型文件")
                    return
                }

                let totalFiles = relevantFiles.count

                // 2. 逐文件下载
                for (idx, filename) in relevantFiles.enumerated() {
                    let destPath = modelDir.appendingPathComponent(filename)

                    // 跳过已下载文件
                    if FileManager.default.fileExists(atPath: destPath.path) {
                        continue
                    }

                    // 创建子目录
                    if filename.contains("/") {
                        let subdir = destPath.deletingLastPathComponent()
                        try? FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
                    }

                    let fileURL = "https://huggingface.co/\(model.huggingFaceModelId)/resolve/main/\(filename)"
                    let overallProgress = Double(idx) / Double(totalFiles)
                    modelStates[model.id] = .downloading(progress: overallProgress)

                    try await downloadFile(url: fileURL, to: destPath)
                }

                // 3. 验证模型完整性
                if isModelInstalled(model) {
                    modelStates[model.id] = .installed
                    engine.reloadModelConfiguration()
                    print("✅ Qwen3-ASR model \(model.size) download completed")
                } else {
                    modelStates[model.id] = .failed("下载完成但模型文件不完整")
                }
            } catch {
                modelStates[model.id] = .failed(error.localizedDescription)
            }
        }
    }

    func deleteModel(model: Qwen3AsrModelDefinition) {
        let modelDir = engine.getModelDirectory(for: model.size)
        try? FileManager.default.removeItem(at: modelDir)
        modelStates[model.id] = .notDownloaded

        if selectedModelId == model.id {
            selectedModelId = nil
        }

        engine.reloadModelConfiguration()
    }

    func selectModel(_ modelId: String) {
        guard modelStates[modelId] == .installed else { return }
        selectedModelId = modelId

        engine.reloadModelConfiguration()

        if engine.isAvailable {
            do {
                try SpeechRecognitionManager.shared.selectEngine(identifier: "qwen3-asr")
            } catch {
                print("⚠️ 选择 Qwen3-ASR 引擎失败: \(error)")
            }
        }
    }

    func cancelDownload(modelId: String) {
        downloadTasks[modelId]?.cancel()
        downloadTasks.removeValue(forKey: modelId)
        modelStates[modelId] = .notDownloaded
    }

    // MARK: - Private

    private func isModelInstalled(_ model: Qwen3AsrModelDefinition) -> Bool {
        let modelDir = engine.getModelDirectory(for: model.size)
        let fm = FileManager.default
        guard fm.fileExists(atPath: modelDir.path) else { return false }

        for file in model.requiredFiles {
            guard fm.fileExists(atPath: modelDir.appendingPathComponent(file).path) else {
                return false
            }
        }

        // 检查 tokenizer
        let tokenizerDir = modelDir.appendingPathComponent("tokenizer")
        let tokenizerFile = modelDir.appendingPathComponent("tokenizer.json")
        return fm.fileExists(atPath: tokenizerDir.path) || fm.fileExists(atPath: tokenizerFile.path)
    }

    private func markMatchingModelAsInstalled() {
        for model in Qwen3AsrModelDefinition.catalog {
            if isModelInstalled(model) {
                modelStates[model.id] = .installed
            }
        }
    }

    private func fetchModelFileList(modelId: String) async throws -> [String] {
        let apiUrl = "https://huggingface.co/api/models/\(modelId)"
        guard let url = URL(string: apiUrl) else {
            throw NSError(domain: "Qwen3AsrModelManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let siblings = json["siblings"] as? [[String: Any]] else {
            throw NSError(domain: "Qwen3AsrModelManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse HuggingFace API response"])
        }

        return siblings.compactMap { $0["rfilename"] as? String }
    }

    private func filterRelevantFiles(_ files: [String]) -> [String] {
        files.filter { filename in
            filename.hasSuffix(".safetensors") ||
            filename.hasSuffix(".safetensors.index.json") ||
            filename == "tokenizer.json" ||
            filename == "tokenizer_config.json" ||
            filename == "config.json" ||
            filename == "generation_config.json" ||
            filename == "special_tokens_map.json" ||
            filename == "vocab.json" ||
            filename.hasSuffix(".model") ||
            filename.hasSuffix(".onnx") ||
            filename.hasPrefix("tokenizer/")
        }
    }

    private func downloadFile(url: String, to destPath: URL) async throws {
        guard let fileURL = URL(string: url) else { return }

        let (tempURL, response) = try await URLSession.shared.download(from: fileURL)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            try? FileManager.default.removeItem(at: tempURL)
            throw NSError(domain: "Qwen3AsrModelManager", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "下载失败: \(url)"])
        }

        // 创建父目录
        let parentDir = destPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        // 如果目标已存在，先删除
        try? FileManager.default.removeItem(at: destPath)

        try FileManager.default.moveItem(at: tempURL, to: destPath)
    }
}
