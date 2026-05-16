@testable import HappySpeech
import XCTest

// MARK: - BingoPresenterTests
//
// Phase 2.6.1 v25 — покрытие BingoPresenter (13 тестов).
// Тестируются все 4 метода: presentLoadGame, presentCallWord,
// presentMarkCell, presentCompleteGame.

@MainActor
final class BingoPresenterTests: XCTestCase {

    // MARK: - DisplaySpy

    @MainActor
    private final class DisplaySpy: BingoDisplayLogic {
        var loadGameVM: BingoModels.LoadGame.ViewModel?
        var callWordVM: BingoModels.CallWord.ViewModel?
        var markCellVM: BingoModels.MarkCell.ViewModel?
        var completeGameVM: BingoModels.CompleteGame.ViewModel?

        func displayLoadGame(_ viewModel: BingoModels.LoadGame.ViewModel) { loadGameVM = viewModel }
        func displayCallWord(_ viewModel: BingoModels.CallWord.ViewModel) { callWordVM = viewModel }
        func displayMarkCell(_ viewModel: BingoModels.MarkCell.ViewModel) { markCellVM = viewModel }
        func displayCompleteGame(_ viewModel: BingoModels.CompleteGame.ViewModel) { completeGameVM = viewModel }
    }

    private func makeSUT() -> (BingoPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = BingoPresenter()
        presenter.display = spy
        return (presenter, spy)
    }

    private func makeCell(word: String = "сок", isMarked: Bool = false, isWinner: Bool = false) -> BingoCell {
        BingoCell(id: UUID(), word: word, soundGroup: "whistling", isMarked: isMarked, isWinner: isWinner)
    }

    // MARK: - presentLoadGame

    func test_presentLoadGame_firstWord_usedAsCalledWord() {
        let (sut, spy) = makeSUT()
        let response = BingoModels.LoadGame.Response(
            cells: [makeCell()],
            totalWords: 25,
            firstWord: "самолёт"
        )
        sut.presentLoadGame(response)
        XCTAssertNotNil(spy.loadGameVM)
        XCTAssertEqual(spy.loadGameVM?.calledWord, "самолёт")
        XCTAssertEqual(spy.loadGameVM?.totalWords, 25)
        XCTAssertEqual(spy.loadGameVM?.progressFraction, 0.0)
    }

    func test_presentLoadGame_nilFirstWord_emptyCalledWord() {
        let (sut, spy) = makeSUT()
        let response = BingoModels.LoadGame.Response(
            cells: [makeCell()],
            totalWords: 10,
            firstWord: nil
        )
        sut.presentLoadGame(response)
        XCTAssertEqual(spy.loadGameVM?.calledWord, "")
    }

    // MARK: - presentCallWord

    func test_presentCallWord_progressFractionMidway() {
        let (sut, spy) = makeSUT()
        let response = BingoModels.CallWord.Response(word: "ракета", index: 5, total: 10)
        sut.presentCallWord(response)
        XCTAssertEqual(spy.callWordVM?.calledWord, "ракета")
        XCTAssertEqual(spy.callWordVM?.progressFraction ?? -1, 0.5, accuracy: 0.001)
        XCTAssertTrue(spy.callWordVM?.isCalling ?? false)
    }

    func test_presentCallWord_firstWord_progressNearZero() {
        let (sut, spy) = makeSUT()
        let response = BingoModels.CallWord.Response(word: "сок", index: 1, total: 25)
        sut.presentCallWord(response)
        XCTAssertEqual(spy.callWordVM?.calledWordIndex, 1)
        XCTAssertLessThan(spy.callWordVM?.progressFraction ?? 1, 0.1)
    }

    func test_presentCallWord_zeroTotal_noNaN() {
        let (sut, spy) = makeSUT()
        let response = BingoModels.CallWord.Response(word: "тест", index: 0, total: 0)
        sut.presentCallWord(response)
        let fraction = spy.callWordVM?.progressFraction ?? -1
        XCTAssertFalse(fraction.isNaN)
        XCTAssertGreaterThanOrEqual(fraction, 0.0)
    }

