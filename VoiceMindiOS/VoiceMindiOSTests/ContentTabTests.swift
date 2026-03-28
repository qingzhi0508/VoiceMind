import Testing
@testable import VoiceMind

struct ContentTabTests {
    @Test
    func appTabsAppearInExpectedOrder() {
        #expect(ContentTab.allCases == [.home, .data, .settings])
    }

    @Test
    func defaultTabIsHome() {
        #expect(ContentTab.defaultTab == .home)
    }

    @Test
    func tabsUseFilledSystemIcons() {
        #expect(ContentTab.home.systemImage == "house.fill")
        #expect(ContentTab.data.systemImage == "tray.full.fill")
        #expect(ContentTab.settings.systemImage == "gearshape.fill")
    }

    @Test
    func pairingSuccessAlwaysReturnsToHomeTab() {
        #expect(
            PairingSuccessNavigationPolicy.destinationTab(
                currentTab: .settings,
                pairingState: .paired(deviceId: "mac-1", deviceName: "MacBook Pro")
            ) == .home
        )
        #expect(
            PairingSuccessNavigationPolicy.destinationTab(
                currentTab: .data,
                pairingState: .unpaired
            ) == .data
        )
    }
}
