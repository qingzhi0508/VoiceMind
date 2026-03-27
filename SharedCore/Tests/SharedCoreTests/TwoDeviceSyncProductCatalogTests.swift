import XCTest
@testable import SharedCore

final class TwoDeviceSyncProductCatalogTests: XCTestCase {
    func testAllKnownProductIDsIncludeIOSAndMacAliases() {
        XCTAssertEqual(
            Set(TwoDeviceSyncProductKind.allProductIDs),
            Set([
                "com.voicemind.twodevice.monthly",
                "com.voicemind.twodevice.monthly.mac",
                "com.voicemind.twodevice.yearly",
                "com.voicemind.twodevice.yearly.mac",
                "com.voicemind.twodevice.alllifetime",
                "com.voicemind.twodevice.alllifetime.mac",
            ])
        )
    }

    func testKindResolutionAcceptsBothIOSAndMacProductIDs() {
        XCTAssertEqual(
            TwoDeviceSyncProductKind.kind(for: "com.voicemind.twodevice.monthly"),
            .monthly
        )
        XCTAssertEqual(
            TwoDeviceSyncProductKind.kind(for: "com.voicemind.twodevice.monthly.mac"),
            .monthly
        )
        XCTAssertEqual(
            TwoDeviceSyncProductKind.kind(for: "com.voicemind.twodevice.yearly"),
            .yearly
        )
        XCTAssertEqual(
            TwoDeviceSyncProductKind.kind(for: "com.voicemind.twodevice.yearly.mac"),
            .yearly
        )
        XCTAssertEqual(
            TwoDeviceSyncProductKind.kind(for: "com.voicemind.twodevice.alllifetime"),
            .lifetime
        )
        XCTAssertEqual(
            TwoDeviceSyncProductKind.kind(for: "com.voicemind.twodevice.alllifetime.mac"),
            .lifetime
        )
    }

    func testPreferredProductIDMatchesCurrentPlatform() {
        #if os(macOS)
        XCTAssertEqual(TwoDeviceSyncProductKind.monthly.rawValue, "com.voicemind.twodevice.monthly.mac")
        XCTAssertEqual(TwoDeviceSyncProductKind.yearly.rawValue, "com.voicemind.twodevice.yearly.mac")
        XCTAssertEqual(TwoDeviceSyncProductKind.lifetime.rawValue, "com.voicemind.twodevice.alllifetime.mac")
        #else
        XCTAssertEqual(TwoDeviceSyncProductKind.monthly.rawValue, "com.voicemind.twodevice.monthly")
        XCTAssertEqual(TwoDeviceSyncProductKind.yearly.rawValue, "com.voicemind.twodevice.yearly")
        XCTAssertEqual(TwoDeviceSyncProductKind.lifetime.rawValue, "com.voicemind.twodevice.alllifetime")
        #endif
    }

    func testBestAvailableProductIDPrefersCurrentPlatformAndFallsBackToAlias() {
        #if os(macOS)
        XCTAssertEqual(
            TwoDeviceSyncProductKind.monthly.bestAvailableProductID(
                in: [
                    "com.voicemind.twodevice.monthly",
                    "com.voicemind.twodevice.monthly.mac",
                ]
            ),
            "com.voicemind.twodevice.monthly.mac"
        )
        XCTAssertEqual(
            TwoDeviceSyncProductKind.monthly.bestAvailableProductID(
                in: ["com.voicemind.twodevice.monthly"]
            ),
            "com.voicemind.twodevice.monthly"
        )
        #else
        XCTAssertEqual(
            TwoDeviceSyncProductKind.monthly.bestAvailableProductID(
                in: [
                    "com.voicemind.twodevice.monthly",
                    "com.voicemind.twodevice.monthly.mac",
                ]
            ),
            "com.voicemind.twodevice.monthly"
        )
        XCTAssertEqual(
            TwoDeviceSyncProductKind.monthly.bestAvailableProductID(
                in: ["com.voicemind.twodevice.monthly.mac"]
            ),
            "com.voicemind.twodevice.monthly.mac"
        )
        #endif
    }
}
