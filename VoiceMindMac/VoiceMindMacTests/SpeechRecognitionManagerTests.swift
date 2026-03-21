import XCTest
@testable import VoiceMindMac

final class SpeechRecognitionManagerTests: XCTestCase {
    var manager: SpeechRecognitionManager!
    var mockEngine: MockSpeechEngine!

    override func setUp() {
        super.setUp()
        manager = SpeechRecognitionManager.shared
        mockEngine = MockSpeechEngine()
    }

    override func tearDown() {
        mockEngine = nil
        super.tearDown()
    }

    func testEngineRegistration() {
        // Given
        let initialCount = manager.availableEngines().count

        // When
        manager.registerEngine(mockEngine)

        // Then
        let newCount = manager.availableEngines().count
        XCTAssertEqual(newCount, initialCount + 1, "Engine should be registered")

        let registered = manager.getEngine(identifier: mockEngine.identifier)
        XCTAssertNotNil(registered, "Registered engine should be retrievable")
        XCTAssertEqual(registered?.identifier, mockEngine.identifier)
    }

    func testEngineSelection() throws {
        // Given
        manager.registerEngine(mockEngine)

        // When
        try manager.selectEngine(identifier: mockEngine.identifier)

        // Then
        XCTAssertEqual(manager.currentEngine?.identifier, mockEngine.identifier)
    }

    func testEngineSelectionWithInvalidId() {
        // Given
        let invalidId = "non-existent-engine"

        // When/Then
        XCTAssertThrowsError(try manager.selectEngine(identifier: invalidId)) { error in
            XCTAssertTrue(error is SpeechError)
        }
    }

    func testFallbackToAppleSpeech() throws {
        // Given
        mockEngine.mockIsAvailable = false
        manager.registerEngine(mockEngine)
        try manager.selectEngine(identifier: mockEngine.identifier)

        // When - startRecognition should succeed by falling back to apple-speech
        try manager.startRecognition(sessionId: "test", language: "zh-CN")

        // Then - should fallback to apple-speech
        XCTAssertEqual(manager.currentEngine?.identifier, "apple-speech")
    }
}

// Mock engine for testing
class MockSpeechEngine: NSObject, SpeechRecognitionEngine {
    var identifier = "mock-engine"
    let displayName = "Mock Engine"
    let supportsStreaming = true
    var supportedLanguages: [String] = ["zh-CN", "en-US"]
    var mockIsAvailable = true
    var isAvailable: Bool { mockIsAvailable }
    weak var delegate: SpeechRecognitionEngineDelegate?

    var initializeCalled = false
    var startRecognitionCalled = false
    var processAudioDataCalled = false
    var stopRecognitionCalled = false

    func initialize() async throws {
        initializeCalled = true
    }

    func startRecognition(sessionId: String, language: String) throws {
        startRecognitionCalled = true
    }

    func processAudioData(_ data: Data) throws {
        processAudioDataCalled = true
    }

    func stopRecognition() throws {
        stopRecognitionCalled = true
        // Simulate recognition completion
        delegate?.engine(self, didRecognizeText: "测试文本", sessionId: "test", language: "zh-CN")
    }
}
