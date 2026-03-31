import Foundation
import Testing
@testable import VoiceMind

struct SettingsSupportLinkPolicyTests {
    @Test
    func supportEmailURLMatchesConfiguredRecipientAndSubject() {
        #expect(
            SettingsSupportLinkPolicy.supportEmailURL ==
            URL(string: "mailto:voicemind@top-list.top?subject=voicemind%20%E6%94%AF%E6%8C%81")
        )
    }
}
