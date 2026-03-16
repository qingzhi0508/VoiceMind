import Foundation

public enum MessageType: String, Codable {
    case pairRequest
    case pairConfirm
    case pairSuccess
    case startListen
    case stopListen
    case result
    case ping
    case pong
    case error
}
