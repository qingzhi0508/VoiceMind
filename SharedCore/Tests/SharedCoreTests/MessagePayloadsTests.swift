import XCTest
@testable import SharedCore

final class MessagePayloadsTests: XCTestCase {
    func testPairRequestPayload() throws {
        let payload = PairRequestPayload(
            shortCode: "123456",
            macName: "Test Mac",
            macId: "mac-uuid-123"
        )

        let encoded = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(PairRequestPayload.self, from: encoded)

        XCTAssertEqual(decoded.shortCode, "123456")
        XCTAssertEqual(decoded.macName, "Test Mac")
        XCTAssertEqual(decoded.macId, "mac-uuid-123")
    }

    func testStartListenPayload() throws {
        let payload = StartListenPayload(sessionId: "session-uuid-456")

        let encoded = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(StartListenPayload.self, from: encoded)

        XCTAssertEqual(decoded.sessionId, "session-uuid-456")
    }

    func testResultPayload() throws {
        let payload = ResultPayload(
            sessionId: "session-uuid-789",
            text: "Hello world",
            language: "en-US"
        )

        let encoded = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ResultPayload.self, from: encoded)

        XCTAssertEqual(decoded.sessionId, "session-uuid-789")
        XCTAssertEqual(decoded.text, "Hello world")
        XCTAssertEqual(decoded.language, "en-US")
    }

    func testTextMessagePayload() throws {
        let payload = TextMessagePayload(
            sessionId: "session-uuid-text",
            text: "Paste this",
            language: "zh-CN"
        )

        let encoded = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(TextMessagePayload.self, from: encoded)

        XCTAssertEqual(decoded.sessionId, "session-uuid-text")
        XCTAssertEqual(decoded.text, "Paste this")
        XCTAssertEqual(decoded.language, "zh-CN")
    }

    func testAudioStartPayloadRoundTripsSpeakerPlaybackFlag() throws {
        let payload = AudioStartPayload(
            sessionId: "session-audio-start",
            language: "zh-CN",
            sampleRate: 16_000,
            channels: 1,
            format: "pcm16",
            playThroughMacSpeaker: true
        )

        let encoded = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(AudioStartPayload.self, from: encoded)

        XCTAssertEqual(decoded.sessionId, "session-audio-start")
        XCTAssertTrue(decoded.playThroughMacSpeaker)
    }

    func testAudioStartPayloadDefaultsSpeakerPlaybackFlagToFalseWhenMissing() throws {
        let json = """
        {"sessionId":"session-audio-start","language":"zh-CN","sampleRate":16000,"channels":1,"format":"pcm16"}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(AudioStartPayload.self, from: json)

        XCTAssertEqual(decoded.sessionId, "session-audio-start")
        XCTAssertFalse(decoded.playThroughMacSpeaker)
    }
}
