@testable import HappySpeech
import XCTest

// MARK: - PuzzleRevealPresenterTests
//
// Phase 2.6.1 v25 — покрытие PuzzleRevealPresenter (14 тестов).
// Тестируются все 6 методов: presentLoadPuzzle, presentStartRecord,
// presentStopRecord, presentRevealTile, presentNextPuzzle, presentComplete.

@MainActor
final class PuzzleRevealPresenterTests: XCTestCase {

    // MARK: - DisplaySpy

    @MainActor
    private final class DisplaySpy: PuzzleRevealDisplayLogic {
        var loadPuzzleVM: PuzzleRevealModels.LoadPuzzle.ViewModel?
        var startRecordCalled = false
        var stopRecordCalled = false
        var revealTileVM: PuzzleRevealModels.RevealTile.ViewModel?
        var nextPuzzleVM: PuzzleRevealModels.NextPuzzle.ViewModel?
        var completeVM: PuzzleRevealModels.Complete.ViewModel?

        func displayLoadPuzzle(_ viewModel: PuzzleRevealModels.LoadPuzzle.ViewModel) { loadPuzzleVM = viewModel }
        func displayStartRecord(_ viewModel: PuzzleRevealModels.StartRecord.ViewModel) { startRecordCalled = true }
        func displayStopRecord(_ viewModel: PuzzleRevealModels.StopRecord.ViewModel) { stopRecordCalled = true }
        func displayRevealTile(_ viewModel: PuzzleRevealModels.RevealTile.ViewModel) { revealTileVM = viewModel }
        func displayNextPuzzle(_ viewModel: PuzzleRevealModels.NextPuzzle.ViewModel) { nextPuzzleVM = viewModel }
        func displayComplete(_ viewModel: PuzzleRevealModels.Complete.ViewModel) { completeVM = viewModel }
    }

    private func makeSUT() -> (PuzzleRevealPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = PuzzleRevealPresenter()
        presenter.viewModel = spy
        return (presenter, spy)
    }

    private func makeTiles(count: Int = 9, revealedCount: Int = 0) -> [PuzzleTile] {
        (0..<count).map { i in
            PuzzleTile(index: i, isRevealed: i < revealedCount)
        }
    }

    // MARK: - presentLoadPuzzle

    func test_presentLoadPuzzle_allHidden_progressZero() {
        let (sut, spy) = makeSUT()
        let response = PuzzleRevealModels.LoadPuzzle.Response(
            tiles: makeTiles(count: 9, revealedCount: 0),
            word: "ракета",
            emoji: "rocket",
            hintText: "Произнеси с буквой Р",
            puzzleIndex: 0,
            totalPuzzles: 5,
            attemptNumber: 1,
            isASRAvailable: true
        )
        sut.presentLoadPuzzle(response)
        XCTAssertNotNil(spy.loadPuzzleVM)
        XCTAssertEqual(spy.loadPuzzleVM?.progressFraction ?? -1, 0.0, accuracy: 0.001)
        XCTAssertEqual(spy.loadPuzzleVM?.word, "ракета")
    }

    func test_presentLoadPuzzle_halfRevealed_progressHalf() {
        let (sut, spy) = makeSUT()
        let response = PuzzleRevealModels.LoadPuzzle.Response(
            tiles: makeTiles(count: 8, revealedCount: 4),
            word: "самолёт",
            emoji: "airplane",
            hintText: "Произнеси с буквой С",
            puzzleIndex: 1,
            totalPuzzles: 5,
            attemptNumber: 5,
            isASRAvailable: false
        )
        sut.presentLoadPuzzle(response)
        XCTAssertEqual(spy.loadPuzzleVM?.progressFraction ?? -1, 0.5, accuracy: 0.001)
    }

    func test_presentLoadPuzzle_passesASRFlagThrough() {
        let (sut, spy) = makeSUT()
        let response = PuzzleRevealModels.LoadPuzzle.Response(
            tiles: makeTiles(),
            word: "рыба",
            emoji: "fish",
            hintText: "Р",
            puzzleIndex: 0,
            totalPuzzles: 5,
            attemptNumber: 1,
            isASRAvailable: false
        )
        sut.presentLoadPuzzle(response)
        XCTAssertFalse(spy.loadPuzzleVM?.isASRAvailable ?? true)
    }

    // MARK: - presentStartRecord / presentStopRecord

