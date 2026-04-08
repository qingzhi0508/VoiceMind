import XCTest

final class MenuBarSpeechRoutingSourceTests: XCTestCase {
    func testMenuBarControllerDoesNotStartLocalSpeechRecognizerDirectly() throws {
        let source = try menuBarControllerSource()

        XCTAssertFalse(
            source.contains("localSpeechRecognizer.startRecording"),
            "MenuBarController should not bypass the selected speech engine by starting LocalSpeechRecognizer directly."
        )
    }

    func testMenuBarControllerRoutesLocalRecordingThroughSpeechRecognitionManager() throws {
        let source = try menuBarControllerSource()

        XCTAssertTrue(
            source.contains("speechRecognitionManager.startRecognition"),
            "MenuBarController should start local recording through SpeechRecognitionManager so the selected engine is actually used."
        )
        XCTAssertTrue(
            source.contains("speechRecognitionManager.processAudioData"),
            "MenuBarController should stream captured microphone audio into SpeechRecognitionManager."
        )
    }

    private func menuBarControllerSource() throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let projectRoot = testsDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = projectRoot
            .appendingPathComponent("VoiceMindMac/VoiceMindMac/MenuBar/MenuBarController.swift")

        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
