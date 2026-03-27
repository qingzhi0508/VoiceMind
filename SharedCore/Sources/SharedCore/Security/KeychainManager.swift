import Foundation
import Security

public enum KeychainError: Error {
    case itemNotFound
    case duplicateItem
    case invalidData
    case unhandledError(status: OSStatus)
}

public class KeychainManager {
    private static func fallbackKey(service: String, account: String) -> String {
        "fallback.\(service).\(account)"
    }

    public static func savePairing(
        _ pairing: PairingData,
        service: String,
        account: String
    ) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(pairing)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        // Delete existing item if present
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            try savePairingFallback(data, service: service, account: account)
            return
        }

        UserDefaults.standard.removeObject(forKey: fallbackKey(service: service, account: account))
    }

    public static func retrievePairing(
        service: String,
        account: String
    ) throws -> PairingData {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return try retrievePairingFallback(service: service, account: account)
            }
            return try retrievePairingFallback(service: service, account: account)
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        let decoder = JSONDecoder()
        return try decoder.decode(PairingData.self, from: data)
    }

    public static func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }

        UserDefaults.standard.removeObject(forKey: fallbackKey(service: service, account: account))
    }

    public static func saveData(
        _ data: Data,
        service: String,
        account: String
    ) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            try savePairingFallback(data, service: service, account: account)
            return
        }

        UserDefaults.standard.removeObject(forKey: fallbackKey(service: service, account: account))
    }

    public static func retrieveData(
        service: String,
        account: String
    ) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            return try retrievePairingFallbackData(service: service, account: account)
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        return data
    }

    private static func savePairingFallback(
        _ data: Data,
        service: String,
        account: String
    ) throws {
        UserDefaults.standard.set(data, forKey: fallbackKey(service: service, account: account))
    }

    private static func retrievePairingFallback(
        service: String,
        account: String
    ) throws -> PairingData {
        let data = try retrievePairingFallbackData(service: service, account: account)
        let decoder = JSONDecoder()
        return try decoder.decode(PairingData.self, from: data)
    }

    private static func retrievePairingFallbackData(
        service: String,
        account: String
    ) throws -> Data {
        let key = fallbackKey(service: service, account: account)
        guard let data = UserDefaults.standard.data(forKey: key) else {
            throw KeychainError.itemNotFound
        }
        return data
    }
}
