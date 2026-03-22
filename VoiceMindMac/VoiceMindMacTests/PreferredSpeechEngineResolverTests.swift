import XCTest
@testable import VoiceMind

final class PreferredSpeechEngineResolverTests: XCTestCase {
    func testFallsBackToAppleSpeechWhenSavedEngineIsUnavailable() {
        let resolvedIdentifier = PreferredSpeechEngineResolver.resolve(
            savedEngineId: "sensevoice",
            availableEngineIds: ["apple-speech"],
            fallbackEngineId: "apple-speech"
        )

        XCTAssertEqual(resolvedIdentifier, "apple-speech")
    }

    func testKeepsSavedEngineWhenItIsAvailable() {
        let resolvedIdentifier = PreferredSpeechEngineResolver.resolve(
            savedEngineId: "apple-speech",
            availableEngineIds: ["apple-speech"],
            fallbackEngineId: "apple-speech"
        )

        XCTAssertEqual(resolvedIdentifier, "apple-speech")
    }
}