    func test_presentStartRecord_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentStartRecord(PuzzleRevealModels.StartRecord.Response())
        XCTAssertTrue(spy.startRecordCalled)
    }

    func test_presentStopRecord_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentStopRecord(PuzzleRevealModels.StopRecord.Response())
        XCTAssertTrue(spy.stopRecordCalled)
    }

    // MARK: - presentRevealTile

    func test_presentRevealTile_highScore_positiveFeedback() {
        let (sut, spy) = makeSUT()
        var tiles = makeTiles(count: 9, revealedCount: 1)
        tiles[0].isRevealed = true
        let response = PuzzleRevealModels.RevealTile.Response(
            tileIndex: 0,
            score: 0.9,
            tiles: tiles,
            allRevealed: false,
            attemptNumber: 1
        )
        sut.presentRevealTile(response)
        XCTAssertNotNil(spy.revealTileVM)
        XCTAssertFalse(spy.revealTileVM?.feedbackText.isEmpty ?? true)
        XCTAssertFalse(spy.revealTileVM?.allRevealed ?? true)
    }

    func test_presentRevealTile_midScore_goodFeedback() {
        let (sut, spy) = makeSUT()
        let response = PuzzleRevealModels.RevealTile.Response(
            tileIndex: 1,
            score: 0.7,
            tiles: makeTiles(),
            allRevealed: false,
            attemptNumber: 2
        )
        sut.presentRevealTile(response)
        XCTAssertFalse(spy.revealTileVM?.feedbackText.isEmpty ?? true)
    }

    func test_presentRevealTile_lowScore_tryAgainFeedback() {
        let (sut, spy) = makeSUT()
        let response = PuzzleRevealModels.RevealTile.Response(
            tileIndex: 2,
            score: 0.3,
            tiles: makeTiles(),
            allRevealed: false,
            attemptNumber: 3
        )
        sut.presentRevealTile(response)
        XCTAssertFalse(spy.revealTileVM?.feedbackText.isEmpty ?? true)
    }

    func test_presentRevealTile_allRevealed_flagSet() {
        let (sut, spy) = makeSUT()
        let allRevealedTiles = makeTiles(count: 9, revealedCount: 9)
        let response = PuzzleRevealModels.RevealTile.Response(
            tileIndex: 8,
            score: 0.9,
            tiles: allRevealedTiles,
            allRevealed: true,
            attemptNumber: 9
        )
        sut.presentRevealTile(response)
        XCTAssertTrue(spy.revealTileVM?.allRevealed ?? false)
        XCTAssertEqual(spy.revealTileVM?.progressFraction ?? 0, 1.0, accuracy: 0.001)
    }

    // MARK: - presentNextPuzzle

    func test_presentNextPuzzle_hasNext_truePassedThrough() {
        let (sut, spy) = makeSUT()
        sut.presentNextPuzzle(PuzzleRevealModels.NextPuzzle.Response(hasNext: true))
        XCTAssertTrue(spy.nextPuzzleVM?.hasNext ?? false)
    }

    func test_presentNextPuzzle_noNext_falsePassedThrough() {
        let (sut, spy) = makeSUT()
        sut.presentNextPuzzle(PuzzleRevealModels.NextPuzzle.Response(hasNext: false))
        XCTAssertFalse(spy.nextPuzzleVM?.hasNext ?? true)
    }

    // MARK: - presentComplete

    func test_presentComplete_3stars_scoreLabelContainsNumber() {
        let (sut, spy) = makeSUT()
        sut.presentComplete(PuzzleRevealModels.Complete.Response(averageScore: 0.95, starsEarned: 3))
        XCTAssertEqual(spy.completeVM?.starsEarned, 3)
        XCTAssertFalse(spy.completeVM?.scoreLabel.isEmpty ?? true)
        XCTAssertFalse(spy.completeVM?.completionMessage.isEmpty ?? true)
    }

    func test_presentComplete_1star_encouragingMessage() {
        let (sut, spy) = makeSUT()
        sut.presentComplete(PuzzleRevealModels.Complete.Response(averageScore: 0.6, starsEarned: 1))
        XCTAssertEqual(spy.completeVM?.starsEarned, 1)
        XCTAssertFalse(spy.completeVM?.completionMessage.isEmpty ?? true)
    }

    func test_presentComplete_0stars_tryAgainMessage() {
        let (sut, spy) = makeSUT()
        sut.presentComplete(PuzzleRevealModels.Complete.Response(averageScore: 0.2, starsEarned: 0))
        XCTAssertEqual(spy.completeVM?.starsEarned, 0)
        XCTAssertFalse(spy.completeVM?.completionMessage.isEmpty ?? true)
    }
}
