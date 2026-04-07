import Foundation
import SharedCore

enum SettingsMembershipPresentationPolicy {
    enum HeaderPresentation: Equatable {
        case regularUser
        case memberUser
    }

    static let accountDestinationTitleKey = "settings_account_membership_title"
    static let rootHeaderTitleKey = "settings_account_membership_title"
    static let benefitTitleKeys = [
        "billing_membership_benefit_unlimited",
        "billing_membership_benefit_batch",
        "billing_membership_benefit_workspace",
        "billing_membership_benefit_updates",
        "billing_membership_benefit_sync"
    ]

    static func headerPresentation(isPaidUser: Bool) -> HeaderPresentation {
        isPaidUser ? .memberUser : .regularUser
    }

    static func headerPresentation(for entitlement: TwoDeviceSyncEntitlement) -> HeaderPresentation {
        headerPresentation(isPaidUser: entitlement.hasUnlimitedSessions)
    }
}

enum SettingsMembershipValidityPolicy {
    static func description(
        entitlement: TwoDeviceSyncEntitlement,
        expirationDate: Date?,
        formattedDate: String?
    ) -> String? {
        switch entitlement {
        case .free:
            return nil
        case .lifetime:
            return "billing_two_device_sync_validity_lifetime"
        case .monthly, .yearly:
            guard expirationDate != nil, formattedDate != nil else {
                return nil
            }
            return "billing_two_device_sync_validity_until_format"
        }
    }
}

enum SettingsMembershipPurchasePolicy {
    static func visibleProductKinds(
        for entitlement: TwoDeviceSyncEntitlement,
        availableProductIDs _: [String]
    ) -> [TwoDeviceSyncProductKind] {
        let preferredKinds: [TwoDeviceSyncProductKind]
        switch entitlement {
        case .lifetime:
            preferredKinds = [.lifetime]
        case .free, .monthly, .yearly:
            preferredKinds = [.monthly, .yearly, .lifetime]
        }

        return preferredKinds
    }

    static func ownedProductKind(
        for entitlement: TwoDeviceSyncEntitlement
    ) -> TwoDeviceSyncProductKind? {
        switch entitlement {
        case .free:
            return nil
        case .monthly:
            return .monthly
        case .yearly:
            return .yearly
        case .lifetime:
            return .lifetime
        }
    }

    static func defaultSelectedProductKind(
        activeEntitlement: TwoDeviceSyncEntitlement,
        availableProductIDs: [String]
    ) -> TwoDeviceSyncProductKind {
        if let ownedProductKind = ownedProductKind(for: activeEntitlement) {
            return ownedProductKind
        }

        let visibleKinds = visibleProductKinds(
            for: activeEntitlement,
            availableProductIDs: availableProductIDs
        )
        let availableKinds = Set(availableProductIDs.compactMap(TwoDeviceSyncProductKind.init(rawValue:)))

        if let firstAvailableVisibleKind = visibleKinds.first(where: { availableKinds.contains($0) }) {
            return firstAvailableVisibleKind
        }

        return visibleKinds.first ?? .monthly
    }

    static func isPurchaseDisabled(
        productKind: TwoDeviceSyncProductKind,
        activeEntitlement: TwoDeviceSyncEntitlement,
        activePurchaseProductID: String?,
        locallyPendingProductID: String?,
        isRestoringPurchases: Bool
    ) -> Bool {
        ownedProductKind(for: activeEntitlement) == productKind ||
        activePurchaseProductID != nil ||
        locallyPendingProductID != nil ||
        isRestoringPurchases
    }

    static func buttonTitleKey(
        for _: TwoDeviceSyncProductKind,
        activeEntitlement _: TwoDeviceSyncEntitlement
    ) -> String? {
        nil
    }

    static func isRestoreDisabled(
        activePurchaseProductID: String?,
        locallyPendingProductID: String?,
        isRestoringPurchases: Bool,
        isLocallyRestoringPurchases: Bool
    ) -> Bool {
        activePurchaseProductID != nil ||
        locallyPendingProductID != nil ||
        isRestoringPurchases ||
        isLocallyRestoringPurchases
    }
}

enum SettingsInformationHierarchyPolicy {
    enum RootSection: Hashable {
        case status
        case pairing
        case appearance
        case support
        case about
    }

    enum PairingItem: Hashable {
        case sendToMac
        case connection
    }

    enum AppearanceItem: Hashable {
        case theme
        case lightBackgroundColor
        case language
    }

    enum SupportItem: Hashable {
        case permissions
        case help
        case supportEmail
        case termsOfUse
        case privacyPolicy
        case logs
        case version
    }

    enum AboutItem: Hashable {
        case website
    }

    static let rootSections: [RootSection] = [
        .status,
        .pairing,
        .appearance,
        .support,
        .about
    ]

    static let pairingItems: [PairingItem] = [
        .sendToMac,
        .connection
    ]

    static let appearanceItems: [AppearanceItem] = [
        .theme,
        .lightBackgroundColor,
        .language
    ]

    static let supportItems: [SupportItem] = [
        .permissions,
        .help,
        .supportEmail,
        .termsOfUse,
        .privacyPolicy,
        .logs,
        .version
    ]
}

enum SettingsAppearancePresentationPolicy {
    static func showsLightBackgroundColor(appTheme: String) -> Bool {
        appTheme == "light"
    }

    static func visibleItems(appTheme: String) -> [SettingsInformationHierarchyPolicy.AppearanceItem] {
        SettingsInformationHierarchyPolicy.appearanceItems.filter { item in
            switch item {
            case .lightBackgroundColor:
                return showsLightBackgroundColor(appTheme: appTheme)
            case .theme, .language:
                return true
            }
        }
    }
}

enum SettingsMembershipLinkPolicy {
    static let websiteURL = URL(string: "https://voicemind.top-list.top")

    static let termsOfUseURL = URL(string: "https://voicemind.top-list.top/terms.html")

    static let privacyPolicyURL = URL(string: "https://voicemind.top-list.top/privacy.html")
}

enum SettingsSupportLinkPolicy {
    static let supportEmailRecipient = "voicemind@top-list.top"
    static let supportEmailSubject = "voicemind 支持"

    static let supportEmailURL: URL? = {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmailRecipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: supportEmailSubject)
        ]
        return components.url
    }()
}
