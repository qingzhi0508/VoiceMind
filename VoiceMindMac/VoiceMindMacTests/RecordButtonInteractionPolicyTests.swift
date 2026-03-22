import XCTest
@testable import VoiceMind

final class RecordButtonInteractionPolicyTests: XCTestCase {
    func testPressBeginsRecordingOnlyOnce() {
        XCTAssertTrue(
            RecordButtonInteractionPolicy.shouldStartRecording(
                isPressActive: false,
                isRecording: false
            )
        )
        XCTAssertFalse(
            RecordButtonInteractionPolicy.shouldStartRecording(
                isPressActive: true,
                isRecording: false
            )
        )
        XCTAssertFalse(
            RecordButtonInteractionPolicy.shouldStartRecording(
                isPressActive: false,
                isRecording: true
            )
        )
    }

    func testReleaseStopsOnlyWhenPressWasActiveAndRecording() {
        XCTAssertTrue(
            RecordButtonInteractionPolicy.shouldStopRecording(
                isPressActive: true,
                isRecording: true
            )
        )
        XCTAssertFalse(
            RecordButtonInteractionPolicy.shouldStopRecording(
                isPressActive: false,
                isRecording: true
            )
        )
        XCTAssertFalse(
            RecordButtonInteractionPolicy.shouldStopRecording(
                isPressActive: true,
                isRecording: false
            )
        )
    }
}
