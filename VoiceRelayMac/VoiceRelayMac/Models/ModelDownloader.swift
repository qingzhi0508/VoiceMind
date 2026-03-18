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
