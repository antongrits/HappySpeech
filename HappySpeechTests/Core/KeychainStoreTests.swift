@testable import HappySpeech
import XCTest

// MARK: - KeychainStoreTests
//
// Security-critical. Exercises the REAL KeychainStore (KeychainAccess-backed,
// kSecClassGenericPassword) against the simulator keychain. Each test uses a
// process-unique service name so runs never collide, and tearDown deletes any
// residue. Covers write/read round-trip, overwrite, delete, missing-key, the
// KeychainKey typed convenience API, and multi-account isolation.

final class KeychainStoreTests: XCTestCase {

    private var sut: KeychainStore!
    private var service: String!
    private let account = "unit-account"

    override func setUp() {
        super.setUp()
        sut = KeychainStore()
        // Unique per test method invocation to guarantee isolation across reruns.
        service = "ru.happyspeech.tests.keychain.\(UUID().uuidString)"
    }

    override func tearDown() {
        // Best-effort cleanup so the simulator keychain stays tidy.
        _ = sut.delete(service: service, account: account)
        _ = sut.delete(service: service, account: "account-A")
        _ = sut.delete(service: service, account: "account-B")
        sut = nil
        service = nil
        super.tearDown()
    }

    // MARK: - write + read round-trip

    func test_write_returnsTrue() {
        XCTAssertTrue(sut.write("secret-token", service: service, account: account))
    }

    func test_writeThenRead_returnsStoredValue() {
        _ = sut.write("secret-token", service: service, account: account)
        XCTAssertEqual(sut.read(service: service, account: account), "secret-token")
    }

    func test_read_missingKey_returnsNil() {
        XCTAssertNil(sut.read(service: service, account: "never-written"))
    }

    func test_writeEmptyString_isReadableAsEmpty() {
        _ = sut.write("", service: service, account: account)
        XCTAssertEqual(sut.read(service: service, account: account), "")
    }

    func test_writeUnicodeValue_roundTrips() {
        let value = "Привет, мир! 🦁 token-Я-Ж"
        _ = sut.write(value, service: service, account: account)
        XCTAssertEqual(sut.read(service: service, account: account), value)
    }

    // MARK: - overwrite

    func test_overwrite_replacesPreviousValue() {
        _ = sut.write("first", service: service, account: account)
        _ = sut.write("second", service: service, account: account)
        XCTAssertEqual(sut.read(service: service, account: account), "second")
    }

    func test_overwrite_returnsTrue() {
        _ = sut.write("first", service: service, account: account)
        XCTAssertTrue(sut.write("second", service: service, account: account))
    }

    // MARK: - delete

    func test_delete_removesValue() {
        _ = sut.write("to-be-deleted", service: service, account: account)
        _ = sut.delete(service: service, account: account)
        XCTAssertNil(sut.read(service: service, account: account))
    }

    func test_delete_returnsTrue() {
        _ = sut.write("to-be-deleted", service: service, account: account)
        XCTAssertTrue(sut.delete(service: service, account: account))
    }

    func test_delete_missingKey_returnsTrue() {
        // KeychainAccess.remove on an absent key does not throw → store returns true.
        XCTAssertTrue(sut.delete(service: service, account: "never-written"))
    }

    func test_readAfterDelete_returnsNil() {
        _ = sut.write("value", service: service, account: account)
        XCTAssertNotNil(sut.read(service: service, account: account))
        _ = sut.delete(service: service, account: account)
        XCTAssertNil(sut.read(service: service, account: account))
    }

    // MARK: - account isolation

    func test_distinctAccounts_areIsolated() {
        _ = sut.write("value-A", service: service, account: "account-A")
        _ = sut.write("value-B", service: service, account: "account-B")
        XCTAssertEqual(sut.read(service: service, account: "account-A"), "value-A")
        XCTAssertEqual(sut.read(service: service, account: "account-B"), "value-B")
    }

    func test_deleteOneAccount_doesNotAffectOther() {
        _ = sut.write("value-A", service: service, account: "account-A")
        _ = sut.write("value-B", service: service, account: "account-B")
        _ = sut.delete(service: service, account: "account-A")
        XCTAssertNil(sut.read(service: service, account: "account-A"))
        XCTAssertEqual(sut.read(service: service, account: "account-B"), "value-B")
    }

    // MARK: - KeychainKey typed convenience API

    func test_keychainKey_writeReadDeleteRoundTrip() {
        let store: KeychainStoreProtocol = KeychainStore()
        let key = KeychainKey(service: "ru.happyspeech.tests.\(UUID().uuidString)", account: "typed")
        defer { _ = store.delete(key) }

        XCTAssertTrue(store.write("typed-secret", for: key))
        XCTAssertEqual(store.read(key), "typed-secret")
        XCTAssertTrue(store.delete(key))
        XCTAssertNil(store.read(key))
    }

    func test_keychainKey_predefinedKeysHaveDistinctCoordinates() {
        let keys = [KeychainKey.remoteLLMAPIToken, .huggingFaceToken, .parentAuthToken]
        let coords = keys.map { "\($0.service)|\($0.account)" }
        XCTAssertEqual(Set(coords).count, keys.count)
    }

    func test_keychainKey_equatableAndHashable() {
        let a = KeychainKey(service: "svc", account: "acc")
        let b = KeychainKey(service: "svc", account: "acc")
        let c = KeychainKey(service: "svc", account: "other")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
        XCTAssertEqual(Set([a, b]).count, 1)
    }
}
