import Foundation
import Testing
@testable import VoiceMind

struct SettingsMembershipLinkPolicyTests {
    @Test
    func privacyPolicyURLMatchesConfiguredDestination() {
        #expect(
            SettingsMembershipLinkPolicy.privacyPolicyURL ==
            URL(string: "https://voicemind.top-list.top/privacy.html")
        )
    }

    @Test
    func termsOfUseURLMatchesConfiguredDestination() {
        #expect(
            SettingsMembershipLinkPolicy.termsOfUseURL ==
            URL(string: "https://voicemind.top-list.top/terms.html")
        )
    }
}
