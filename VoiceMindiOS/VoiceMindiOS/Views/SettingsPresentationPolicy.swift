import SharedCore

enum SettingsMembershipPresentationPolicy {
    enum HeaderPresentation: Equatable {
        case regularUser
        case memberUser
    }

    static let accountDestinationTitleKey = "settings_account_membership_title"
    static let rootHeaderTitleKey = "settings_account_membership_title"

    static func headerPresentation(isPaidUser: Bool) -> HeaderPresentation {
        isPaidUser ? .memberUser : .regularUser
    }

    static func headerPresentation(for entitlement: TwoDeviceSyncEntitlement) -> HeaderPresentation {
        headerPresentation(isPaidUser: entitlement.hasUnlimitedSessions)
    }
}

enum SettingsInformationHierarchyPolicy {
    enum RootSection: Hashable {
        case status
        case pairing
        case appearance
        case support
    }

    enum PairingItem: Hashable {
        case sendToMac
        case connection
    }

    enum AppearanceItem: Hashable {
        case theme
        case language
    }

    enum SupportItem: Hashable {
        case permissions
        case help
        case logs
        case version
    }

    static let rootSections: [RootSection] = [
        .status,
        .pairing,
        .appearance,
        .support
    ]

    static let pairingItems: [PairingItem] = [
        .sendToMac,
        .connection
    ]

    static let appearanceItems: [AppearanceItem] = [
        .theme,
        .language
    ]

    static let supportItems: [SupportItem] = [
        .permissions,
        .help,
        .logs,
        .version
    ]
}
