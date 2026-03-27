import Combine
import Foundation
import StoreKit

public enum TwoDeviceSyncProductKind: String, CaseIterable {
    #if os(macOS)
    case monthly = "com.voicemind.twodevice.monthly.mac"
    case yearly = "com.voicemind.twodevice.yearly.mac"
    case lifetime = "com.voicemind.twodevice.alllifetime.mac"
    #else
    case monthly = "com.voicemind.twodevice.monthly"
    case yearly = "com.voicemind.twodevice.yearly"
    case lifetime = "com.voicemind.twodevice.alllifetime"
    #endif

    public var iOSProductID: String {
        switch self {
        case .monthly:
            return "com.voicemind.twodevice.monthly"
        case .yearly:
            return "com.voicemind.twodevice.yearly"
        case .lifetime:
            return "com.voicemind.twodevice.alllifetime"
        }
    }

    public var macProductID: String {
        switch self {
        case .monthly:
            return "com.voicemind.twodevice.monthly.mac"
        case .yearly:
            return "com.voicemind.twodevice.yearly.mac"
        case .lifetime:
            return "com.voicemind.twodevice.alllifetime.mac"
        }
    }

    public var productIDs: [String] {
        [rawValue, iOSProductID, macProductID]
            .reduce(into: [String]()) { ids, productID in
                guard !ids.contains(productID) else { return }
                ids.append(productID)
            }
    }

    public static var allProductIDs: [String] {
        allCases.reduce(into: [String]()) { ids, kind in
            for productID in kind.productIDs where !ids.contains(productID) {
                ids.append(productID)
            }
        }
    }

    public static func kind(for productID: String) -> Self? {
        allCases.first(where: { $0.productIDs.contains(productID) })
    }

    public func bestAvailableProductID<S: Sequence>(in productIDs: S) -> String? where S.Element == String {
        let availableProductIDs = Set(productIDs)

        if availableProductIDs.contains(rawValue) {
            return rawValue
        }

        return self.productIDs.first(where: availableProductIDs.contains)
    }
}

@MainActor
public final class TwoDeviceSyncPurchaseStore: ObservableObject {
    public static let shared = TwoDeviceSyncPurchaseStore()

    @Published public private(set) var entitlement: TwoDeviceSyncEntitlement = .free
    @Published public private(set) var entitlementExpirationDate: Date?
    @Published public private(set) var products: [Product] = []
    @Published public private(set) var isLoadingProducts = false
    @Published public private(set) var isRestoringPurchases = false
    @Published public private(set) var activePurchaseProductID: String?
    @Published public var lastErrorMessage: String?

    private var updatesTask: Task<Void, Never>?

    public init() {}

    deinit {
        updatesTask?.cancel()
    }

    public var hasUnlimitedAccess: Bool {
        entitlement.hasUnlimitedSessions
    }

    public func prepare() async {
        startObservingTransactionsIfNeeded()
        await refreshProducts()
        await refreshEntitlement()
    }

    public func refreshProducts() async {
        lastErrorMessage = nil
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let fetchedProducts = try await Product.products(for: TwoDeviceSyncProductKind.allProductIDs)
            let availableProductIDs = fetchedProducts.map(\.id)

            products = TwoDeviceSyncProductKind.allCases.compactMap { kind in
                guard let productID = kind.bestAvailableProductID(in: availableProductIDs) else {
                    return nil
                }

                return fetchedProducts.first(where: { $0.id == productID })
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func refreshEntitlement() async {
        lastErrorMessage = nil
        var resolvedEntitlement: TwoDeviceSyncEntitlement = .free
        var resolvedExpirationDate: Date?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard let kind = TwoDeviceSyncProductKind.kind(for: transaction.productID) else { continue }
            let candidateExpirationDate = transaction.expirationDate

            switch mapEntitlement(for: kind) {
            case .lifetime:
                resolvedEntitlement = .lifetime
                resolvedExpirationDate = nil
            case .yearly:
                if resolvedEntitlement != .lifetime {
                    resolvedEntitlement = .yearly
                    resolvedExpirationDate = maxDate(resolvedExpirationDate, candidateExpirationDate)
                }
            case .monthly:
                if resolvedEntitlement == .free {
                    resolvedEntitlement = .monthly
                    resolvedExpirationDate = candidateExpirationDate
                } else if resolvedEntitlement == .monthly {
                    resolvedExpirationDate = maxDate(resolvedExpirationDate, candidateExpirationDate)
                }
            case .free:
                break
            }
        }

        entitlement = resolvedEntitlement
        entitlementExpirationDate = resolvedExpirationDate
    }

    public func purchase(_ kind: TwoDeviceSyncProductKind) async -> Bool {
        lastErrorMessage = nil
        guard let product = product(for: kind) else {
            await refreshProducts()
            guard let refreshedProduct = product(for: kind) else {
                lastErrorMessage = "Product unavailable."
                return false
            }
            return await purchase(product: refreshedProduct, as: kind)
        }

        return await purchase(product: product, as: kind)
    }

    public func displayPrice(for kind: TwoDeviceSyncProductKind) -> String? {
        product(for: kind)?.displayPrice
    }

    public func restorePurchases() async {
        lastErrorMessage = nil
        isRestoringPurchases = true
        defer { isRestoringPurchases = false }

        do {
            try await AppStore.sync()
            await refreshEntitlement()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func purchase(product: Product, as kind: TwoDeviceSyncProductKind? = nil) async -> Bool {
        activePurchaseProductID = kind?.rawValue ?? TwoDeviceSyncProductKind.kind(for: product.id)?.rawValue ?? product.id
        defer { activePurchaseProductID = nil }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlement()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }
    }

    private func startObservingTransactionsIfNeeded() {
        guard updatesTask == nil else { return }

        updatesTask = Task { [weak self] in
            guard let self else { return }

            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self.refreshEntitlement()
            }
        }
    }

    private func product(for kind: TwoDeviceSyncProductKind) -> Product? {
        guard let productID = kind.bestAvailableProductID(in: products.map(\.id)) else {
            return nil
        }

        return products.first(where: { $0.id == productID })
    }

    private func mapEntitlement(for kind: TwoDeviceSyncProductKind) -> TwoDeviceSyncEntitlement {
        switch kind {
        case .monthly:
            return .monthly
        case .yearly:
            return .yearly
        case .lifetime:
            return .lifetime
        }
    }

    private func sortOrder(for kind: TwoDeviceSyncProductKind) -> Int {
        switch kind {
        case .monthly:
            return 0
        case .yearly:
            return 1
        case .lifetime:
            return 2
        }
    }

    private func maxDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (.some(left), .some(right)):
            return max(left, right)
        case (.some, .none):
            return lhs
        case (.none, .some):
            return rhs
        case (.none, .none):
            return nil
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw StoreError.failedVerification
        }
    }

    private enum StoreError: Error {
        case failedVerification
    }
}
