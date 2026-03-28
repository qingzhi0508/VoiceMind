import XCTest
import SharedCore
@testable import VoiceMind

final class MacBillingPresentationPolicyTests: XCTestCase {
    func testLifetimeEntitlementHidesUnlockOptions() {
        XCTAssertFalse(MacBillingPresentationPolicy.showsUnlockOptions(for: .lifetime))
    }

    func testRenewableAndFreeEntitlementsKeepUnlockOptionsVisible() {
        XCTAssertTrue(MacBillingPresentationPolicy.showsUnlockOptions(for: .free))
        XCTAssertTrue(MacBillingPresentationPolicy.showsUnlockOptions(for: .monthly))
        XCTAssertTrue(MacBillingPresentationPolicy.showsUnlockOptions(for: .yearly))
    }
}
