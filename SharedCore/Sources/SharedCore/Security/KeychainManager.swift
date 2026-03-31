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
        try saveData(data, service: service, account: account)
    }

    public static func saveString(
        _ value: String,
        service: String,
        account: String
    ) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try saveData(data, service: service, account: account)
    }

    public static func retrievePairing(
        service: String,
        account: String
    ) throws -> PairingData {
        let data = try retrieveData(service: service, account: account)
        let decoder = JSONDecoder()
        return try decoder.decode(PairingData.self, from: data)
    }

    public static func retrieveString(
        service: String,
        account: String
    ) throws -> String {
        let data = try retrieveData(service: service, account: account)
        guard let value = String(data: data, encoding: .utf8), !value.isEmpty else {
            throw KeychainError.invalidData
        }
        return value
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
            try saveDataFallback(data, service: service, account: account)
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
            return try retrieveDataFallback(service: service, account: account)
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        return data
    }

    private static func saveDataFallback(
        _ data: Data,
        service: String,
        account: String
    ) throws {
        UserDefaults.standard.set(data, forKey: fallbackKey(service: service, account: account))
    }

    private static func retrieveDataFallback(
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
