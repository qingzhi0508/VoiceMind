import XCTest

final class InjectionTargetCaptureSourceTests: XCTestCase {
    func testShowPairingWindowCapturesTargetBeforeWindowBecomesKey() throws {
        let source = try menuBarControllerSource()
        let methodBody = try XCTUnwrap(methodBody(named: "func showPairingWindow(code: String)", in: source))

        let captureIndex = try XCTUnwrap(methodBody.range(of: "textInjectionService.captureTargetApplication()")?.lowerBound)
        let makeKeyIndex = try XCTUnwrap(methodBody.range(of: "window.makeKeyAndOrderFront(nil)")?.lowerBound)

        XCTAssertLessThan(
            methodBody.distance(from: methodBody.startIndex, to: captureIndex),
            methodBody.distance(from: methodBody.startIndex, to: makeKeyIndex),
            "showPairingWindow should capture the current target application before VoiceMind takes focus."
        )
    }

    func testWindowDidBecomeKeyDoesNotOverwriteCapturedTarget() throws {
        let source = try menuBarControllerSource()
        let methodBody = try XCTUnwrap(methodBody(named: "func windowDidBecomeKey(_ notification: Notification)", in: source))

        XCTAssertFalse(
            methodBody.contains("captureTargetApplication()"),
            "windowDidBecomeKey should not overwrite the previously captured target after VoiceMind becomes key."
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
