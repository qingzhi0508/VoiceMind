import Testing
@testable import VoiceMind

struct DiscoveredServiceIdentityPolicyTests {
    @Test
    func serviceIdentityIsStableForSameHostPortAndName() {
        let first = DiscoveredService(name: "VoiceMind Mac", host: "192.168.1.8", port: 18661)
        let second = DiscoveredService(name: "VoiceMind Mac", host: "192.168.1.8", port: 18661)

        #expect(first.id == second.id)
    }

    @Test
    func serviceIdentityChangesWhenEndpointChanges() {
        let first = DiscoveredService(name: "VoiceMind Mac", host: "192.168.1.8", port: 18661)
        let second = DiscoveredService(name: "VoiceMind Mac", host: "192.168.1.9", port: 18661)

        #expect(first.id != second.id)
    }
}
