import Foundation

/// Qwen3-ASR 可下载模型定义
struct Qwen3AsrModelDefinition: Identifiable {
    let id: String
    let displayName: String
    let size: String          // "0.6b" or "1.7b"
    let languages: [String]
    let estimatedSize: String
    let huggingFaceModelId: String // e.g. "Qwen/Qwen3-ASR-0.6b"

    /// 模型所需文件（相对于模型目录）
    var requiredFiles: [String] {
        ["conv_frontend.onnx", "encoder.int8.onnx", "decoder.int8.onnx"]
    }

    /// tokenizer 目录
    var tokenizerDir: String { "tokenizer" }

    static let catalog: [Qwen3AsrModelDefinition] = [
        Qwen3AsrModelDefinition(
            id: "qwen3-asr-0.6b",
            displayName: "Qwen3-ASR 0.6B",
            size: "0.6b",
            languages: ["zh-CN", "en-US", "ja-JP", "ko-KR"],
            estimatedSize: "~1.3 GB",
            huggingFaceModelId: "Qwen/Qwen3-ASR-0.6b"
        ),
        Qwen3AsrModelDefinition(
            id: "qwen3-asr-1.7b",
            displayName: "Qwen3-ASR 1.7B",
            size: "1.7b",
            languages: ["zh-CN", "en-US", "ja-JP", "ko-KR"],
            estimatedSize: "~3.5 GB",
            huggingFaceModelId: "Qwen/Qwen3-ASR-1.7b"
        ),
    ]
}
