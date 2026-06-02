@testable import HappySpeech
import XCTest

// MARK: - EveningReflectionInteractorTests
//
// Вечерняя рефлексия: запись (fun/hard + mood) + история; submit() требует
// выбранного настроения, ставит savedAt, добавляет запись в начало истории и
// сбрасывает черновик. История персистится в EveningReflectionStore. Тесты
// используют изолированный UserDefaults.

@MainActor
final class EveningReflectionInteractorTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "test.eveningReflection"

    override func setUp() async throws {
        try await super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        try await super.tearDown()
    }

    private func makeSUT(childId: String = "child-1") -> EveningReflectionInteractor {
        let sut = EveningReflectionInteractor(childId: childId, defaults: defaults)
        sut.load()
        return sut
    }

    // MARK: - Init

    func test_init_storesChildId() {
        let sut = EveningReflectionInteractor(childId: "c-13", defaults: defaults)
        XCTAssertEqual(sut.childId, "c-13")
    }

    func test_initialState_emptyEntryAndHistory() {
        let sut = makeSUT()
        XCTAssertEqual(sut.entry.fun, "")
        XCTAssertEqual(sut.entry.hard, "")
        XCTAssertNil(sut.entry.mood)
        XCTAssertNil(sut.entry.savedAt)
        XCTAssertTrue(sut.history.isEmpty)
        XCTAssertTrue(sut.isLoaded)
    }

    // MARK: - submit guard

    func test_submit_withoutMood_doesNotSave() {
        let sut = makeSUT()
        sut.submit()
        XCTAssertTrue(sut.history.isEmpty)
    }

    func test_submit_withTextButNoMood_doesNotSave() {
        let sut = makeSUT()
        sut.entry.fun = "играли в мяч"
        sut.entry.hard = "звук Р"
        sut.submit()
        XCTAssertTrue(sut.history.isEmpty)
    }

    // MARK: - submit happy path

    func test_submit_withMood_insertsIntoHistory() {
        let sut = makeSUT()
        sut.entry.mood = .bright
        sut.submit()
        XCTAssertEqual(sut.history.count, 1)
        XCTAssertEqual(sut.history.first?.mood, .bright)
    }

    func test_submit_stampsSavedAt() {
        let sut = makeSUT()
        sut.entry.mood = .calm
        let before = Date()
        sut.submit()
        let saved = sut.history.first!
        XCTAssertNotNil(saved.savedAt)
        if let savedAt = saved.savedAt {
            XCTAssertGreaterThanOrEqual(savedAt, before.addingTimeInterval(-1))
        }
    }

    func test_submit_preservesTextInHistory() {
        let sut = makeSUT()
        sut.entry.fun = "прогулка"
        sut.entry.hard = "усидчивость"
        sut.entry.mood = .sad
        sut.submit()
        XCTAssertEqual(sut.history.first?.fun, "прогулка")
        XCTAssertEqual(sut.history.first?.hard, "усидчивость")
    }

    func test_submit_resetsDraftAfterSave() {
        let sut = makeSUT()
        sut.entry.fun = "что-то"
        sut.entry.mood = .bright
        sut.submit()
        XCTAssertEqual(sut.entry.fun, "")
        XCTAssertEqual(sut.entry.hard, "")
        XCTAssertNil(sut.entry.mood)
    }

    func test_submit_multipleEntries_prependNewest() {
        let sut = makeSUT()
        sut.entry.fun = "first"
        sut.entry.mood = .bright
        sut.submit()
        sut.entry.fun = "second"
        sut.entry.mood = .calm
        sut.submit()
        XCTAssertEqual(sut.history.count, 2)
        XCTAssertEqual(sut.history.first?.fun, "second")
        XCTAssertEqual(sut.history.last?.fun, "first")
    }

    // MARK: - Persistence

    func test_persistence_survivesNewInstance() {
        let sut1 = makeSUT(childId: "kid-diary")
        sut1.entry.fun = "запомни меня"
        sut1.entry.mood = .bright
        sut1.submit()
        let sut2 = EveningReflectionInteractor(childId: "kid-diary", defaults: defaults)
        sut2.load()
        XCTAssertEqual(sut2.history.count, 1)
        XCTAssertEqual(sut2.history.first?.fun, "запомни меня")
    }
}
