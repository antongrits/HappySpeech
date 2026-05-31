@testable import HappySpeech
import XCTest

// MARK: - SpeechDisorderStoreTests (F1-021)
// ==================================================================================
// Тесты per-child хранилища профиля нарушения (UserDefaults, без Realm-миграции).
// Используем изолированный suite, чтобы не загрязнять standard defaults.
// ==================================================================================

final class SpeechDisorderStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "test.speechDisorderStore"

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: - 1. Дефолт при отсутствии значения — дислалия

    func testLoad_default_isDyslalia() {
        let disorder = SpeechDisorderStore.load(childId: "child-1", defaults: defaults)
        XCTAssertEqual(disorder, .dyslalia)
        XCTAssertEqual(disorder, SpeechDisorder.default)
    }

    // MARK: - 2. Save → load round-trip

    func testSaveLoad_roundTrip() {
        for disorder in SpeechDisorder.allCases {
            SpeechDisorderStore.save(disorder, childId: "child-1", defaults: defaults)
            let loaded = SpeechDisorderStore.load(childId: "child-1", defaults: defaults)
            XCTAssertEqual(loaded, disorder, "round-trip для \(disorder.rawValue)")
        }
    }

    // MARK: - 3. Per-child изоляция

    func testPerChild_isolation() {
        SpeechDisorderStore.save(.onr, childId: "child-A", defaults: defaults)
        SpeechDisorderStore.save(.stuttering, childId: "child-B", defaults: defaults)
        XCTAssertEqual(SpeechDisorderStore.load(childId: "child-A", defaults: defaults), .onr)
        XCTAssertEqual(SpeechDisorderStore.load(childId: "child-B", defaults: defaults), .stuttering)
        // Третий ребёнок без записи — дефолт.
        XCTAssertEqual(SpeechDisorderStore.load(childId: "child-C", defaults: defaults), .dyslalia)
    }

    // MARK: - 4. clear возвращает к дефолту

    func testClear_resetsToDefault() {
        SpeechDisorderStore.save(.dysarthria, childId: "child-1", defaults: defaults)
        SpeechDisorderStore.clear(childId: "child-1", defaults: defaults)
        XCTAssertEqual(SpeechDisorderStore.load(childId: "child-1", defaults: defaults), .dyslalia)
    }

    // MARK: - 5. Пустой childId — save no-op, load дефолт

    func testEmptyChildId_isSafe() {
        SpeechDisorderStore.save(.onr, childId: "", defaults: defaults)
        XCTAssertEqual(SpeechDisorderStore.load(childId: "", defaults: defaults), .dyslalia)
    }

    // MARK: - 6. Перезапись значения

    func testOverwrite_takesLatest() {
        SpeechDisorderStore.save(.ffn, childId: "child-1", defaults: defaults)
        SpeechDisorderStore.save(.zrr, childId: "child-1", defaults: defaults)
        XCTAssertEqual(SpeechDisorderStore.load(childId: "child-1", defaults: defaults), .zrr)
    }

    // MARK: - 7. Битое значение → дефолт

    func testCorruptedValue_fallsBackToDefault() {
        defaults.set("not-a-disorder", forKey: "speech.disorder.child-1")
        XCTAssertEqual(SpeechDisorderStore.load(childId: "child-1", defaults: defaults), .dyslalia)
    }
}
