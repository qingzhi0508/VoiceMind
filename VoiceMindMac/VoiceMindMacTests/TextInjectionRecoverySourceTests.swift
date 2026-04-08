import XCTest

final class TextInjectionRecoverySourceTests: XCTestCase {
    func testRestoringTargetApplicationUsesIgnoringOtherAppsActivation() throws {
        let source = try menuBarControllerSource()
        let methodBody = try XCTUnwrap(methodBody(named: "func restoreInjectionTargetApplicationIfNeeded(completion: @escaping () -> Void)", in: source))

        XCTAssertTrue(
            methodBody.contains("app.activate(options: [.activateIgnoringOtherApps])"),
            "Restoring the target application should force it back to the foreground before attempting text injection."
        )
    }

    func testNoFocusedTargetPathSchedulesRetryBeforeShowingFailure() throws {
        let source = try menuBarControllerSource()

        XCTAssertTrue(
            source.contains("No focused input target"),
            "The recovery path should still specifically handle the no-focused-target failure case."
        )
        XCTAssertTrue(
            source.contains("DispatchQueue.main.asyncAfter"),
            "Text injection should retry briefly when the target app has just been reactivated and focus may not have settled yet."
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

    private func methodBody(named signature: String, in source: String) -> String? {
        guard let signatureRange = source.range(of: signature) else {
            return nil
        }

        let bodyStart = signatureRange.upperBound
        guard let methodEnd = source[bodyStart...].range(of: "\n    }\n") else {
            return nil
        }

        return String(source[bodyStart..<methodEnd.lowerBound])
    }
}
