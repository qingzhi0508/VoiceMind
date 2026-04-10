import XCTest

final class SherpaOnnxModelDirectorySourceTests: XCTestCase {
    func testSherpaEngineSearchesLegacyApplicationSupportDirectory() throws {
        let source = try sherpaEngineSource()

        XCTAssertTrue(
            source.contains("legacyModelConfigDirectory"),
            "SherpaOnnxEngine should keep a legacy Application Support lookup so existing downloaded models remain usable."
        )
        XCTAssertTrue(
            source.contains("candidateModelConfigDirectories"),
            "SherpaOnnxEngine should search more than one model directory when resolving existing models."
        )
    }

    private func sherpaEngineSource() throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let projectRoot = testsDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = projectRoot
            .appendingPathComponent("VoiceMindMac/VoiceMindMac/Speech/Engines/SherpaOnnxEngine.swift")

        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
