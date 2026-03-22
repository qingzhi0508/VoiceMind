import XCTest
@testable import VoiceMind

final class NotesTextSelectionPolicyTests: XCTestCase {
    func testRecognizedTextCanBeSelectedForCopy() {
        XCTAssertTrue(NotesTextSelectionPolicy.allowsSelection(for: "识别完成"))
    }

    func testPlaceholderDoesNotNeedSelection() {
        XCTAssertFalse(NotesTextSelectionPolicy.allowsSelection(for: ""))
        XCTAssertFalse(NotesTextSelectionPolicy.allowsSelection(for: "   "))
    }
}
