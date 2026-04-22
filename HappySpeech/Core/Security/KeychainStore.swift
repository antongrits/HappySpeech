import Foundation
import Security

// MARK: - KeychainStoreProtocol

/// Protocol-oriented Keychain facade used by API clients to load/store secrets.
public protocol KeychainStoreProtocol: Sendable {
    func read(service: String, account: String) -> String?
    @discardableResult
    func write(_ value: String, service: String, account: String) -> Bool
    @discardableResult
    func delete(service: String, account: String) -> Bool
}

// MARK: - KeychainStore

/// Thin wrapper over Security Framework Keychain services.
/// Uses `kSecClassGenericPassword`. No iCloud sync — device-local only.
public struct KeychainStore: KeychainStoreProtocol {

    public init() {}

    public func read(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    public func write(_ value: String, service: String, account: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    public func delete(service: String, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}

// MARK: - KeychainKey

/// Strongly-typed Keychain coordinates so call sites stay compact.
public struct KeychainKey: Sendable, Hashable {
    public let service: String
    public let account: String

    public init(service: String, account: String) {
        self.service = service
        self.account = account
    }

    public static let anthropicAPIToken  = KeychainKey(service: "ru.happyspeech.anthropic", account: "api-token")
    public static let huggingFaceToken   = KeychainKey(service: "ru.happyspeech.hf",        account: "inference-token")
}

public extension KeychainStoreProtocol {
    func read(_ key: KeychainKey) -> String? {
        read(service: key.service, account: key.account)
    }
    @discardableResult
    func write(_ value: String, for key: KeychainKey) -> Bool {
        write(value, service: key.service, account: key.account)
    }
    @discardableResult
    func delete(_ key: KeychainKey) -> Bool {
        delete(service: key.service, account: key.account)
    }
}
