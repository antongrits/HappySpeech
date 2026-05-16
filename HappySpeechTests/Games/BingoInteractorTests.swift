@testable import HappySpeech
import XCTest

// MARK: - BingoInteractorTests
//
// 9 тестов для BingoInteractor (S12-010 P1).
// Покрывает: loadGame (25 клеток), resolveSoundGroup, markCell, markCell дважды,
// completeGame (score 0), starsForScore (4 случая), cancel, checkBingo (пустой).

@MainActor
final class BingoInteractorTests: XCTestCase {

    // MARK: - Spy

    @MainActor
    private final class SpyPresenter: BingoPresentationLogic {
        var loadGameCalled = false
        var callWordCalled = false
        var markCellCalled = false
        var completeGameCalled = false

        var lastLoadResponse: BingoModels.LoadGame.Response?
        var lastCallWordResponse: BingoModels.CallWord.Response?
        var lastMarkCellResponse: BingoModels.MarkCell.Response?
        var lastCompleteResponse: BingoModels.CompleteGame.Response?

        func presentLoadGame(_ response: BingoModels.LoadGame.Response) {
            loadGameCalled = true
            lastLoadResponse = response
        }
        func presentCallWord(_ response: BingoModels.CallWord.Response) {
            callWordCalled = true
            lastCallWordResponse = response
        }
        func presentMarkCell(_ response: BingoModels.MarkCell.Response) {
            markCellCalled = true
            lastMarkCellResponse = response
        }
        func presentCompleteGame(_ response: BingoModels.CompleteGame.Response) {
            completeGameCalled = true
            lastCompleteResponse = response
        }
    }

    // MARK: - Helpers

    private func makeActivity(sound: String = "С") -> SessionActivity {
        SessionActivity(
            id: "test-bingo",
            gameType: .bingo,
            lessonId: "lesson-1",
            soundTarget: sound,
            difficulty: 1,
            isCompleted: false,
            score: nil
        )
    }

