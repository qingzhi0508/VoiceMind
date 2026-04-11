import XCTest

final class MainWindowFullscreenLayoutTests: XCTestCase {
    func testMainSceneDefaultsTo800By720WindowSize() throws {
        let appSource = try voiceMindMacAppSource()

        XCTAssertTrue(
            appSource.contains(".defaultSize(width: 800, height: 720)"),
            "VoiceMindMacApp should default the main window to 800 by 720."
        )
    }

    func testMainSceneDoesNotForceContentMinSizeResizability() throws {
        let appSource = try voiceMindMacAppSource()

        XCTAssertFalse(
            appSource.contains(".windowResizability(.contentMinSize)"),
            "VoiceMindMacApp should not force content-based minimum resizing if the window should shrink freely."
        )
    }

    func testAppDelegateRecentersAndResizesMainWindowAfterLaunch() throws {
        let appSource = try voiceMindMacAppSource()

        XCTAssertTrue(
            appSource.contains("normalizeMainWindowFrameIfNeeded"),
            "App launch should normalize main window frame so startup stays centered with preferred size."
        )
    }

    func testMainWindowDoesNotUseFixedCanvasSizeForRootLayout() throws {
        let source = try mainWindowSource()

        XCTAssertFalse(
            source.contains(".frame(width: 1220, height: 780)"),
            "MainWindow should expand with the window instead of pinning the root layout to a fixed canvas."
        )
    }

    func testMainWindowDoesNotForceMinimumHeightsThatBlockVerticalResize() throws {
        let source = try mainWindowSource()

        XCTAssertFalse(
            source.contains("minHeight: 96"),
            "MainWindow should not enforce the old 96pt minimum card height if vertical resize should stay flexible."
        )

        XCTAssertFalse(
            source.contains("minHeight: 170"),
            "MainWindow should not enforce the old 170pt minimum card height if vertical resize should stay flexible."
        )

        XCTAssertFalse(
            source.contains("minHeight: 200"),
            "MainWindow should not enforce the old 200pt minimum note area height if vertical resize should stay flexible."
        )
    }

    func testMainWindowDoesNotStretchCoreContainersToInfiniteHeight() throws {
        let source = try mainWindowSource()

        XCTAssertFalse(
            source.contains(".frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)"),
            "MainWindow should not force core containers to infinite height if vertical resize should keep a compact page height."
        )
    }

    func testContentAreaDoesNotUseOpacityOnlyForHiddenPersistentPages() throws {
        let source = try mainWindowSource()

        XCTAssertFalse(
            source.contains(".opacity(selectedSection == section ? 1 : 0)"),
            "MainWindow should not keep hidden pages in layout with opacity-only hiding because that makes the content height keep expanding."
        )
    }

    func testMainWindowUsesAppLocalizationInsteadOfSystemLocalizedStringForUIOverrides() throws {
        let source = try mainWindowSource()

        XCTAssertFalse(
            source.contains("String(localized:"),
            "MainWindow should resolve UI strings through AppLocalization so the in-app language setting takes effect."
        )
    }

    func testNotesTabDoesNotUseSpacerToPushContentToWindowBottom() throws {
        let source = try mainWindowSource()
        let notesTabRange = try XCTUnwrap(source.range(of: "struct NotesTab: View"))
        let recordButtonRange = try XCTUnwrap(source.range(of: "// MARK: - Record Button"))
        let notesTabSource = String(source[notesTabRange.lowerBound..<recordButtonRange.lowerBound])

        // Only check for VStack-level Spacer() that pushes content to the bottom.
        // HStack-level Spacer() used for horizontal alignment (e.g., pushing a clear button
        // to the trailing edge) are legitimate and should not trigger this check.
        let verticalSpacerPattern = "\n                Spacer()\n"
        XCTAssertFalse(
            notesTabSource.contains(verticalSpacerPattern),
            "NotesTab should not use a vertical Spacer that forces content to stick to the window bottom."
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
