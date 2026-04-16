import Foundation

/// Qwen3-ASR 可下载模型定义
struct Qwen3AsrModelDefinition: Identifiable {
    let id: String
    let displayName: String
    let size: String          // "0.6b"
    let languages: [String]
    let estimatedSize: String
    let downloadURL: String   // GitHub Releases tar.bz2 URL

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
            estimatedSize: "~940 MB",
            downloadURL: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25.tar.bz2"
        ),
    ]
}
