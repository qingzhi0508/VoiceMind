import XCTest

final class MenuBarWindowSizingTests: XCTestCase {
    func testShowStatusDoesNotUseLegacySmallWindowSize() throws {
        let source = try menuBarControllerSource()

        XCTAssertFalse(
            source.contains("width: 500, height: 600"),
            "Menu bar return-to-main should not open the legacy compact window size."
        )
    }

    func testShowStatusUsesPrimaryWindowFirst() throws {
        let source = try menuBarControllerSource()

        XCTAssertTrue(
            source.contains("if let existingWindow = existingMainAppWindow()"),
            "Menu bar return-to-main should prioritize the existing primary window."
        )
    }

    func testExistingMainWindowFilterSkipsNonKeyableStatusBarWindow() throws {
        let source = try menuBarControllerSource()

        XCTAssertTrue(
            source.contains("window.canBecomeKey"),
            "Primary window lookup should skip NSStatusBarWindow-like windows that cannot become key."
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
