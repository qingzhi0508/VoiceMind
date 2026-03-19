import Foundation

/// 模型下载器
class ModelDownloader: NSObject {

    /// 下载进度回调
    typealias ProgressHandler = (Double) -> Void

    /// 下载完成回调
    typealias CompletionHandler = (Result<URL, Error>) -> Void

    private let queue = DispatchQueue(label: "com.voicerelay.modeldownloader")
    private var downloadTask: URLSessionDownloadTask?
    private var destinationURL: URL?
    private var progressHandler: ProgressHandler?
    private var completionHandler: CompletionHandler?
    private var completionCalled = false

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
        queue.async { [weak self] in
            guard let self = self else { return }

            // 取消现有下载
            if let existingTask = self.downloadTask {
                existingTask.cancel()
                print("⚠️ 取消现有下载任务")
            }

            // 重置状态
            self.destinationURL = destinationURL
            self.progressHandler = progress
            self.completionHandler = completion
            self.completionCalled = false

            print("📥 开始下载: \(url.lastPathComponent)")
            print("   目标路径: \(destinationURL.path)")

            var request = URLRequest(url: url)
            request.setValue("VoiceRelayMac/1.0", forHTTPHeaderField: "User-Agent")
            request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
            self.downloadTask = self.session.downloadTask(with: request)
            self.downloadTask?.resume()
        }
    }

    /// 取消下载
    func cancel() {
        queue.async { [weak self] in
            guard let self = self else { return }

            self.downloadTask?.cancel()
            self.downloadTask = nil

            print("❌ 下载已取消")

            // 通知调用者下载已取消
            if !self.completionCalled {
                self.completionCalled = true
                let handler = self.completionHandler
                self.completionHandler = nil
                self.progressHandler = nil

                DispatchQueue.main.async {
                    handler?(.failure(ModelError.downloadFailed("下载已取消")))
                }
            }
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension ModelDownloader: URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // 立即处理临时文件，避免被系统清理
        var destinationURL: URL?
        var handler: CompletionHandler?

        queue.sync {
            guard !completionCalled else { return }
            completionCalled = true
            destinationURL = self.destinationURL
            handler = self.completionHandler
            self.completionHandler = nil
            self.progressHandler = nil
        }

        guard let destinationURL else {
            DispatchQueue.main.async {
                handler?(.failure(ModelError.downloadFailed("无法获取目标 URL")))
            }
            return
        }

        do {
            // 移动文件到目标位置
            let fileManager = FileManager.default
            let destinationDir = destinationURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: destinationDir.path) {
                try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true)
            }
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: location, to: destinationURL)

            print("✅ 下载完成: \(destinationURL.lastPathComponent)")

            DispatchQueue.main.async {
                handler?(.success(destinationURL))
            }
        } catch {
            print("❌ 移动文件失败: \(error.localizedDescription)")

            DispatchQueue.main.async {
                handler?(.failure(error))
            }
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

        queue.async { [weak self] in
            guard let self = self else { return }
            let handler = self.progressHandler

            DispatchQueue.main.async {
                handler?(progress)
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            queue.async { [weak self] in
                guard let self = self else { return }

                // 防止重复调用
                guard !self.completionCalled else { return }
                self.completionCalled = true

                print("❌ 下载失败: \(error.localizedDescription)")

                let handler = self.completionHandler
                self.completionHandler = nil
                self.progressHandler = nil

                DispatchQueue.main.async {
                    handler?(.failure(error))
                }
            }
        }
    }
}
