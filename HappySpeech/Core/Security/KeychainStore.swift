import Foundation
import KeychainAccess
import OSLog

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

/// Keychain wrapper backed by KeychainAccess SPM library.
/// Uses kSecClassGenericPassword. No iCloud sync — device-local only.
/// kSecAttrAccessible = afterFirstUnlockThisDeviceOnly.
public struct KeychainStore: KeychainStoreProtocol {

    private let logger = Logger(subsystem: "ru.happyspeech.app", category: "Security")

    public init() {}

    public func read(service: String, account: String) -> String? {
        let kc = Keychain(service: service).accessibility(.afterFirstUnlockThisDeviceOnly)
        do {
            return try kc.get(account)
        } catch {
            logger.warning("KeychainStore.read failed service=\(service) account=\(account): \(error.localizedDescription)")
            return nil
        }
    }

    @discardableResult
    public func write(_ value: String, service: String, account: String) -> Bool {
        let kc = Keychain(service: service).accessibility(.afterFirstUnlockThisDeviceOnly)
        do {
            try kc.set(value, key: account)
            return true
        } catch {
            logger.error("KeychainStore.write failed service=\(service) account=\(account): \(error.localizedDescription)")
            return false
        }
    }

    @discardableResult
    public func delete(service: String, account: String) -> Bool {
        let kc = Keychain(service: service)
        do {
            try kc.remove(account)
            return true
        } catch {
            logger.warning("KeychainStore.delete failed service=\(service) account=\(account): \(error.localizedDescription)")
            return false
        }
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

    public static let remoteLLMAPIToken  = KeychainKey(service: "ru.happyspeech.remotellm", account: "api-token")
    public static let huggingFaceToken   = KeychainKey(service: "ru.happyspeech.hf", account: "inference-token")
    public static let parentAuthToken    = KeychainKey(service: "ru.happyspeech.auth", account: "parent-refresh-token")
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
