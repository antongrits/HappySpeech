@testable import HappySpeech
import XCTest

// MARK: - AnimalSoundsBingoInteractorTests
//
// AnimalSoundsBingoInteractor is a thin VIP MVP variant (@Observable). Tests
// cover toggle(), callRandom(), reset() and the bingo/markedCount computeds.

@MainActor
final class AnimalSoundsBingoInteractorTests: XCTestCase {

    private func makeSUT(childId: String = "child-1") -> AnimalSoundsBingoInteractor {
        AnimalSoundsBingoInteractor(childId: childId)
    }

    // MARK: - Initial state

    func test_init_storesChildId() {
        let sut = makeSUT(childId: "kid-3")
        XCTAssertEqual(sut.childId, "kid-3")
    }

    func test_initialState_sixteenCells() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.cells.count, AnimalSoundsBingoModels.ViewState.animals.count)
    }

    func test_initialState_nothingMarked() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.markedCount, 0)
        XCTAssertFalse(sut.state.isBingo)
    }

    func test_initialState_noCalledOut() {
        let sut = makeSUT()
        XCTAssertNil(sut.state.calledOutId)
    }

    // MARK: - toggle

    func test_toggle_marksCell() {
        let sut = makeSUT()
        let id = sut.state.cells[0].id
        sut.toggle(id)
        XCTAssertTrue(sut.state.cells[0].isMarked)
        XCTAssertEqual(sut.state.markedCount, 1)
    }

    func test_toggle_twice_unmarksCell() {
        let sut = makeSUT()
        let id = sut.state.cells[0].id
        sut.toggle(id)
        sut.toggle(id)
        XCTAssertFalse(sut.state.cells[0].isMarked)
        XCTAssertEqual(sut.state.markedCount, 0)
    }

    func test_toggle_unknownId_noChange() {
        let sut = makeSUT()
        sut.toggle(UUID())
        XCTAssertEqual(sut.state.markedCount, 0)
    }

    func test_toggle_clearsCalledOutWhenMatchingCell() {
        let sut = makeSUT()
        let id = sut.state.cells[0].id
        // Force calledOutId to that cell, then toggle it → calledOut cleared.
        sut.state.calledOutId = id
        sut.toggle(id)
        XCTAssertNil(sut.state.calledOutId)
    }

    func test_toggle_keepsCalledOutWhenDifferentCell() {
        let sut = makeSUT()
        let called = sut.state.cells[1].id
        sut.state.calledOutId = called
        sut.toggle(sut.state.cells[0].id)
        XCTAssertEqual(sut.state.calledOutId, called)
    }

    // MARK: - bingo threshold

    func test_isBingo_trueWhenEightMarked() {
        let sut = makeSUT()
        for cell in sut.state.cells.prefix(8) {
            sut.toggle(cell.id)
        }
        XCTAssertEqual(sut.state.markedCount, 8)
        XCTAssertTrue(sut.state.isBingo)
    }

    func test_isBingo_falseWhenSevenMarked() {
        let sut = makeSUT()
        for cell in sut.state.cells.prefix(7) {
            sut.toggle(cell.id)
        }
        XCTAssertFalse(sut.state.isBingo)
    }

    // MARK: - callRandom

    func test_callRandom_setsCalledOutToUnmarkedCell() {
        let sut = makeSUT()
        sut.callRandom()
        let calledId = sut.state.calledOutId
        XCTAssertNotNil(calledId)
        let cell = sut.state.cells.first { $0.id == calledId }
        XCTAssertFalse(cell?.isMarked ?? true)
    }

    func test_callRandom_allMarked_doesNotSetCalledOut() {
        let sut = makeSUT()
        for cell in sut.state.cells {
            sut.toggle(cell.id)
        }
        sut.state.calledOutId = nil
        sut.callRandom()
        XCTAssertNil(sut.state.calledOutId)
    }

    // MARK: - reset

    func test_reset_clearsMarksAndCalledOut() {
        let sut = makeSUT()
        sut.toggle(sut.state.cells[0].id)
        sut.callRandom()
        sut.reset()
        XCTAssertEqual(sut.state.markedCount, 0)
        XCTAssertNil(sut.state.calledOutId)
    }
}
