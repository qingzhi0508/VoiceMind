import XCTest
@testable import SharedCore

final class MessageEnvelopeTests: XCTestCase {
    func testMessageTypeRawValues() {
        XCTAssertEqual(MessageType.pairRequest.rawValue, "pairRequest")
        XCTAssertEqual(MessageType.pairConfirm.rawValue, "pairConfirm")
        XCTAssertEqual(MessageType.pairSuccess.rawValue, "pairSuccess")
        XCTAssertEqual(MessageType.startListen.rawValue, "startListen")
        XCTAssertEqual(MessageType.stopListen.rawValue, "stopListen")
        XCTAssertEqual(MessageType.result.rawValue, "result")
        XCTAssertEqual(MessageType.textMessage.rawValue, "textMessage")
        XCTAssertEqual(MessageType.ping.rawValue, "ping")
        XCTAssertEqual(MessageType.pong.rawValue, "pong")
        XCTAssertEqual(MessageType.error.rawValue, "error")
    }

    func testMessageEnvelopeEncodingDecoding() throws {
        let payload = try JSONEncoder().encode(["test": "data"])
        let envelope = MessageEnvelope(
            type: .ping,
            payload: payload,
            timestamp: Date(),
            deviceId: "test-device-123",
            hmac: "test-hmac"
        )

        let encoded = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(MessageEnvelope.self, from: encoded)

        XCTAssertEqual(decoded.type, .ping)
        XCTAssertEqual(decoded.deviceId, "test-device-123")
        XCTAssertEqual(decoded.hmac, "test-hmac")
    }

    func testMessageEnvelopeWithoutHMAC() throws {
        let payload = try JSONEncoder().encode(["test": "data"])
        let envelope = MessageEnvelope(
            type: .pairRequest,
            payload: payload,
            timestamp: Date(),
            deviceId: "test-device-123",
            hmac: nil
        )

        let encoded = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(MessageEnvelope.self, from: encoded)

        XCTAssertEqual(decoded.type, .pairRequest)
        XCTAssertNil(decoded.hmac)
    }
}
