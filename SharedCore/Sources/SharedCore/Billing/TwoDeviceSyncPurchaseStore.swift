import Combine
import Foundation
import StoreKit

public enum TwoDeviceSyncProductKind: String, CaseIterable {
    case monthly = "com.voicemind.twodevice.monthly"
    case yearly = "com.voicemind.twodevice.yearly"
    case lifetime = "com.voicemind.twodevice.lifetime"
}

@MainActor
public final class TwoDeviceSyncPurchaseStore: ObservableObject {
    public static let shared = TwoDeviceSyncPurchaseStore()

    @Published public private(set) var entitlement: TwoDeviceSyncEntitlement = .free
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
            let fetchedProducts = try await Product.products(for: TwoDeviceSyncProductKind.allCases.map(\.rawValue))
            products = fetchedProducts.sorted { lhs, rhs in
                guard let left = TwoDeviceSyncProductKind(rawValue: lhs.id),
                      let right = TwoDeviceSyncProductKind(rawValue: rhs.id) else {
                    return lhs.id < rhs.id
                }

                return sortOrder(for: left) < sortOrder(for: right)
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func refreshEntitlement() async {
        lastErrorMessage = nil
        var resolvedEntitlement: TwoDeviceSyncEntitlement = .free

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard let kind = TwoDeviceSyncProductKind(rawValue: transaction.productID) else { continue }

            switch mapEntitlement(for: kind) {
            case .lifetime:
                resolvedEntitlement = .lifetime
            case .yearly:
                if resolvedEntitlement != .lifetime {
                    resolvedEntitlement = .yearly
                }
            case .monthly:
                if resolvedEntitlement == .free {
                    resolvedEntitlement = .monthly
                }
            case .free:
                break
            }
        }

        entitlement = resolvedEntitlement
    }

    public func purchase(_ kind: TwoDeviceSyncProductKind) async -> Bool {
        lastErrorMessage = nil
        guard let product = products.first(where: { $0.id == kind.rawValue }) else {
            await refreshProducts()
            guard let refreshedProduct = products.first(where: { $0.id == kind.rawValue }) else {
                lastErrorMessage = "Product unavailable."
                return false
            }
            return await purchase(product: refreshedProduct)
        }

        return await purchase(product: product)
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

    private func purchase(product: Product) async -> Bool {
        activePurchaseProductID = product.id
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
