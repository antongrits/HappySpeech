@testable import HappySpeech
import XCTest

// MARK: - SpeechHomeworkPlannerInteractorTests
//
// Thin VIP (@Observable). Tests toggle plus the doneCount / progress
// computed properties (including the divide-by-zero guard via max(count,1)).

@MainActor
final class SpeechHomeworkPlannerInteractorTests: XCTestCase {

    private func makeSUT() -> SpeechHomeworkPlannerInteractor {
        SpeechHomeworkPlannerInteractor()
    }

    // MARK: - Initial state

    func test_initialState_seedItems() {
        let sut = makeSUT()
        XCTAssertEqual(sut.items.count, SpeechHomeworkPlannerModels.seed.count)
    }

    func test_initialState_doneCountZero() {
        let sut = makeSUT()
        XCTAssertEqual(sut.doneCount, 0)
    }

    func test_initialState_progressZero() {
        let sut = makeSUT()
        XCTAssertEqual(sut.progress, 0.0, accuracy: 0.0001)
    }

    // MARK: - toggle

    func test_toggle_marksItemDone() {
        let sut = makeSUT()
        let firstId = sut.items[0].id
        sut.toggle(firstId)
        XCTAssertTrue(sut.items[0].isDone)
    }

    func test_toggle_incrementsDoneCount() {
        let sut = makeSUT()
        sut.toggle(sut.items[0].id)
        XCTAssertEqual(sut.doneCount, 1)
    }

    func test_toggle_twice_returnsToNotDone() {
        let sut = makeSUT()
        let id = sut.items[0].id
        sut.toggle(id)
        sut.toggle(id)
        XCTAssertFalse(sut.items[0].isDone)
        XCTAssertEqual(sut.doneCount, 0)
    }

    func test_toggle_unknownId_isNoOp() {
        let sut = makeSUT()
        sut.toggle(UUID())
        XCTAssertEqual(sut.doneCount, 0)
    }

    func test_toggle_allItems_progressIsOne() {
        let sut = makeSUT()
        for item in sut.items {
            sut.toggle(item.id)
        }
        XCTAssertEqual(sut.progress, 1.0, accuracy: 0.0001)
        XCTAssertEqual(sut.doneCount, sut.items.count)
    }

    func test_toggle_half_progressIsAboutHalf() {
        let sut = makeSUT()
        let half = sut.items.count / 2
        for index in 0..<half {
            sut.toggle(sut.items[index].id)
        }
        XCTAssertEqual(sut.progress, Double(half) / Double(sut.items.count), accuracy: 0.0001)
    }

    // MARK: - Seed model

    func test_seed_itemsHaveDistinctIds() {
        let ids = Set(SpeechHomeworkPlannerModels.seed.map(\.id))
        XCTAssertEqual(ids.count, SpeechHomeworkPlannerModels.seed.count)
    }
}
