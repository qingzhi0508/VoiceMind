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
