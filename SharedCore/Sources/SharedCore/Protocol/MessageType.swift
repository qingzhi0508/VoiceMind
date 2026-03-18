import Foundation

public enum MessageType: String, Codable {
    case pairRequest
    case pairConfirm
    case pairSuccess
    case startListen
    case stopListen
    case result
    case partialResult  // Mac -> iOS: 部分识别结果（实时反馈）
    case ping
    case pong
    case error

    // 音频流消息类型
    case audioStart     // iOS -> Mac: 开始音频流
    case audioData      // iOS -> Mac: 音频数据
    case audioEnd       // iOS -> Mac: 结束音频流
}
