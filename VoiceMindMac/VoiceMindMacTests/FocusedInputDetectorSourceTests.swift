import XCTest

final class FocusedInputDetectorSourceTests: XCTestCase {
    func testFocusedDetectorCanTraverseParentChainToResolveWritableTarget() throws {
        let source = try focusedInputDetectorSource()

        XCTAssertTrue(
            source.contains("kAXParentAttribute"),
            "FocusedInputDetector should walk parent accessibility elements when the immediate focused element is not writable."
        )
    }

    func testFocusedDetectorExposesWritableTargetLookup() throws {
        let source = try focusedInputDetectorSource()

        XCTAssertTrue(
            source.contains("currentWritableFocusedElement"),
            "FocusedInputDetector should expose a writable focused element lookup for the injector to use."
        )
    }

    private func focusedInputDetectorSource() throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let projectRoot = testsDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = projectRoot
            .appendingPathComponent("VoiceMindMac/VoiceMindMac/TextInjection/FocusedInputDetector.swift")

        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
