@testable import HappySpeech
import XCTest

// MARK: - DifferentiationProgressStoreTests
//
// v29 Фаза 8, Функция 5 «Звуковой светофор». Покрывает persistence прогресса
// лестницы дифференциации (`UserDefaultsDifferentiationProgressStore`):
// сохранение/чтение per-child-per-pair, дефолт, очистка по ребёнку,
// мульти-child-изоляцию. Использует изолированный UserDefaults-suite.

@MainActor
final class DifferentiationProgressStoreTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!
    private var sut: UserDefaultsDifferentiationProgressStore!

    override func setUp() {
        super.setUp()
        suiteName = "test.diff.progress.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        sut = UserDefaultsDifferentiationProgressStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        sut = nil
        super.tearDown()
    }

    func test_default_isSyllableLevel() {
        let progress = sut.progress(childId: "c1", pairId: "pair-s-sh")
        XCTAssertEqual(progress.level, .syllable)
        XCTAssertEqual(progress.consecutiveQualifyingSessions, 0)
        XCTAssertFalse(progress.isPairCompleted)
    }

    func test_saveAndLoad_roundTrips() {
        let saved = DifferentiationProgress(
            level: .phrase, consecutiveQualifyingSessions: 1, isPairCompleted: false
        )
        sut.save(saved, childId: "c1", pairId: "pair-r-l")
        let loaded = sut.progress(childId: "c1", pairId: "pair-r-l")
        XCTAssertEqual(loaded, saved)
    }

    func test_progress_isPerPair() {
        sut.save(.init(level: .word), childId: "c1", pairId: "pair-s-sh")
        sut.save(.init(level: .text), childId: "c1", pairId: "pair-r-l")
        XCTAssertEqual(sut.progress(childId: "c1", pairId: "pair-s-sh").level, .word)
        XCTAssertEqual(sut.progress(childId: "c1", pairId: "pair-r-l").level, .text)
    }

    func test_progress_isPerChild() {
        sut.save(.init(level: .phrase), childId: "c1", pairId: "pair-s-sh")
        XCTAssertEqual(sut.progress(childId: "c2", pairId: "pair-s-sh").level, .syllable,
                       "Другой ребёнок — независимый прогресс")
    }

    func test_clear_removesChildProgress() {
        sut.save(.init(level: .word), childId: "c1", pairId: "pair-s-sh")
        sut.save(.init(level: .text), childId: "c1", pairId: "pair-r-l")
        sut.save(.init(level: .phrase), childId: "c2", pairId: "pair-s-sh")

        sut.clear(childId: "c1")

        XCTAssertEqual(sut.progress(childId: "c1", pairId: "pair-s-sh").level, .syllable)
        XCTAssertEqual(sut.progress(childId: "c1", pairId: "pair-r-l").level, .syllable)
        XCTAssertEqual(sut.progress(childId: "c2", pairId: "pair-s-sh").level, .phrase,
                       "Очистка одного ребёнка не трогает другого")
    }

    func test_emptyIds_areIgnored() {
        sut.save(.init(level: .text), childId: "", pairId: "pair-s-sh")
        XCTAssertEqual(sut.progress(childId: "", pairId: "pair-s-sh").level, .syllable)
    }
}
