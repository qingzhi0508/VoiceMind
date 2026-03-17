import Foundation

public enum InboundDataCategory: Codable {
    case voice
    case pairing
    case connection
}

public enum InboundDataSeverity: Codable {
    case info
    case warning
    case error
}

public struct InboundDataRecord: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let title: String
    public let detail: String
    public let category: InboundDataCategory
    public let severity: InboundDataSeverity

    public var isVoice: Bool {
        category == .voice
    }

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        title: String,
        detail: String,
        category: InboundDataCategory,
        severity: InboundDataSeverity
    ) {
        self.id = id
        self.timestamp = timestamp
        self.title = title
        self.detail = detail
        self.category = category
        self.severity = severity
    }
}
