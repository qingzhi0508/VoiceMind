import Foundation

/// 可下载的 Sherpa-ONNX 模型定义
struct SherpaOnnxModelDefinition: Identifiable {
    let id: String
    let displayName: String
    let languages: [String]
    let downloadURL: String
    let estimatedSize: String
    /// 解压后的目录名（也是 tar.bz2 文件去掉扩展名后的名称）
    let modelName: String

    /// 所有可下载的模型
    static let catalog: [SherpaOnnxModelDefinition] = [
        SherpaOnnxModelDefinition(
            id: "zipformer-small-zh-en",
            displayName: "中英双语 Zipformer",
            languages: ["zh-CN", "en-US"],
            downloadURL: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-small-bilingual-zh-en-2023-02-16.tar.bz2",
            estimatedSize: "48 MB",
            modelName: "sherpa-onnx-streaming-zipformer-small-bilingual-zh-en-2023-02-16"
        ),
        SherpaOnnxModelDefinition(
            id: "paraformer-bilingual-zh-en",
            displayName: "中英双语 Paraformer",
            languages: ["zh-CN", "en-US"],
            downloadURL: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-paraformer-bilingual-zh-en.tar.bz2",
            estimatedSize: "226 MB",
            modelName: "sherpa-onnx-streaming-paraformer-bilingual-zh-en"
        ),
        SherpaOnnxModelDefinition(
            id: "zipformer-zh-14m",
            displayName: "中文 Zipformer 14M",
            languages: ["zh-CN"],
            downloadURL: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-zh-14M-2023-02-23.tar.bz2",
            estimatedSize: "25 MB",
            modelName: "sherpa-onnx-streaming-zipformer-zh-14M-2023-02-23"
        ),
    ]
}
