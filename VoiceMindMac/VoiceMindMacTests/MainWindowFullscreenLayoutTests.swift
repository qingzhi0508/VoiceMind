import XCTest

final class MainWindowFullscreenLayoutTests: XCTestCase {
    func testMainSceneDefaultsTo1280By800WindowSize() throws {
        let appSource = try voiceMindMacAppSource()

        XCTAssertTrue(
            appSource.contains(".defaultSize(width: 1280, height: 800)"),
            "VoiceMindMacApp should default the main window to 1280 by 800."
        )
    }

    func testMainWindowDoesNotUseFixedCanvasSizeForRootLayout() throws {
        let source = try mainWindowSource()

        XCTAssertFalse(
            source.contains(".frame(width: 1220, height: 780)"),
            "MainWindow should expand with the window instead of pinning the root layout to a fixed canvas."
        )
    }

    func testAboutTabDoesNotCenterContentWithOuterSpacers() throws {
        let source = try mainWindowSource()
        let aboutTabRange = try XCTUnwrap(source.range(of: "struct AboutTab: View"))
        let notesTabRange = try XCTUnwrap(source.range(of: "// MARK: - Notes Tab"))
        let aboutTabSource = String(source[aboutTabRange.lowerBound..<notesTabRange.lowerBound])

        XCTAssertFalse(
            aboutTabSource.contains("Spacer()"),
            "AboutTab should anchor content to the available space instead of centering a compact card with outer spacers."
        )
    }

    func testAboutTabUsesSupportedCrossDeviceSymbol() throws {
        let source = try mainWindowSource()

        XCTAssertFalse(
            source.contains("\"desktopcomputer.and.iphone\""),
            "AboutTab should avoid unavailable SF Symbols that log lookup failures at launch."
        )

        XCTAssertTrue(
            source.contains("\"laptopcomputer.and.iphone\""),
            "AboutTab should use a supported cross-device SF Symbol."
        )
    }

    private func mainWindowSource() throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let projectRoot = testsDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let mainWindowURL = projectRoot
            .appendingPathComponent("VoiceMindMac/VoiceMindMac/Views/MainWindow.swift")

        return try String(contentsOf: mainWindowURL, encoding: .utf8)
    }

    private func voiceMindMacAppSource() throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let projectRoot = testsDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appURL = projectRoot
            .appendingPathComponent("VoiceMindMac/VoiceMindMac/VoiceMindMacApp.swift")

        return try String(contentsOf: appURL, encoding: .utf8)
    }
}
