@testable import HappySpeech
import XCTest

// MARK: - FamilyMembershipStoreTests
//
// Локальное хранилище принятых приглашений: сохранение, идемпотентность по
// inviterParentId, чтение пустого состояния.

final class FamilyMembershipStoreTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "test.familyMembership.\(UUID().uuidString)"
        // swiftlint:disable:next force_unwrapping
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func test_emptyByDefault() {
        let store = UserDefaultsFamilyMembershipStore(defaults: defaults)
        XCTAssertTrue(store.all().isEmpty)
    }

    func test_saveAndRetrieve() {
        let store = UserDefaultsFamilyMembershipStore(defaults: defaults)
        let record = FamilyMembershipRecord(inviterParentId: "p1", role: .secondary, joinedAt: Date())

        store.save(record)

        let all = store.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.inviterParentId, "p1")
        XCTAssertEqual(all.first?.role, ParentRole.secondary.rawValue)
    }

    func test_save_isIdempotentPerInviter() {
        let store = UserDefaultsFamilyMembershipStore(defaults: defaults)
        store.save(.init(inviterParentId: "p1", role: .observer, joinedAt: Date()))
        store.save(.init(inviterParentId: "p1", role: .secondary, joinedAt: Date()))

        let all = store.all()
        XCTAssertEqual(all.count, 1, "Повторный invite от того же родителя обновляет, а не дублирует")
        XCTAssertEqual(all.first?.role, ParentRole.secondary.rawValue)
    }

    func test_save_multipleInviters() {
        let store = UserDefaultsFamilyMembershipStore(defaults: defaults)
        store.save(.init(inviterParentId: "p1", role: .secondary, joinedAt: Date()))
        store.save(.init(inviterParentId: "p2", role: .observer, joinedAt: Date()))

        XCTAssertEqual(store.all().count, 2)
    }
}
