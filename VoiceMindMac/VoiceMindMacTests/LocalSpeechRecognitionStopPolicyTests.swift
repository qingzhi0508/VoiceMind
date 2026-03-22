import XCTest
@testable import VoiceMind

final class LocalSpeechRecognitionStopPolicyTests: XCTestCase {
    func testFreshStartDoesNotGracefullyStopWhenNoSessionIsActive() {
        XCTAssertFalse(
            LocalSpeechRecognitionStopPolicy.shouldStopExistingSessionBeforeStarting(
                isAudioEngineRunning: false,
                hasRecognitionTask: false,
                hasRecognitionRequest: false
            )
        )
    }

    func testRestartGracefullyStopsWhenPreviousSessionExists() {
        XCTAssertTrue(
            LocalSpeechRecognitionStopPolicy.shouldStopExistingSessionBeforeStarting(
                isAudioEngineRunning: true,
                hasRecognitionTask: true,
                hasRecognitionRequest: true
            )
        )
    }

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

    func testDelayedCancellationDoesNotTouchNewerRecordingSession() {
        XCTAssertFalse(
            LocalSpeechRecognitionStopPolicy.shouldCancelDelayedTask(
                scheduledSessionGeneration: 3,
                currentSessionGeneration: 4,
                isAudioEngineRunning: true
            )
        )
    }

    func testDelayedCancellationStillAppliesToSameStoppedSession() {
        XCTAssertTrue(
            LocalSpeechRecognitionStopPolicy.shouldCancelDelayedTask(
                scheduledSessionGeneration: 3,
                currentSessionGeneration: 3,
                isAudioEngineRunning: false
            )
        )
    }
}
