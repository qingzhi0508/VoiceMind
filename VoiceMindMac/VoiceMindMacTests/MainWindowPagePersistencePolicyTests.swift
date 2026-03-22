import XCTest
@testable import VoiceMind

final class MainWindowPagePersistencePolicyTests: XCTestCase {
    @MainActor
    func testAllPrimaryAndSecondarySectionsStayMountedForFastSwitching() {
        XCTAssertEqual(
            MainWindowPagePersistencePolicy.persistentSections,
            [.home, .collaboration, .data, .speech, .permissions, .settings, .about]
        )
    }
}
