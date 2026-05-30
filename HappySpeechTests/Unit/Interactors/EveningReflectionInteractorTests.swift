@testable import HappySpeech
import XCTest

// MARK: - EveningReflectionInteractorTests
//
// EveningReflectionInteractor is a thin VIP MVP variant (@Observable). It captures
// a child's evening reflection (free-text fun/hard + a mood) and a history list;
// submit() guards on a chosen mood, stamps savedAt, prepends the entry to history
// and resets the draft. Tests cover the empty start, the guard branch, the happy
// path (history insert, timestamp, reset) and that text alone is insufficient.
// (Mood.emoji/.label maps are purely presentational — intentionally skipped.)

@MainActor
final class EveningReflectionInteractorTests: XCTestCase {

    private func makeSUT() -> EveningReflectionInteractor {
        EveningReflectionInteractor(childId: "child-1")
    }

    // MARK: - Init

    func test_init_storesChildId() {
        let sut = EveningReflectionInteractor(childId: "c-13")
        XCTAssertEqual(sut.childId, "c-13")
    }

    func test_initialState_emptyEntryAndHistory() {
        let sut = makeSUT()
        XCTAssertEqual(sut.entry.fun, "")
        XCTAssertEqual(sut.entry.hard, "")
        XCTAssertNil(sut.entry.mood)
        XCTAssertNil(sut.entry.savedAt)
        XCTAssertTrue(sut.history.isEmpty)
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

    func test_submit_withoutMood_keepsDraft() {
        let sut = makeSUT()
        sut.entry.fun = "не теряем черновик"
        sut.submit()
        XCTAssertEqual(sut.entry.fun, "не теряем черновик")
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
            XCTAssertGreaterThanOrEqual(savedAt, before)
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
        XCTAssertNil(sut.entry.savedAt)
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
}
