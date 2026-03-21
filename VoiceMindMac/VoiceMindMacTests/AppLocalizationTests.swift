import XCTest
@testable import VoiceMind

final class AppLocalizationTests: XCTestCase {
    func testSimplifiedChineseMapsToZhHansFirst() {
        XCTAssertEqual(
            AppLocalization.bundleLocalizationCandidates(for: "zh-CN"),
            ["zh-Hans", "zh-CN", "zh"]
        )
    }

    func testEnglishMapsToLanguageFallback() {
        XCTAssertEqual(
            AppLocalization.bundleLocalizationCandidates(for: "en-US"),
            ["en-US", "en"]
        )
    }
}
