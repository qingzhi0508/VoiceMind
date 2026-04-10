import XCTest

final class PairingWindowCloseSourceTests: XCTestCase {
    func testClosingPairingWindowCancelsActivePairing() throws {
        let source = try menuBarControllerSource()
        let windowWillCloseBody = try XCTUnwrap(windowWillCloseBody(in: source))

        XCTAssertTrue(
            windowWillCloseBody.contains("connectionManager.cancelPairing()"),
            "windowWillClose should cancel the active pairing session when the pairing window is closed so the start pairing action becomes available again."
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

    private func windowWillCloseBody(in source: String) -> String? {
        guard let signatureRange = source.range(of: "func windowWillClose(_ notification: Notification) {") else {
            return nil
        }

        let bodyStart = signatureRange.upperBound
        guard let extensionEnd = source[bodyStart...].range(of: "\n}\n") else {
            return nil
        }

        return String(source[bodyStart..<extensionEnd.lowerBound])
    }
}
