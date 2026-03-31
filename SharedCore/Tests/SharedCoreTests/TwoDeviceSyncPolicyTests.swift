import XCTest
@testable import SharedCore

final class TwoDeviceSyncPolicyTests: XCTestCase {
    private func date(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)!
    }

    func testFreeUsersAreBlockedAfterReachingDailyLimit() throws {
        let timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let now = date("2026-03-26T00:00:00+08:00")
        let record = TwoDeviceSyncUsageRecord(
            dayKey: TwoDeviceSyncPolicy.dayKey(for: now, timeZone: timeZone),
            sessionCount: 50
        )

        let state = TwoDeviceSyncPolicy.accessState(
            entitlement: .free,
            usageRecord: record,
            now: now,
            freeSessionLimit: 50,
            timeZone: timeZone
        )

        XCTAssertEqual(state, .blocked(limit: 50))
    }

    func testPaidUsersAlwaysHaveUnlimitedAccess() throws {
        let timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let now = date("2026-03-26T00:00:00+08:00")
        let record = TwoDeviceSyncUsageRecord(dayKey: "2026-03-26", sessionCount: 50)

        let state = TwoDeviceSyncPolicy.accessState(
            entitlement: .yearly,
            usageRecord: record,
            now: now,
            freeSessionLimit: 50,
            timeZone: timeZone
        )

        XCTAssertEqual(state, .unlimited)
    }

    func testRegisteringSuccessfulFreeSessionIncrementsUsage() throws {
        let timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let now = date("2026-03-26T00:00:00+08:00")

        let updated = TwoDeviceSyncPolicy.registerSuccessfulSession(
            entitlement: .free,
            usageRecord: TwoDeviceSyncUsageRecord(dayKey: "2026-03-26", sessionCount: 3),
            now: now,
            freeSessionLimit: 50,
            timeZone: timeZone
        )

        XCTAssertEqual(updated, TwoDeviceSyncUsageRecord(dayKey: "2026-03-26", sessionCount: 4))
    }

    func testRegisteringSessionResetsCountOnNewDay() throws {
        let timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let now = date("2026-03-27T00:00:00+08:00")

        let updated = TwoDeviceSyncPolicy.registerSuccessfulSession(
            entitlement: .free,
            usageRecord: TwoDeviceSyncUsageRecord(dayKey: "2026-03-26", sessionCount: 50),
            now: now,
            freeSessionLimit: 50,
            timeZone: timeZone
        )

        XCTAssertEqual(updated, TwoDeviceSyncUsageRecord(dayKey: "2026-03-27", sessionCount: 1))
    }
}
