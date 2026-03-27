import Foundation

public protocol TwoDeviceSyncUsageStoring {
    func loadUsageRecord() throws -> TwoDeviceSyncUsageRecord?
    func saveUsageRecord(_ record: TwoDeviceSyncUsageRecord) throws
}

public final class KeychainTwoDeviceSyncUsageStore: TwoDeviceSyncUsageStoring {
    private let service: String
    private let account: String

    public init(
        service: String = "com.voicemind.twodevice",
        account: String = "daily-usage"
    ) {
        self.service = service
        self.account = account
    }

    public func loadUsageRecord() throws -> TwoDeviceSyncUsageRecord? {
        do {
            let data = try KeychainManager.retrieveData(service: service, account: account)
            return try JSONDecoder().decode(TwoDeviceSyncUsageRecord.self, from: data)
        } catch KeychainError.itemNotFound {
            return nil
        } catch {
            return nil
        }
    }

    public func saveUsageRecord(_ record: TwoDeviceSyncUsageRecord) throws {
        let data = try JSONEncoder().encode(record)
        try KeychainManager.saveData(data, service: service, account: account)
    }
}

public final class TwoDeviceSyncUsageLimiter {
    private let store: TwoDeviceSyncUsageStoring
    private let freeSessionLimit: Int
    private let timeZone: TimeZone
    private let nowProvider: () -> Date

    public init(
        store: TwoDeviceSyncUsageStoring = KeychainTwoDeviceSyncUsageStore(),
        freeSessionLimit: Int = TwoDeviceSyncPolicy.defaultFreeSessionLimit,
        timeZone: TimeZone = TimeZone(identifier: TwoDeviceSyncPolicy.defaultTimeZoneIdentifier) ?? .current,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.freeSessionLimit = freeSessionLimit
        self.timeZone = timeZone
        self.nowProvider = nowProvider
    }

    public func accessState(entitlement: TwoDeviceSyncEntitlement) -> TwoDeviceSyncAccessState {
        TwoDeviceSyncPolicy.accessState(
            entitlement: entitlement,
            usageRecord: try? store.loadUsageRecord(),
            now: nowProvider(),
            freeSessionLimit: freeSessionLimit,
            timeZone: timeZone
        )
    }

    @discardableResult
    public func recordSuccessfulSession(
        entitlement: TwoDeviceSyncEntitlement
    ) throws -> TwoDeviceSyncAccessState {
        let usageRecord = try? store.loadUsageRecord()
        guard let updatedRecord = TwoDeviceSyncPolicy.registerSuccessfulSession(
            entitlement: entitlement,
            usageRecord: usageRecord,
            now: nowProvider(),
            freeSessionLimit: freeSessionLimit,
            timeZone: timeZone
        ) else {
            return .unlimited
        }

        try store.saveUsageRecord(updatedRecord)

        return TwoDeviceSyncPolicy.accessState(
            entitlement: entitlement,
            usageRecord: updatedRecord,
            now: nowProvider(),
            freeSessionLimit: freeSessionLimit,
            timeZone: timeZone
        )
    }
}
