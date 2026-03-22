import XCTest
@testable import VoiceMind

final class LocalSpeechRecognitionStartPolicyTests: XCTestCase {
    func testDoesNotForceOnDeviceRecognitionForLocalCapture() {
        XCTAssertFalse(
            LocalSpeechRecognitionStartPolicy.shouldRequireOnDeviceRecognition(
                supportsOnDeviceRecognition: true
            )
        )
    }

    func testStartsImmediatelyWhenPermissionsAreAlreadyGranted() {
        XCTAssertTrue(
            LocalSpeechRecognitionStartPolicy.shouldStartImmediately(
                microphoneGranted: true,
                speechRecognitionGranted: true
            )
        )
    }

    func testRequestsPermissionsWhenAnyPermissionIsMissing() {
        XCTAssertFalse(
            LocalSpeechRecognitionStartPolicy.shouldStartImmediately(
                microphoneGranted: false,
                speechRecognitionGranted: true
            )
        )
        XCTAssertFalse(
            LocalSpeechRecognitionStartPolicy.shouldStartImmediately(
                microphoneGranted: true,
                speechRecognitionGranted: false
            )
        )
    }
}