    // MARK: - presentMarkCell

    func test_presentMarkCell_noBingoLines_playingPhase() {
        let (sut, spy) = makeSUT()
        let cells = (0..<25).map { _ in makeCell() }
        let response = BingoModels.MarkCell.Response(
            cells: cells,
            bingoLines: [],
            allMarked: false
        )
        sut.presentMarkCell(response)
        XCTAssertNotNil(spy.markCellVM)
        XCTAssertEqual(spy.markCellVM?.phase, .playing)
        XCTAssertTrue(spy.markCellVM?.bingoLines.isEmpty ?? false)
    }

    func test_presentMarkCell_hasBingoLine_bingoPhase() {
        let (sut, spy) = makeSUT()
        let cells = (0..<25).map { i in BingoCell(id: UUID(), word: "слово\(i)", soundGroup: "w", isMarked: i < 5, isWinner: i < 5) }
        let response = BingoModels.MarkCell.Response(
            cells: cells,
            bingoLines: [[0, 1, 2, 3, 4]],
            allMarked: false
        )
        sut.presentMarkCell(response)
        XCTAssertEqual(spy.markCellVM?.phase, .bingo)
        XCTAssertFalse(spy.markCellVM?.bingoLines.isEmpty ?? true)
    }

    // MARK: - presentCompleteGame

    func test_presentCompleteGame_bingoAchieved_bingoMessage() {
        let (sut, spy) = makeSUT()
        let response = BingoModels.CompleteGame.Response(
            score: 0.9,
            bingoAchieved: true,
            markedCells: 20,
            totalCells: 25
        )
        sut.presentCompleteGame(response)
        XCTAssertEqual(spy.completeGameVM?.starsEarned, 3)
        // бинго → специальное сообщение
        XCTAssertFalse(spy.completeGameVM?.completionMessage.isEmpty ?? true)
    }

    func test_presentCompleteGame_highScoreNoBingo_2stars() {
        let (sut, spy) = makeSUT()
        let response = BingoModels.CompleteGame.Response(
            score: 0.75,
            bingoAchieved: false,
            markedCells: 15,
            totalCells: 25
        )
        sut.presentCompleteGame(response)
        XCTAssertEqual(spy.completeGameVM?.starsEarned, 2)
        XCTAssertFalse(spy.completeGameVM?.completionMessage.isEmpty ?? true)
    }

    func test_presentCompleteGame_lowScore_0stars() {
        let (sut, spy) = makeSUT()
        let response = BingoModels.CompleteGame.Response(
            score: 0.2,
            bingoAchieved: false,
            markedCells: 3,
            totalCells: 25
        )
        sut.presentCompleteGame(response)
        XCTAssertEqual(spy.completeGameVM?.starsEarned, 0)
    }

    func test_presentCompleteGame_scoreLabelContainsPercent() {
        let (sut, spy) = makeSUT()
        let response = BingoModels.CompleteGame.Response(
            score: 0.7,
            bingoAchieved: false,
            markedCells: 14,
            totalCells: 25
        )
        sut.presentCompleteGame(response)
        XCTAssertTrue(spy.completeGameVM?.scoreLabel.contains("%") ?? false)
    }

    // MARK: - starsForScore utility

    func test_starsForScore_boundary_exactlyPoint9_returns3() {
        XCTAssertEqual(BingoPresenter.starsForScore(0.9), 3)
    }

    func test_starsForScore_boundary_exactlyPoint7_returns2() {
        XCTAssertEqual(BingoPresenter.starsForScore(0.7), 2)
    }

    func test_starsForScore_boundary_exactlyPoint5_returns1() {
        XCTAssertEqual(BingoPresenter.starsForScore(0.5), 1)
    }
}
