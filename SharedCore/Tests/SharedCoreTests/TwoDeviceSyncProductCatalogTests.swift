import XCTest
@testable import SharedCore

final class TwoDeviceSyncProductCatalogTests: XCTestCase {
    func testAllKnownProductIDsUseSingleUniversalCatalog() {
        XCTAssertEqual(
            Set(TwoDeviceSyncProductKind.allProductIDs),
            Set([
                "com.voicemind.twodevice.monthly",
                "com.voicemind.twodevice.yearly",
                "com.voicemind.twodevice.alllifetime",
            ])
        )
    }

    func testKindResolutionAcceptsOnlyUniversalProductIDs() {
        XCTAssertEqual(
            TwoDeviceSyncProductKind.kind(for: "com.voicemind.twodevice.monthly"),
            .monthly
        )
        XCTAssertEqual(
            TwoDeviceSyncProductKind.kind(for: "com.voicemind.twodevice.yearly"),
            .yearly
        )
        XCTAssertEqual(
            TwoDeviceSyncProductKind.kind(for: "com.voicemind.twodevice.alllifetime"),
            .lifetime
        )
        XCTAssertNil(TwoDeviceSyncProductKind.kind(for: "com.voicemind.twodevice.monthly.mac"))
        XCTAssertNil(TwoDeviceSyncProductKind.kind(for: "com.voicemind.twodevice.yearly.mac"))
        XCTAssertNil(TwoDeviceSyncProductKind.kind(for: "com.voicemind.twodevice.alllifetime.mac"))
    }

    func testPreferredProductIDIsTheSameOnEveryPlatform() {
        XCTAssertEqual(TwoDeviceSyncProductKind.monthly.rawValue, "com.voicemind.twodevice.monthly")
        XCTAssertEqual(TwoDeviceSyncProductKind.yearly.rawValue, "com.voicemind.twodevice.yearly")
        XCTAssertEqual(TwoDeviceSyncProductKind.lifetime.rawValue, "com.voicemind.twodevice.alllifetime")
    }

    func testBestAvailableProductIDReturnsOnlyUniversalCatalogMatches() {
        XCTAssertEqual(
            TwoDeviceSyncProductKind.monthly.bestAvailableProductID(
                in: [
                    "com.voicemind.twodevice.monthly",
                ]
            ),
            "com.voicemind.twodevice.monthly"
        )
        XCTAssertEqual(
            TwoDeviceSyncProductKind.monthly.bestAvailableProductID(
                in: ["com.voicemind.twodevice.monthly.mac"]
            ),
            nil
        )
        XCTAssertEqual(
            TwoDeviceSyncProductKind.lifetime.bestAvailableProductID(
                in: ["com.voicemind.twodevice.alllifetime"]
            ),
            "com.voicemind.twodevice.alllifetime"
        )
    }
}
