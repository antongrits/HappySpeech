@testable import HappySpeech
import XCTest

// MARK: - StageProgressStoreTests (P0-4)
// ==================================================================================
// Персистентный прогресс лестницы per-child-per-sound (UserDefaults).
//   • дефолт при отсутствии записи — .isolated, серия 0;
//   • round-trip сохранения/чтения стадии + счётчика;
//   • изоляция по ребёнку и по звуку;
//   • clear удаляет все звуки ребёнка.
// Каждый тест работает на изолированном UserDefaults-suite (без записи в .standard).
// ==================================================================================

final class StageProgressStoreTests: XCTestCase {

    private var suiteName: String = ""

    override func setUp() {
        super.setUp()
        suiteName = "test.stageProgress.\(UUID().uuidString)"
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeStore() -> UserDefaultsStageProgressStore {
        UserDefaultsStageProgressStore(suiteName: suiteName)
    }

    // MARK: - defaults

    func test_progress_unknown_returnsIsolatedStart() {
        let store = makeStore()
        let progress = store.progress(childId: "c1", sound: "С")
        XCTAssertEqual(progress.stage, .isolated)
        XCTAssertEqual(progress.consecutiveQualifyingSessions, 0)
    }

    func test_currentStage_unknown_returnsIsolated() {
        let store = makeStore()
        XCTAssertEqual(store.currentStage(childId: "c1", sound: "Р"), .isolated)
    }

    func test_progress_emptyIdentifiers_returnsDefault() {
        let store = makeStore()
        XCTAssertEqual(store.progress(childId: "", sound: "С").stage, .isolated)
        XCTAssertEqual(store.progress(childId: "c1", sound: "").stage, .isolated)
    }

    // MARK: - round-trip

    func test_saveThenRead_roundTripsStageAndStreak() {
        let store = makeStore()
        store.save(
            StageProgress(stage: .wordMed, consecutiveQualifyingSessions: 1),
            childId: "c1", sound: "Р"
        )
        let read = store.progress(childId: "c1", sound: "Р")
        XCTAssertEqual(read.stage, .wordMed)
        XCTAssertEqual(read.consecutiveQualifyingSessions, 1)
    }

    func test_save_persistsAcrossStoreInstances() {
        makeStore().save(
            StageProgress(stage: .phrase, consecutiveQualifyingSessions: 0),
            childId: "c1", sound: "Ш"
        )
        // Новый инстанс читает тот же suite — стадия сохранилась.
        let read = makeStore().progress(childId: "c1", sound: "Ш")
        XCTAssertEqual(read.stage, .phrase)
    }

    func test_save_emptyIdentifiers_isNoOp() {
        let store = makeStore()
        store.save(StageProgress(stage: .story), childId: "", sound: "С")
        store.save(StageProgress(stage: .story), childId: "c1", sound: "")
        XCTAssertEqual(store.progress(childId: "c1", sound: "С").stage, .isolated)
    }

    // MARK: - isolation

    func test_isolation_perSound() {
        let store = makeStore()
        store.save(StageProgress(stage: .wordFinal), childId: "c1", sound: "С")
        store.save(StageProgress(stage: .syllable), childId: "c1", sound: "Р")
        XCTAssertEqual(store.progress(childId: "c1", sound: "С").stage, .wordFinal)
        XCTAssertEqual(store.progress(childId: "c1", sound: "Р").stage, .syllable)
    }

    func test_isolation_perChild() {
        let store = makeStore()
        store.save(StageProgress(stage: .sentence), childId: "c1", sound: "С")
        store.save(StageProgress(stage: .isolated), childId: "c2", sound: "С")
        XCTAssertEqual(store.progress(childId: "c1", sound: "С").stage, .sentence)
        XCTAssertEqual(store.progress(childId: "c2", sound: "С").stage, .isolated)
    }

    // MARK: - clear

    func test_clear_removesAllSoundsForChild() {
        let store = makeStore()
        store.save(StageProgress(stage: .wordMed), childId: "c1", sound: "С")
        store.save(StageProgress(stage: .phrase), childId: "c1", sound: "Р")
        store.save(StageProgress(stage: .story), childId: "c2", sound: "С")

        store.clear(childId: "c1")

        XCTAssertEqual(store.progress(childId: "c1", sound: "С").stage, .isolated, "очищено")
        XCTAssertEqual(store.progress(childId: "c1", sound: "Р").stage, .isolated, "очищено")
        XCTAssertEqual(store.progress(childId: "c2", sound: "С").stage, .story, "другой ребёнок не затронут")
    }
}
