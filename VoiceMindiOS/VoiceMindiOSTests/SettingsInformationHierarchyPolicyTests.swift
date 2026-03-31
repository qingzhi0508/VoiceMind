import Testing
@testable import VoiceMind

@MainActor
struct SettingsInformationHierarchyPolicyTests {
    @Test
    func rootSectionsUseTheExpectedOrder() {
        #expect(SettingsInformationHierarchyPolicy.rootSections == [.status, .pairing, .appearance, .support])
    }

    @Test
    func pairingSectionKeepsOnlySyncControlsWithConnectionManagement() {
        #expect(
            SettingsInformationHierarchyPolicy.pairingItems == [
                .sendToMac,
                .connection
            ]
        )
    }
    @Test
    func supportSectionCombinesPermissionsAndSupportEntries() {
        #expect(
            SettingsInformationHierarchyPolicy.supportItems == [
                .permissions,
                .help,
                .supportEmail,
                .logs,
                .version
            ]
        )
    }
}
