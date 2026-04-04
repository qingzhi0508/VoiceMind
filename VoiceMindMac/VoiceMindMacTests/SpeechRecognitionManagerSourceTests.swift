import XCTest

final class SpeechRecognitionManagerSourceTests: XCTestCase {
    func testSelectEngineUnsafeDoesNotPostNotificationsWhileHoldingQueue() throws {
        let source = try speechRecognitionManagerSource()
        let functionRange = try XCTUnwrap(source.range(of: "private func selectEngineUnsafe(identifier: String) throws -> SpeechRecognitionEngine"))
        let availableRange = try XCTUnwrap(source.range(of: "/// 获取所有可用引擎"))
        let functionSource = String(source[functionRange.lowerBound..<availableRange.lowerBound])

        XCTAssertFalse(
            functionSource.contains("NotificationCenter.default.post"),
            "selectEngineUnsafe should not post notifications while the speech manager queue is locked."
        )
    }

    func testNotificationsAreDispatchedOutsideSpeechManagerQueue() throws {
        let source = try speechRecognitionManagerSource()

        XCTAssertTrue(
            source.contains("DispatchQueue.main.async"),
            "Speech engine change notifications should be dispatched asynchronously on the main queue."
        )
    }

    private func speechRecognitionManagerSource() throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let projectRoot = testsDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = projectRoot
            .appendingPathComponent("VoiceMindMac/VoiceMindMac/Speech/SpeechRecognitionManager.swift")

        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
