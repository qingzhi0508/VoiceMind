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
}
