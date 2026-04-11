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

    func testStatusWindowDoesNotConstrainMinimumSize() throws {
        let source = try menuBarControllerSource()

        XCTAssertFalse(
            source.contains("window.contentMinSize ="),
            "Status window should not enforce any content minimum size."
        )
    }

    func testOnboardingWindowUsesScaledStartupSize() throws {
        let source = try menuBarControllerSource()

        XCTAssertTrue(
            source.contains("contentRect: NSRect(x: 0, y: 0, width: 400, height: 480)"),
            "Onboarding startup window should use the scaled 400 by 480 size."
        )
    }

    func testUsageGuideWindowUsesScaledStartupSize() throws {
        let source = try menuBarControllerSource()

        XCTAssertTrue(
            source.contains("contentRect: NSRect(x: 0, y: 0, width: 416, height: 448)"),
            "Usage guide startup window should use the scaled 416 by 448 size."
        )
    }

    func testMainWindowUsesWiderAndShorterDefaultSize() throws {
        let source = try menuBarControllerSource()

        XCTAssertTrue(
            source.contains("static let defaultWidth: CGFloat = 850"),
            "Main window default width should use 850."
        )

        XCTAssertTrue(
            source.contains("static let defaultHeight: CGFloat = 720"),
            "Main window default height should reduce to 720."
        )

        XCTAssertFalse(
            source.contains("minWidth"),
            "Main window should not define a minimum width so users can freely resize."
        )
    }

    func testShowStatusReappliesPreferredMainWindowSizeForExistingWindow() throws {
        let source = try menuBarControllerSource()

        XCTAssertTrue(
            source.contains("applyPreferredMainWindowSizeAndPosition(to: existingWindow)"),
            "Reopening the main window should reapply the preferred content size."
        )

        XCTAssertTrue(
            source.contains("existingWindow.delegate = self"),
            "Existing main windows should be assigned the controller as delegate so fullscreen lifecycle callbacks are observed."
        )
    }

    func testControllerExposesWindowFrameNormalizationHelper() throws {
        let source = try menuBarControllerSource()

        XCTAssertTrue(
            source.contains("func normalizeMainWindowFrameIfNeeded()"),
            "MenuBarController should expose a reusable helper to normalize main window frame at startup."
        )

        XCTAssertTrue(
            source.contains("window.delegate = self"),
            "Main window normalization should attach the controller as delegate for future fullscreen transitions."
        )
    }

    func testExitFullscreenRestoresPreferredMainWindowSize() throws {
        let source = try menuBarControllerSource()

        XCTAssertTrue(
            source.contains("func windowDidExitFullScreen(_ notification: Notification)"),
            "Exiting fullscreen should trigger a delegate callback to restore preferred window size."
        )

        XCTAssertTrue(
            source.contains("DispatchQueue.main.asyncAfter"),
            "Fullscreen exit flow should reapply the preferred size after the system fullscreen transition completes."
        )

        XCTAssertTrue(
            source.contains("applyPreferredMainWindowSizeAndPosition(to: window)"),
            "Fullscreen exit flow should restore the preferred main window size and centered position."
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
