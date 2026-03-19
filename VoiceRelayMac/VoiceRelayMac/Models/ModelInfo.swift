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
    static let predefinedModels: [ModelInfo] = {
        // SenseVoice Small 模型（Hugging Face 直链，包含 model.int8.onnx / tokens.txt）
        guard let downloadURL = URL(string: "https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/") else {
            print("❌ 无效的模型下载URL，使用空数组")
            return []
        }
        return [
            ModelInfo(
                id: "sensevoice-small",
                name: "SenseVoice Small",
                engineType: "sensevoice",
                version: "1.0",
                languages: ["zh-CN", "en-US", "ja-JP", "ko-KR", "yue-CN"],
                size: 245_000_000, // 约 245MB（int8）
                downloadURL: downloadURL,
                localPath: nil,
                description: "多语言语音识别模型，支持50+语言",
                files: [
                    "https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/model.int8.onnx?download=true",
                    "https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/tokens.txt?download=true"
                ]
            )
        ]
    }()
}
