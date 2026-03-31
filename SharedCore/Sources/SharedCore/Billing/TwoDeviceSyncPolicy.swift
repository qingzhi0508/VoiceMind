import Foundation

public enum TwoDeviceSyncEntitlement: Equatable {
    case free
    case monthly
    case yearly
    case lifetime

    public var hasUnlimitedSessions: Bool {
        self != .free
    }
}

public struct TwoDeviceSyncUsageRecord: Codable, Equatable {
    public let dayKey: String
    public let sessionCount: Int

    public init(dayKey: String, sessionCount: Int) {
        self.dayKey = dayKey
        self.sessionCount = sessionCount
    }
}

public enum TwoDeviceSyncAccessState: Equatable {
    case unlimited
    case limited(remaining: Int, used: Int)
    case blocked(limit: Int)
}

public enum TwoDeviceSyncPolicy {
    public static let defaultFreeSessionLimit = 50
    public static let defaultTimeZoneIdentifier = "Asia/Shanghai"

    public static func dayKey(for date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    public static func accessState(
        entitlement: TwoDeviceSyncEntitlement,
        usageRecord: TwoDeviceSyncUsageRecord?,
        now: Date,
        freeSessionLimit: Int = defaultFreeSessionLimit,
        timeZone: TimeZone = TimeZone(identifier: defaultTimeZoneIdentifier) ?? .current
    ) -> TwoDeviceSyncAccessState {
        guard !entitlement.hasUnlimitedSessions else {
            return .unlimited
        }

        let normalized = normalizedUsageRecord(
            usageRecord,
            now: now,
            timeZone: timeZone
        )

        if normalized.sessionCount >= freeSessionLimit {
            return .blocked(limit: freeSessionLimit)
        }

        return .limited(
            remaining: max(0, freeSessionLimit - normalized.sessionCount),
            used: normalized.sessionCount
        )
    }

    public static func registerSuccessfulSession(
        entitlement: TwoDeviceSyncEntitlement,
        usageRecord: TwoDeviceSyncUsageRecord?,
        now: Date,
        freeSessionLimit: Int = defaultFreeSessionLimit,
        timeZone: TimeZone = TimeZone(identifier: defaultTimeZoneIdentifier) ?? .current
    ) -> TwoDeviceSyncUsageRecord? {
        guard !entitlement.hasUnlimitedSessions else {
            return usageRecord
        }

        let normalized = normalizedUsageRecord(
            usageRecord,
            now: now,
            timeZone: timeZone
        )

        guard normalized.sessionCount < freeSessionLimit else {
            return normalized
        }

        return TwoDeviceSyncUsageRecord(
            dayKey: normalized.dayKey,
            sessionCount: normalized.sessionCount + 1
        )
    }

    public static func normalizedUsageRecord(
        _ usageRecord: TwoDeviceSyncUsageRecord?,
        now: Date,
        timeZone: TimeZone = TimeZone(identifier: defaultTimeZoneIdentifier) ?? .current
    ) -> TwoDeviceSyncUsageRecord {
        let currentDayKey = dayKey(for: now, timeZone: timeZone)
        guard let usageRecord, usageRecord.dayKey == currentDayKey else {
            return TwoDeviceSyncUsageRecord(dayKey: currentDayKey, sessionCount: 0)
        }

        return usageRecord
    }
}
