import Foundation
import Combine

/// Qwen3-ASR 模型下载与安装管理器
/// 从 GitHub Releases 下载 tar.bz2 并解压
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

    private var downloadDelegates: [String: DownloadDelegate] = [:]
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

        Task {
            do {
                let modelDir = engine.getModelDirectory(for: model.size)
                try? FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)

                // 1. 下载 tar.bz2（带进度回调）
                guard let url = URL(string: model.downloadURL) else {
                    modelStates[model.id] = .failed("无效的下载 URL")
                    return
                }

                let tempURL = try await downloadWithProgress(url: url, modelId: model.id)

                modelStates[model.id] = .extracting

                // 2. 解压 tar.bz2 到临时目录
                let extractDir = modelDir.appendingPathComponent("_extract_tmp")
                try? FileManager.default.removeItem(at: extractDir)
                try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
                process.arguments = ["-xjf", tempURL.path, "-C", extractDir.path]
                try process.run()
                process.waitUntilExit()

                // 清理下载的 tar.bz2
                try? FileManager.default.removeItem(at: tempURL)

                guard process.terminationStatus == 0 else {
                    try? FileManager.default.removeItem(at: extractDir)
                    modelStates[model.id] = .failed("解压失败 (exit code \(process.terminationStatus))")
                    return
                }

                // 3. 找到解压后的目录 (sherpa-onnx-qwen3-asr-0.6B-int8-*)
                let contents = try FileManager.default.contentsOfDirectory(at: extractDir, includingPropertiesForKeys: nil)
                guard let extractedDir = contents.first(where: { $0.hasDirectoryPath }) else {
                    try? FileManager.default.removeItem(at: extractDir)
                    modelStates[model.id] = .failed("解压后未找到模型目录")
                    return
                }

                // 4. 将文件从解压目录移到模型目录
                let extractedContents = try FileManager.default.contentsOfDirectory(at: extractedDir, includingPropertiesForKeys: nil)
                for item in extractedContents {
                    let dest = modelDir.appendingPathComponent(item.lastPathComponent)
                    try? FileManager.default.removeItem(at: dest)
                    try FileManager.default.moveItem(at: item, to: dest)
                }

                // 清理临时目录
                try? FileManager.default.removeItem(at: extractDir)

                // 5. 验证模型完整性
                if isModelInstalled(model) {
                    modelStates[model.id] = .installed
                    engine.reloadModelConfiguration()
                    print("✅ Qwen3-ASR model \(model.size) download completed")
                } else {
                    modelStates[model.id] = .failed("下载完成但模型文件不完整")
                }
            } catch is CancellationError {
                modelStates[model.id] = .notDownloaded
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
        downloadDelegates[modelId]?.cancel()
        downloadDelegates.removeValue(forKey: modelId)
        modelStates[modelId] = .notDownloaded
    }

    // MARK: - Private

    private func downloadWithProgress(url: URL, modelId: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let delegate = DownloadDelegate(modelId: modelId) { [weak self] result in
                self?.downloadDelegates.removeValue(forKey: modelId)
                switch result {
                case .success(let url):
                    continuation.resume(returning: url)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            downloadDelegates[modelId] = delegate

            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            let task = session.downloadTask(with: url)
            task.resume()
        }
    }

    private func isModelInstalled(_ model: Qwen3AsrModelDefinition) -> Bool {
        let modelDir = engine.getModelDirectory(for: model.size)
        let fm = FileManager.default
        guard fm.fileExists(atPath: modelDir.path) else { return false }

        for file in model.requiredFiles {
            guard fm.fileExists(atPath: modelDir.appendingPathComponent(file).path) else {
                return false
            }
        }

        // 检查 tokenizer 目录
        let tokenizerDir = modelDir.appendingPathComponent(model.tokenizerDir)
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
}

// MARK: - Download Delegate

private class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    private let modelId: String
    private let completion: (Result<URL, Error>) -> Void
    private var isCompleted = false

    init(modelId: String, completion: @escaping (Result<URL, Error>) -> Void) {
        self.modelId = modelId
        self.completion = completion
    }

    func cancel() {
        guard !isCompleted else { return }
        isCompleted = true
        completion(.failure(CancellationError()))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // 将临时文件移到安全位置
        let tempDir = FileManager.default.temporaryDirectory
        let destURL = tempDir.appendingPathComponent("qwen3-asr-\(modelId)-\(UUID().uuidString).tar.bz2")

        do {
            try FileManager.default.moveItem(at: location, to: destURL)
            finish(with: .success(destURL))
        } catch {
            finish(with: .failure(error))
        }
        session.invalidateAndCancel()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)

        Task { @MainActor [weak self] in
            guard let self else { return }
            Qwen3AsrModelManager.shared.modelStates[self.modelId] = .downloading(progress: progress)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            finish(with: .failure(error))
            session.invalidateAndCancel()
        }
    }

    private func finish(with result: Result<URL, Error>) {
        guard !isCompleted else { return }
        isCompleted = true
        completion(result)
    }
}
