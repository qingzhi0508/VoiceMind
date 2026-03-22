import XCTest
@testable import VoiceMind

final class SidebarNavigationInteractionPolicyTests: XCTestCase {
    func testSidebarNavigationUsesCustomHitTargetWithoutSystemButtonFocusRing() {
        XCTAssertFalse(SidebarNavigationInteractionPolicy.usesNativeButtonFocusRing)
    }
}
