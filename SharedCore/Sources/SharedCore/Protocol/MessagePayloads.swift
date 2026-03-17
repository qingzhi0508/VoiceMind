import Foundation

public struct PairRequestPayload: Codable {
    public let shortCode: String
    public let macName: String
    public let macId: String

    public init(shortCode: String, macName: String, macId: String) {
        self.shortCode = shortCode
        self.macName = macName
        self.macId = macId
    }
}

public struct PairConfirmPayload: Codable {
    public let shortCode: String
    public let iosName: String
    public let iosId: String

    public init(shortCode: String, iosName: String, iosId: String) {
        self.shortCode = shortCode
        self.iosName = iosName
        self.iosId = iosId
    }
}

public struct PairSuccessPayload: Codable {
    public let sharedSecret: String

    public init(sharedSecret: String) {
        self.sharedSecret = sharedSecret
    }
}

public struct StartListenPayload: Codable {
    public let sessionId: String

    public init(sessionId: String) {
        self.sessionId = sessionId
    }
}

public struct StopListenPayload: Codable {
    public let sessionId: String

    public init(sessionId: String) {
        self.sessionId = sessionId
    }
}

public struct ResultPayload: Codable {
    public let sessionId: String
    public let text: String
    public let language: String

    public init(sessionId: String, text: String, language: String) {
        self.sessionId = sessionId
        self.text = text
        self.language = language
    }
}

public struct PingPayload: Codable {
    public let nonce: String

    public init(nonce: String) {
        self.nonce = nonce
    }
}

public struct PongPayload: Codable {
    public let nonce: String

    public init(nonce: String) {
        self.nonce = nonce
    }
}

public struct ErrorPayload: Codable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

// MARK: - 音频流 Payloads

public struct AudioStartPayload: Codable {
    public let sessionId: String
    public let language: String
    public let sampleRate: Int
    public let channels: Int
    public let format: String  // "pcm16"

    public init(sessionId: String, language: String, sampleRate: Int, channels: Int, format: String = "pcm16") {
        self.sessionId = sessionId
        self.language = language
        self.sampleRate = sampleRate
        self.channels = channels
        self.format = format
    }
}

public struct AudioDataPayload: Codable {
    public let sessionId: String
    public let audioData: Data
    public let sequenceNumber: Int

    public init(sessionId: String, audioData: Data, sequenceNumber: Int) {
        self.sessionId = sessionId
        self.audioData = audioData
        self.sequenceNumber = sequenceNumber
    }
}

public struct AudioEndPayload: Codable {
    public let sessionId: String

    public init(sessionId: String) {
        self.sessionId = sessionId
    }
}
