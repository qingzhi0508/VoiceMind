import Foundation
import Testing
import SharedCore
@testable import VoiceMind

@MainActor
struct SettingsMembershipPresentationPolicyTests {
    @Test
    func freeUsersUseRegularUserPresentationFromBothEntryPoints() {
        #expect(SettingsMembershipPresentationPolicy.headerPresentation(isPaidUser: false) == .regularUser)
        #expect(SettingsMembershipPresentationPolicy.headerPresentation(for: .free) == .regularUser)
    }

    @Test
    func paidUsersUseMemberUserPresentationFromBothEntryPoints() {
        #expect(SettingsMembershipPresentationPolicy.headerPresentation(isPaidUser: true) == .memberUser)
        #expect(SettingsMembershipPresentationPolicy.headerPresentation(for: .monthly) == .memberUser)
        #expect(SettingsMembershipPresentationPolicy.headerPresentation(for: .yearly) == .memberUser)
        #expect(SettingsMembershipPresentationPolicy.headerPresentation(for: .lifetime) == .memberUser)
    }

    @Test
    func accountDestinationUsesNeutralLabeling() {
        #expect(SettingsMembershipPresentationPolicy.accountDestinationTitleKey == "settings_account_membership_title")
        #expect(SettingsMembershipPresentationPolicy.rootHeaderTitleKey == "settings_account_membership_title")
    }

    @Test
    func lifetimeMembershipUsesPermanentValidityCopy() {
        #expect(
            SettingsMembershipValidityPolicy.description(
                entitlement: .lifetime,
                expirationDate: nil,
                formattedDate: nil
            ) == "billing_two_device_sync_validity_lifetime"
        )
    }

    @Test
    func renewableMembershipUsesExpirationCopyWhenDateExists() {
        #expect(
            SettingsMembershipValidityPolicy.description(
                entitlement: .monthly,
                expirationDate: Date(timeIntervalSince1970: 0),
                formattedDate: "1970-01-01"
            ) == "billing_two_device_sync_validity_until_format"
        )
        #expect(
            SettingsMembershipValidityPolicy.description(
                entitlement: .yearly,
                expirationDate: Date(timeIntervalSince1970: 0),
                formattedDate: "1970-01-01"
            ) == "billing_two_device_sync_validity_until_format"
        )
    }

    @Test
    func freeMembershipHasNoValidityCopy() {
        #expect(
            SettingsMembershipValidityPolicy.description(
                entitlement: .free,
                expirationDate: nil,
                formattedDate: nil
            ) == nil
        )
    }

    @Test
    func ownedProductKindMatchesCurrentEntitlement() {
        #expect(SettingsMembershipPurchasePolicy.ownedProductKind(for: .free) == nil)
        #expect(SettingsMembershipPurchasePolicy.ownedProductKind(for: .monthly) == .monthly)
        #expect(SettingsMembershipPurchasePolicy.ownedProductKind(for: .yearly) == .yearly)
        #expect(SettingsMembershipPurchasePolicy.ownedProductKind(for: .lifetime) == .lifetime)
    }

    @Test
    func purchaseButtonDisablesOnlyForOwnedPlanOrInFlightRequest() {
        #expect(
            SettingsMembershipPurchasePolicy.isPurchaseDisabled(
                productKind: .monthly,
                activeEntitlement: .monthly,
                activePurchaseProductID: nil,
                locallyPendingProductID: nil,
                isRestoringPurchases: false
            )
        )
        #expect(
            !SettingsMembershipPurchasePolicy.isPurchaseDisabled(
                productKind: .yearly,
                activeEntitlement: .monthly,
                activePurchaseProductID: nil,
                locallyPendingProductID: nil,
                isRestoringPurchases: false
            )
        )
        #expect(
            SettingsMembershipPurchasePolicy.isPurchaseDisabled(
                productKind: .yearly,
                activeEntitlement: .free,
                activePurchaseProductID: nil,
                locallyPendingProductID: TwoDeviceSyncProductKind.yearly.rawValue,
                isRestoringPurchases: false
            )
        )
    }

    @Test
    func restoreButtonDisablesDuringPurchaseOrRestore() {
        #expect(
            SettingsMembershipPurchasePolicy.isRestoreDisabled(
                activePurchaseProductID: TwoDeviceSyncProductKind.monthly.rawValue,
                locallyPendingProductID: nil,
                isRestoringPurchases: false,
                isLocallyRestoringPurchases: false
            )
        )
        #expect(
            SettingsMembershipPurchasePolicy.isRestoreDisabled(
                activePurchaseProductID: nil,
                locallyPendingProductID: nil,
                isRestoringPurchases: true,
                isLocallyRestoringPurchases: false
            )
        )
        #expect(
            !SettingsMembershipPurchasePolicy.isRestoreDisabled(
                activePurchaseProductID: nil,
                locallyPendingProductID: nil,
                isRestoringPurchases: false,
                isLocallyRestoringPurchases: false
            )
        )
    }

    @Test
    func visibleProductsHideOtherOptionsForLifetimeEntitlement() {
        #expect(
            SettingsMembershipPurchasePolicy.visibleProductKinds(
                for: .lifetime,
                availableProductIDs: TwoDeviceSyncProductKind.allCases.map(\.rawValue)
            ) == [.lifetime]
        )
        #expect(
            SettingsMembershipPurchasePolicy.visibleProductKinds(
                for: .monthly,
                availableProductIDs: TwoDeviceSyncProductKind.allCases.map(\.rawValue)
            ) == [.monthly, .yearly, .lifetime]
        )
    }

    @Test
    func ownedPlanKeepsOriginalLabel() {
        #expect(
            SettingsMembershipPurchasePolicy.buttonTitleKey(
                for: .monthly,
                activeEntitlement: .monthly
            ) == nil
        )
        #expect(
            SettingsMembershipPurchasePolicy.buttonTitleKey(
                for: .yearly,
                activeEntitlement: .monthly
            ) == nil
        )
    }

    @Test
    func visibleProductsKeepAllPurchaseOptionsEvenWhenUnavailable() {
        #expect(
            SettingsMembershipPurchasePolicy.visibleProductKinds(
                for: .free,
                availableProductIDs: [TwoDeviceSyncProductKind.monthly.rawValue, TwoDeviceSyncProductKind.yearly.rawValue]
            ) == [.monthly, .yearly, .lifetime]
        )
        #expect(
            SettingsMembershipPurchasePolicy.visibleProductKinds(
                for: .lifetime,
                availableProductIDs: []
            ) == [.lifetime]
        )
    }
}
