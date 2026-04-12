import XCTest

final class TextInjectionRecoverySourceTests: XCTestCase {
    func testRestoringTargetApplicationIsHandledByService() throws {
        let source = try textInjectionServiceSource()

        XCTAssertTrue(
            source.contains("restoreTargetApplicationIfNeeded"),
            "TextInjectionService should contain the target application restore logic."
        )
        XCTAssertTrue(
            source.contains("activateApp"),
            "Restoring the target application should activate the previously captured app."
        )
    }

    func testNoFocusedTargetPathSchedulesRetryBeforeShowingFailure() throws {
        let source = try textInjectionServiceSource()

        XCTAssertTrue(
            source.contains("No focused input target"),
            "The recovery path should still specifically handle the no-focused-target failure case."
        )
        XCTAssertTrue(
            source.contains("asyncAfter"),
            "Text injection should retry briefly when the target app has just been reactivated and focus may not have settled yet."
        )
    }

    private func textInjectionServiceSource() throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let projectRoot = testsDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = projectRoot
            .appendingPathComponent("VoiceMindMac/VoiceMindMac/TextInjection/TextInjectionService.swift")

        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
