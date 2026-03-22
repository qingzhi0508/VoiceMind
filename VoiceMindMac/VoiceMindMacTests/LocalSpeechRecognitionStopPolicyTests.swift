import XCTest
@testable import VoiceMind

final class LocalSpeechRecognitionStopPolicyTests: XCTestCase {
    func testStopPolicyWaitsBeforeCancellingRecognitionTask() {
        XCTAssertEqual(LocalSpeechRecognitionStopPolicy.cancellationDelay, 1.0)
    }

    func testStopPolicySuppressesNoSpeechErrorDuringGracefulStop() {
        XCTAssertTrue(
            LocalSpeechRecognitionStopPolicy.shouldSuppressErrorAfterStop(
                NSError(domain: "kAFAssistantErrorDomain", code: 1110, userInfo: [NSLocalizedDescriptionKey: "No speech detected"])
            )
        )
    }
}
