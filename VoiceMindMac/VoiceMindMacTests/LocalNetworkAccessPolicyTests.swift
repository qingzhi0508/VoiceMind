import XCTest
import Network
@testable import VoiceMind

final class LocalNetworkAccessPolicyTests: XCTestCase {
    func testRecognizesPrivateIPv4Addresses() {
        XCTAssertTrue(LocalNetworkAccessPolicy.isPrivateLANIPv4("10.0.0.8"))
        XCTAssertTrue(LocalNetworkAccessPolicy.isPrivateLANIPv4("172.16.4.2"))
        XCTAssertTrue(LocalNetworkAccessPolicy.isPrivateLANIPv4("172.31.255.254"))
        XCTAssertTrue(LocalNetworkAccessPolicy.isPrivateLANIPv4("192.168.1.5"))
    }

    func testRejectsNonPrivateIPv4Addresses() {
        XCTAssertFalse(LocalNetworkAccessPolicy.isPrivateLANIPv4("8.8.8.8"))
        XCTAssertFalse(LocalNetworkAccessPolicy.isPrivateLANIPv4("127.0.0.1"))
        XCTAssertFalse(LocalNetworkAccessPolicy.isPrivateLANIPv4("172.15.1.1"))
        XCTAssertFalse(LocalNetworkAccessPolicy.isPrivateLANIPv4("172.32.1.1"))
        XCTAssertFalse(LocalNetworkAccessPolicy.isPrivateLANIPv4("fe80::1"))
    }

    func testAllowsOnlyPrivateIPv4HostPortEndpoints() {
        let allowed = NWEndpoint.hostPort(host: "192.168.0.12", port: 8899)
        let disallowed = NWEndpoint.hostPort(host: "203.0.113.7", port: 8899)

        XCTAssertTrue(LocalNetworkAccessPolicy.isAllowedPeerEndpoint(allowed))
        XCTAssertFalse(LocalNetworkAccessPolicy.isAllowedPeerEndpoint(disallowed))
    }

    func testPrefersPrivateEnInterfacesForLocalAddress() {
        let interfaces = [
            LocalNetworkAccessPolicy.InterfaceAddress(name: "lo0", address: "127.0.0.1"),
            LocalNetworkAccessPolicy.InterfaceAddress(name: "en5", address: "203.0.113.2"),
            LocalNetworkAccessPolicy.InterfaceAddress(name: "en0", address: "192.168.31.20"),
            LocalNetworkAccessPolicy.InterfaceAddress(name: "bridge0", address: "10.0.0.3")
        ]

        XCTAssertEqual(LocalNetworkAccessPolicy.preferredLocalIPv4(from: interfaces), "192.168.31.20")
    }
}
