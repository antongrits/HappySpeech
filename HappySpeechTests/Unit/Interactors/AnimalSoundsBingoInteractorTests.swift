@testable import HappySpeech
import XCTest

// MARK: - AnimalSoundsBingoInteractorTests
//
// «Звуковое бинго»: поле собирается из звукоподражаний под рабочие звуки
// ребёнка (AnimalSoundsBingoContent). «Диктор» называет клетку, ребёнок ищет;
// верная отметка засчитывается, по заполнению поля игра завершается.

@MainActor
final class AnimalSoundsBingoInteractorTests: XCTestCase {

    private func makeSUT(childId: String = "") -> AnimalSoundsBingoInteractor {
        AnimalSoundsBingoInteractor(childId: childId)
    }

    // MARK: - Init / load

    func test_init_storesChildId() {
        let sut = makeSUT(childId: "kid-3")
        XCTAssertEqual(sut.childId, "kid-3")
    }

    func test_load_buildsBoard() async {
        let sut = makeSUT()
        await sut.load()
        XCTAssertTrue(sut.state.isLoaded)
        XCTAssertFalse(sut.state.cells.isEmpty)
        XCTAssertEqual(sut.state.markedCount, 0)
        XCTAssertFalse(sut.state.isBingo)
        XCTAssertNil(sut.state.calledOutId)
    }

    func test_content_cellsHaveSoundFamily() {
        let cells = AnimalSoundsBingoContent.cells(forTargetSounds: ["Р"])
        XCTAssertFalse(cells.isEmpty)
        XCTAssertTrue(cells.allSatisfy { !$0.soundFamily.isEmpty })
        // Рабочие звуки ребёнка идут первыми.
        XCTAssertEqual(cells.first?.soundFamily, "Р")
    }

    // MARK: - toggle

    func test_toggle_marksCell() async {
        let sut = makeSUT()
        await sut.load()
        let id = sut.state.cells[0].id
        sut.toggle(id)
        XCTAssertTrue(sut.state.cells[0].isMarked)
        XCTAssertEqual(sut.state.markedCount, 1)
    }

    func test_toggle_twice_unmarksCell() async {
        let sut = makeSUT()
        await sut.load()
        let id = sut.state.cells[0].id
        sut.toggle(id)
        sut.toggle(id)
        XCTAssertFalse(sut.state.cells[0].isMarked)
        XCTAssertEqual(sut.state.markedCount, 0)
    }

    func test_toggle_unknownId_noChange() async {
        let sut = makeSUT()
        await sut.load()
        sut.toggle(UUID())
        XCTAssertEqual(sut.state.markedCount, 0)
    }

    // MARK: - called scoring

    func test_toggle_correctCall_countsAsCorrect() async {
        let sut = makeSUT()
        await sut.load()
        let id = sut.state.cells[0].id
        sut.state.calledOutId = id
        sut.toggle(id)
        XCTAssertEqual(sut.state.correctMarks, 1)
        XCTAssertEqual(sut.state.wrongMarks, 0)
        XCTAssertNil(sut.state.calledOutId)
    }

    func test_toggle_wrongCard_countsAsWrong() async {
        let sut = makeSUT()
        await sut.load()
        let called = sut.state.cells[1].id
        sut.state.calledOutId = called
        sut.toggle(sut.state.cells[0].id)
        XCTAssertEqual(sut.state.wrongMarks, 1)
        XCTAssertEqual(sut.state.correctMarks, 0)
        // Вызов остаётся, т.к. отмечена не та клетка.
        XCTAssertEqual(sut.state.calledOutId, called)
    }

    // MARK: - callRandom

    func test_callRandom_setsCalledOutToUnmarkedCell() async {
        let sut = makeSUT()
        await sut.load()
        sut.callRandom()
        let calledId = sut.state.calledOutId
        XCTAssertNotNil(calledId)
        let cell = sut.state.cells.first { $0.id == calledId }
        XCTAssertFalse(cell?.isMarked ?? true)
    }

    func test_callRandom_allMarked_doesNotSetCalledOut() async {
        let sut = makeSUT()
        await sut.load()
        for idx in sut.state.cells.indices { sut.state.cells[idx].isMarked = true }
        sut.state.calledOutId = nil
        sut.callRandom()
        XCTAssertNil(sut.state.calledOutId)
    }

    // MARK: - bingo

    func test_isBingo_whenAllMarked() async {
        let sut = makeSUT()
        await sut.load()
        for idx in sut.state.cells.indices { sut.state.cells[idx].isMarked = true }
        XCTAssertTrue(sut.state.isBingo)
    }

    // MARK: - stars

    func test_stars_zeroWithoutAttempts() async {
        let sut = makeSUT()
        await sut.load()
        XCTAssertEqual(sut.state.stars, 0)
    }

    func test_stars_perfectAccuracy() async {
        let sut = makeSUT()
        await sut.load()
        sut.state.correctMarks = 5
        sut.state.wrongMarks = 0
        XCTAssertEqual(sut.state.stars, 3)
    }

    // MARK: - reset

    func test_reset_clearsMarksAndCalledOut() async {
        let sut = makeSUT()
        await sut.load()
        sut.toggle(sut.state.cells[0].id)
        sut.callRandom()
        sut.reset()
        XCTAssertEqual(sut.state.markedCount, 0)
        XCTAssertNil(sut.state.calledOutId)
        XCTAssertEqual(sut.state.correctMarks, 0)
    }
}
