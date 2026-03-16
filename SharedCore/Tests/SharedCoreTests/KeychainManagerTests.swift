import XCTest
@testable import SharedCore

final class KeychainManagerTests: XCTestCase {
    let testService = "com.voicerelay.test"
    let testAccount = "test-pairing"

    override func tearDown() {
        super.tearDown()
        // Clean up test keychain items
        try? KeychainManager.delete(service: testService, account: testAccount)
    }

    func testSaveAndRetrievePairing() throws {
        let pairing = PairingData(
            deviceId: "test-device-123",
            deviceName: "Test Device",
            sharedSecret: "test-secret-key"
        )

        try KeychainManager.savePairing(pairing, service: testService, account: testAccount)
        let retrieved = try KeychainManager.retrievePairing(service: testService, account: testAccount)

        XCTAssertEqual(retrieved.deviceId, "test-device-123")
        XCTAssertEqual(retrieved.deviceName, "Test Device")
        XCTAssertEqual(retrieved.sharedSecret, "test-secret-key")
    }

    func testDeletePairing() throws {
        let pairing = PairingData(
            deviceId: "test-device-456",
            deviceName: "Test Device 2",
            sharedSecret: "test-secret-key-2"
        )

        try KeychainManager.savePairing(pairing, service: testService, account: testAccount)
        try KeychainManager.delete(service: testService, account: testAccount)

        XCTAssertThrowsError(try KeychainManager.retrievePairing(service: testService, account: testAccount))
    }
}
