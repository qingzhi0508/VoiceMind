import XCTest
@testable import VoiceMind

final class ConnectionManagerTests: XCTestCase {
    func testUsesVoiceMindKeychainServiceName() {
        XCTAssertEqual(ConnectionManager.keychainServiceName, "com.voicemind.mac")
    }
}
