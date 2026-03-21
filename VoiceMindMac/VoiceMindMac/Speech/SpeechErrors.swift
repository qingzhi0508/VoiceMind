import Foundation

/// 语音识别相关错误
enum SpeechError: LocalizedError {
    case noEngineSelected
    case noAvailableEngine
    case engineNotAvailable
    case engineNotInitialized
    case invalidAudioFormat
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .noEngineSelected:
            return "未选择语音识别引擎"
        case .noAvailableEngine:
            return "没有可用的语音识别引擎"
        case .engineNotAvailable:
            return "当前引擎不可用"
        case .engineNotInitialized:
            return "引擎未初始化"
        case .invalidAudioFormat:
            return "无效的音频格式"
        case .recognitionFailed(let reason):
            return "识别失败: \(reason)"
        }
    }
}

/// SenseVoice 引擎错误
enum SenseVoiceError: LocalizedError {
    case modelNotFound
    case modelLoadFailed
    case notInitialized
    case invalidModelPath
    case invalidTokensFile
    case audioConversionFailed

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "SenseVoice 模型未找到"
        case .modelLoadFailed:
            return "SenseVoice 模型加载失败"
        case .notInitialized:
            return "SenseVoice 引擎未初始化"
        case .invalidModelPath:
            return "无效的模型路径"
        case .invalidTokensFile:
            return "无效的 tokens 文件"
        case .audioConversionFailed:
            return "音频格式转换失败"
        }
    }
}

/// 模型管理错误
enum ModelError: LocalizedError {
    case downloadFailed(String)
    case modelNotFound
    case invalidModel
    case storageError
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let reason):
            return "模型下载失败: \(reason)"
        case .modelNotFound:
            return "模型未找到"
        case .invalidModel:
            return "无效的模型文件"
        case .storageError:
            return "存储错误"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        }
    }
}
