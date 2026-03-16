import XCTest
import CryptoKit
@testable import SharedCore

final class HMACValidatorTests: XCTestCase {
    func testHMACGeneration() throws {
        let key = SymmetricKey(size: .bits256)
        let validator = HMACValidator(key: key)

        let message = "test message"
        let hmac = validator.generateHMAC(for: message)

        XCTAssertFalse(hmac.isEmpty)
        XCTAssertEqual(hmac.count, 64) // SHA256 hex string length
    }

    func testHMACValidation() throws {
        let key = SymmetricKey(size: .bits256)
        let validator = HMACValidator(key: key)

        let message = "test message"
        let hmac = validator.generateHMAC(for: message)

        XCTAssertTrue(validator.validateHMAC(hmac, for: message))
    }

    func testHMACValidationFailsWithWrongMessage() throws {
        let key = SymmetricKey(size: .bits256)
        let validator = HMACValidator(key: key)

        let message = "test message"
        let hmac = validator.generateHMAC(for: message)

        XCTAssertFalse(validator.validateHMAC(hmac, for: "different message"))
    }

    func testHMACValidationFailsWithWrongKey() throws {
        let key1 = SymmetricKey(size: .bits256)
        let key2 = SymmetricKey(size: .bits256)

        let validator1 = HMACValidator(key: key1)
        let validator2 = HMACValidator(key: key2)

        let message = "test message"
        let hmac = validator1.generateHMAC(for: message)

        XCTAssertFalse(validator2.validateHMAC(hmac, for: message))
    }
}
