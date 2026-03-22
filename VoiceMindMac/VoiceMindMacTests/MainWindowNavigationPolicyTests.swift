import XCTest
@testable import VoiceMind

final class MainWindowNavigationPolicyTests: XCTestCase {
    @MainActor
    func testPrimarySectionsPromoteNotesToHomeAndPlaceCollaborationBelow() {
        XCTAssertEqual(
            MainWindowNavigationPolicy.primarySections,
            [.home, .records, .collaboration, .speech]
        )
    }

    @MainActor
    func testSecondarySectionsPlaceLogsAboveSettingsAndAbout() {
        XCTAssertEqual(
            MainWindowSection.secondaryItems,
            [.data, .settings, .about]
        )
    }

    @MainActor
    func testCollaborationSectionUsesFormerHomePresentation() {
        XCTAssertEqual(MainWindowNavigationPolicy.contentSection(for: .home), .notes)
        XCTAssertEqual(MainWindowNavigationPolicy.contentSection(for: .records), .records)
        XCTAssertEqual(MainWindowNavigationPolicy.contentSection(for: .collaboration), .collaboration)
    }
}
