import XCTest
@testable import VoiceMind

final class MainWindowNavigationPolicyTests: XCTestCase {
    @MainActor
    func testPrimarySectionsPromoteNotesToHomeAndPlaceCollaborationBelow() {
        XCTAssertEqual(
            MainWindowNavigationPolicy.primarySections,
            [.home, .collaboration, .data, .speech, .permissions]
        )
    }

    @MainActor
    func testCollaborationSectionUsesFormerHomePresentation() {
        XCTAssertEqual(MainWindowNavigationPolicy.contentSection(for: .home), .notes)
        XCTAssertEqual(MainWindowNavigationPolicy.contentSection(for: .collaboration), .collaboration)
    }
}
