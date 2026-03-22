import XCTest
@testable import VoiceMind

final class MainWindowNavigationPolicyTests: XCTestCase {
    @MainActor
    func testPrimarySectionsPromoteNotesToHomeAndPlaceCollaborationBelow() {
        XCTAssertEqual(
            MainWindowNavigationPolicy.primarySections,
            [.home, .records, .collaboration, .data, .speech, .permissions]
        )
    }

    @MainActor
    func testCollaborationSectionUsesFormerHomePresentation() {
        XCTAssertEqual(MainWindowNavigationPolicy.contentSection(for: .home), .notes)
        XCTAssertEqual(MainWindowNavigationPolicy.contentSection(for: .records), .records)
        XCTAssertEqual(MainWindowNavigationPolicy.contentSection(for: .collaboration), .collaboration)
    }
}
