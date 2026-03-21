import XCTest
@testable import VoiceMindMac

final class SpeechRecognitionIntegrationTests: XCTestCase {
    var manager: SpeechRecognitionManager!
    var mockDelegate: MockEngineDelegate!

    override func setUp() {
        super.setUp()
        manager = SpeechRecognitionManager.shared
        mockDelegate = MockEngineDelegate()
    }

    override func tearDown() {
        mockDelegate = nil
        super.tearDown()
    }

    func testEndToEndRecognitionFlow() throws {
        // Given - Register and select mock engine
        let mockEngine = MockSpeechEngine()

        let expectation = XCTestExpectation(description: "Engine registered")
        manager.registerEngine(mockEngine)

        // Wait for async registration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        try manager.selectEngine(identifier: mockEngine.identifier)

        // Set delegate on the registered engine instance
        if let registeredEngine = manager.getEngine(identifier: mockEngine.identifier) as? MockSpeechEngine {
            registeredEngine.delegate = mockDelegate
        }

        let sessionId = "test-session-123"
        let language = "zh-CN"

        // When - Start recognition
        try manager.startRecognition(sessionId: sessionId, language: language)
        XCTAssertTrue(mockEngine.startRecognitionCalled)

        // Process audio data
        let audioData = Data(repeating: 0, count: 1024)
        try manager.processAudioData(audioData)
        XCTAssertTrue(mockEngine.processAudioDataCalled)

        // Stop recognition
        try manager.stopRecognition()
        XCTAssertTrue(mockEngine.stopRecognitionCalled)

        // Wait for delegate callback to complete
        let delegateExpectation = XCTestExpectation(description: "Delegate called")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            delegateExpectation.fulfill()
        }
        wait(for: [delegateExpectation], timeout: 1.0)

        // Then - Verify delegate was called
        XCTAssertTrue(mockDelegate.didRecognizeTextCalled)
    }

    func testEngineNotAvailableFallback() throws {
        // Given - Register apple-speech as fallback
        let appleSpeechEngine = MockSpeechEngine()
        appleSpeechEngine.identifier = "apple-speech"

        let unavailableEngine = MockSpeechEngine()
        unavailableEngine.identifier = "unavailable-engine"
        unavailableEngine.mockIsAvailable = false

        let expectation = XCTestExpectation(description: "Engines registered")
        manager.registerEngine(appleSpeechEngine)
        manager.registerEngine(unavailableEngine)

        // Wait for async registration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        try manager.selectEngine(identifier: unavailableEngine.identifier)

        // When - Try to start recognition, should fallback to apple-speech
        try manager.startRecognition(sessionId: "test", language: "zh-CN")

        // Then - Should fallback to apple-speech
        XCTAssertEqual(manager.currentEngine?.identifier, "apple-speech")
        XCTAssertTrue(appleSpeechEngine.startRecognitionCalled)
    }

    func testMultipleEnginesSwitching() throws {
        // Given - Two engines
        let engine1 = MockSpeechEngine()
        let engine2 = MockSpeechEngine()
        engine2.identifier = "mock-engine-2"

        let expectation = XCTestExpectation(description: "Engines registered")
        manager.registerEngine(engine1)
        manager.registerEngine(engine2)

        // Wait for async registration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // When - Switch between engines
        try manager.selectEngine(identifier: engine1.identifier)
        XCTAssertEqual(manager.currentEngine?.identifier, engine1.identifier)

        try manager.selectEngine(identifier: engine2.identifier)
        XCTAssertEqual(manager.currentEngine?.identifier, engine2.identifier)

        // Then - Both engines should be available
        let engines = manager.availableEngines()
        XCTAssertTrue(engines.contains { $0.identifier == engine1.identifier })
        XCTAssertTrue(engines.contains { $0.identifier == engine2.identifier })
    }
}

// Mock delegate for testing
class MockEngineDelegate: SpeechRecognitionEngineDelegate {
    var didRecognizeTextCalled = false
    var didFailWithErrorCalled = false
    var didReceivePartialResultCalled = false

    var recognizedText: String?
    var error: Error?
    var partialResult: String?

    func engine(_ engine: SpeechRecognitionEngine, didRecognizeText text: String, sessionId: String, language: String) {
        didRecognizeTextCalled = true
        recognizedText = text
    }

    func engine(_ engine: SpeechRecognitionEngine, didFailWithError error: Error, sessionId: String) {
        didFailWithErrorCalled = true
        self.error = error
    }

    func engine(_ engine: SpeechRecognitionEngine, didReceivePartialResult text: String, sessionId: String) {
        didReceivePartialResultCalled = true
        partialResult = text
    }
}
