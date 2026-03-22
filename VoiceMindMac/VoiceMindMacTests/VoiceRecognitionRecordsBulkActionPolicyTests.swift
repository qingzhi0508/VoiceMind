import XCTest
@testable import VoiceMind

final class VoiceRecognitionRecordsBulkActionPolicyTests: XCTestCase {
    func testDeleteSelectedIsEnabledOnlyWhenEditingAndHasSelection() {
        XCTAssertFalse(
            VoiceRecognitionRecordsBulkActionPolicy(
                isEditing: false,
                totalRecordCount: 4,
                selectedRecordCount: 2
            ).canDeleteSelection
        )

        XCTAssertFalse(
            VoiceRecognitionRecordsBulkActionPolicy(
                isEditing: true,
                totalRecordCount: 4,
                selectedRecordCount: 0
            ).canDeleteSelection
        )

        XCTAssertTrue(
            VoiceRecognitionRecordsBulkActionPolicy(
                isEditing: true,
                totalRecordCount: 4,
                selectedRecordCount: 2
            ).canDeleteSelection
        )
    }

    func testClearAllIsEnabledOnlyWhenRecordsExist() {
        XCTAssertFalse(
            VoiceRecognitionRecordsBulkActionPolicy(
                isEditing: false,
                totalRecordCount: 0,
                selectedRecordCount: 0
            ).canClearAll
        )

        XCTAssertTrue(
            VoiceRecognitionRecordsBulkActionPolicy(
                isEditing: false,
                totalRecordCount: 3,
                selectedRecordCount: 0
            ).canClearAll
        )
    }
}