    private func makeSUT() -> (BingoInteractor, SpyPresenter) {
        let sut = BingoInteractor()
        let spy = SpyPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 1. loadGame создаёт 25 клеток

    func test_loadGame_loads25Cells() {
        let (sut, spy) = makeSUT()
        sut.loadGame(.init(activity: makeActivity(sound: "С")))
        XCTAssertTrue(spy.loadGameCalled)
        XCTAssertEqual(spy.lastLoadResponse?.cells.count, 25)
    }

    // MARK: - 2. resolveSoundGroup — маппинг

    func test_resolveSoundGroup_whistling() {
        XCTAssertEqual(BingoInteractor.resolveSoundGroup(for: "С"), "whistling")
        XCTAssertEqual(BingoInteractor.resolveSoundGroup(for: "З"), "whistling")
        XCTAssertEqual(BingoInteractor.resolveSoundGroup(for: "Ц"), "whistling")
    }

    func test_resolveSoundGroup_hissing() {
        XCTAssertEqual(BingoInteractor.resolveSoundGroup(for: "Ш"), "hissing")
        XCTAssertEqual(BingoInteractor.resolveSoundGroup(for: "Ж"), "hissing")
        XCTAssertEqual(BingoInteractor.resolveSoundGroup(for: "Ч"), "hissing")
        XCTAssertEqual(BingoInteractor.resolveSoundGroup(for: "Щ"), "hissing")
    }

    func test_resolveSoundGroup_sonants() {
        XCTAssertEqual(BingoInteractor.resolveSoundGroup(for: "Р"), "sonants")
        XCTAssertEqual(BingoInteractor.resolveSoundGroup(for: "Л"), "sonants")
    }

    func test_resolveSoundGroup_velar() {
        XCTAssertEqual(BingoInteractor.resolveSoundGroup(for: "К"), "velar")
        XCTAssertEqual(BingoInteractor.resolveSoundGroup(for: "Г"), "velar")
        XCTAssertEqual(BingoInteractor.resolveSoundGroup(for: "Х"), "velar")
    }

    // MARK: - 3. markCell помечает правильную клетку

    func test_markCell_marksCellAsMarked() {
        let (sut, spy) = makeSUT()
        sut.loadGame(.init(activity: makeActivity()))
        guard let firstCell = spy.lastLoadResponse?.cells.first else {
            XCTFail("Нет клеток после loadGame")
            return
        }
        sut.markCell(.init(cellId: firstCell.id))
        XCTAssertTrue(spy.markCellCalled)
        let markedCount = spy.lastMarkCellResponse?.cells.filter(\.isMarked).count ?? 0
        XCTAssertGreaterThanOrEqual(markedCount, 1)
    }

    // MARK: - 4. markCell дважды — идемпотентно

    func test_markCell_twice_ignored() {
        let (sut, spy) = makeSUT()
        sut.loadGame(.init(activity: makeActivity()))
        guard let firstCell = spy.lastLoadResponse?.cells.first else { return }

        sut.markCell(.init(cellId: firstCell.id))
        let countAfterFirst = spy.lastMarkCellResponse?.cells.filter(\.isMarked).count ?? 0
        sut.markCell(.init(cellId: firstCell.id))
        let countAfterSecond = spy.lastMarkCellResponse?.cells.filter(\.isMarked).count ?? 0
        XCTAssertEqual(countAfterFirst, countAfterSecond)
    }

    // MARK: - 5. completeGame считает score в [0,1]

    func test_completeGame_zeroMarked_scoreInRange() {
        let (sut, spy) = makeSUT()
        sut.loadGame(.init(activity: makeActivity()))
        sut.completeGame()
        XCTAssertTrue(spy.completeGameCalled)
        let score = spy.lastCompleteResponse?.score ?? -1
        XCTAssertGreaterThanOrEqual(score, 0)
        XCTAssertLessThanOrEqual(score, 1)
    }

    // MARK: - 6. starsForScore

    func test_starsForScore_threeStars() {
        XCTAssertEqual(BingoPresenter.starsForScore(0.9), 3)
        XCTAssertEqual(BingoPresenter.starsForScore(1.0), 3)
    }

    func test_starsForScore_twoStars() {
        XCTAssertEqual(BingoPresenter.starsForScore(0.7), 2)
        XCTAssertEqual(BingoPresenter.starsForScore(0.85), 2)
    }

    func test_starsForScore_oneStar() {
        XCTAssertEqual(BingoPresenter.starsForScore(0.5), 1)
        XCTAssertEqual(BingoPresenter.starsForScore(0.65), 1)
    }

    func test_starsForScore_zeroStars() {
        XCTAssertEqual(BingoPresenter.starsForScore(0.0), 0)
        XCTAssertEqual(BingoPresenter.starsForScore(0.49), 0)
    }

    // MARK: - 7. cancel не вызывает presentCompleteGame

    func test_cancel_doesNotCallComplete() {
        let (sut, spy) = makeSUT()
        sut.loadGame(.init(activity: makeActivity()))
        sut.cancel()
        XCTAssertFalse(spy.completeGameCalled)
    }

    // MARK: - 8. checkBingo без помеченных — пустой список

    func test_checkBingo_noMarked_returnsEmpty() {
        let (sut, _) = makeSUT()
        sut.loadGame(.init(activity: makeActivity()))
        let lines = sut.checkBingo()
        XCTAssertTrue(lines.isEmpty)
    }

    // MARK: - Batch 1: расширенное покрытие

    func test_loadGame_totalWordsIs25() {
        let (sut, spy) = makeSUT()
        sut.loadGame(.init(activity: makeActivity()))
        XCTAssertEqual(spy.lastLoadResponse?.totalWords, 25)
    }

    func test_loadGame_allCellsUnmarkedInitially() {
        let (sut, spy) = makeSUT()
        sut.loadGame(.init(activity: makeActivity()))
        let markedCount = spy.lastLoadResponse?.cells.filter(\.isMarked).count ?? -1
        XCTAssertEqual(markedCount, 0)
    }

    func test_markCell_unknownCellId_ignored() {
        let (sut, spy) = makeSUT()
        sut.loadGame(.init(activity: makeActivity()))
        spy.markCellCalled = false
        sut.markCell(.init(cellId: UUID()))
        XCTAssertFalse(spy.markCellCalled)
    }

    func test_markCell_allMarked_completesGame() {
        let (sut, spy) = makeSUT()
        sut.loadGame(.init(activity: makeActivity()))
        guard let cells = spy.lastLoadResponse?.cells else { return }
        for cell in cells {
            sut.markCell(.init(cellId: cell.id))
        }
        XCTAssertTrue(spy.completeGameCalled, "Пометка всех 25 клеток завершает игру")
    }

    func test_markCell_allMarked_scoreIsOne() {
        let (sut, spy) = makeSUT()
        sut.loadGame(.init(activity: makeActivity()))
        guard let cells = spy.lastLoadResponse?.cells else { return }
        for cell in cells {
            sut.markCell(.init(cellId: cell.id))
        }
        XCTAssertEqual(spy.lastCompleteResponse?.score, 1.0)
    }

    func test_completeGame_twice_secondIgnored() {
        let (sut, spy) = makeSUT()
        sut.loadGame(.init(activity: makeActivity()))
        sut.completeGame()
        spy.completeGameCalled = false
        sut.completeGame()
        XCTAssertFalse(spy.completeGameCalled, "Повторный completeGame игнорируется")
    }

    func test_completeGame_reportsMarkedCount() {
        let (sut, spy) = makeSUT()
        sut.loadGame(.init(activity: makeActivity()))
        guard let firstCell = spy.lastLoadResponse?.cells.first else { return }
        sut.markCell(.init(cellId: firstCell.id))
        sut.completeGame()
        XCTAssertEqual(spy.lastCompleteResponse?.markedCells, 1)
        XCTAssertEqual(spy.lastCompleteResponse?.totalCells, 25)
    }

    func test_cancel_blocksMarkCell() {
        let (sut, spy) = makeSUT()
        sut.loadGame(.init(activity: makeActivity()))
        sut.cancel()
        spy.markCellCalled = false
        guard let firstCell = spy.lastLoadResponse?.cells.first else { return }
        sut.markCell(.init(cellId: firstCell.id))
        XCTAssertFalse(spy.markCellCalled, "После cancel markCell не обрабатывается")
    }

    func test_callNextWord_afterCancel_ignored() {
        let (sut, spy) = makeSUT()
        sut.loadGame(.init(activity: makeActivity()))
        sut.cancel()
        spy.callWordCalled = false
        sut.callNextWord()
        XCTAssertFalse(spy.callWordCalled)
    }

    func test_resolveSoundGroup_unknownFallback() {
        XCTAssertEqual(BingoInteractor.resolveSoundGroup(for: "Б"), "whistling")
        XCTAssertEqual(BingoInteractor.resolveSoundGroup(for: ""), "whistling")
    }

    func test_loadGame_velarGroup_25Cells() {
        let (sut, spy) = makeSUT()
        sut.loadGame(.init(activity: makeActivity(sound: "К")))
        XCTAssertEqual(spy.lastLoadResponse?.cells.count, 25)
        XCTAssertTrue(spy.lastLoadResponse?.cells.allSatisfy { $0.soundGroup == "velar" } ?? false)
    }
}
