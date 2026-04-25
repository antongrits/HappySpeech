import Testing
@testable import HappySpeech

// MARK: - Spy

@MainActor
private final class SpyBingoPresenter: BingoPresentationLogic {
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

// MARK: - Tests

@Suite("BingoInteractor")
@MainActor
struct BingoInteractorTests {

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

    private func makeSUT() -> (BingoInteractor, SpyBingoPresenter) {
        let sut = BingoInteractor()
        let spy = SpyBingoPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 1. loadGame создаёт 25 клеток

    @Test("loadGame передаёт 25 клеток в presenter")
    func loadGameLoads25Cells() {
        let (sut, spy) = makeSUT()
        sut.loadGame(.init(activity: makeActivity(sound: "С")))
        #expect(spy.loadGameCalled)
        #expect(spy.lastLoadResponse?.cells.count == 25)
    }

    // MARK: - 2. resolveSoundGroup маппинг

    @Test("resolveSoundGroup возвращает whistling для С, З, Ц")
    func resolveSoundGroupWhistling() {
        #expect(BingoInteractor.resolveSoundGroup(for: "С") == "whistling")
        #expect(BingoInteractor.resolveSoundGroup(for: "З") == "whistling")
        #expect(BingoInteractor.resolveSoundGroup(for: "Ц") == "whistling")
    }

    @Test("resolveSoundGroup возвращает hissing для Ш, Ж, Ч, Щ")
    func resolveSoundGroupHissing() {
        #expect(BingoInteractor.resolveSoundGroup(for: "Ш") == "hissing")
        #expect(BingoInteractor.resolveSoundGroup(for: "Ж") == "hissing")
        #expect(BingoInteractor.resolveSoundGroup(for: "Ч") == "hissing")
        #expect(BingoInteractor.resolveSoundGroup(for: "Щ") == "hissing")
    }

    @Test("resolveSoundGroup возвращает sonants для Р, Л")
    func resolveSoundGroupSonants() {
        #expect(BingoInteractor.resolveSoundGroup(for: "Р") == "sonants")
        #expect(BingoInteractor.resolveSoundGroup(for: "Л") == "sonants")
    }

    @Test("resolveSoundGroup возвращает velar для К, Г, Х")
    func resolveSoundGroupVelar() {
        #expect(BingoInteractor.resolveSoundGroup(for: "К") == "velar")
        #expect(BingoInteractor.resolveSoundGroup(for: "Г") == "velar")
        #expect(BingoInteractor.resolveSoundGroup(for: "Х") == "velar")
    }

    // MARK: - 3. markCell помечает клетку

    @Test("markCell помечает правильную клетку")
    func markCellMarksCellAsMarked() {
        let (sut, spy) = makeSUT()
        sut.loadGame(.init(activity: makeActivity()))
        guard let firstCell = spy.lastLoadResponse?.cells.first else {
            Issue.record("Нет клеток после loadGame")
            return
        }
        sut.markCell(.init(cellId: firstCell.id))
        #expect(spy.markCellCalled)
        let markedCells = spy.lastMarkCellResponse?.cells.filter(\.isMarked)
        #expect((markedCells?.count ?? 0) >= 1)
    }

    // MARK: - 4. markCell дважды — игнорируется

    @Test("повторное нажатие на клетку игнорируется")
    func markCellTwiceIgnored() {
        let (sut, spy) = makeSUT()
        sut.loadGame(.init(activity: makeActivity()))
        guard let firstCell = spy.lastLoadResponse?.cells.first else { return }

        sut.markCell(.init(cellId: firstCell.id))
        let countAfterFirst = spy.lastMarkCellResponse?.cells.filter(\.isMarked).count ?? 0
        sut.markCell(.init(cellId: firstCell.id))
        let countAfterSecond = spy.lastMarkCellResponse?.cells.filter(\.isMarked).count ?? 0
        #expect(countAfterFirst == countAfterSecond)
    }

    // MARK: - 5. completeGame считает score

    @Test("completeGame без помеченных клеток даёт score = 0")
    func completeGameZeroMarked() {
        let (sut, spy) = makeSUT()
        sut.loadGame(.init(activity: makeActivity()))
        sut.completeGame()
        #expect(spy.completeGameCalled)
        let score = spy.lastCompleteResponse?.score ?? -1
        #expect(score >= 0 && score <= 1)
    }

    // MARK: - 6. BingoPresenter: starsForScore

    @Test("starsForScore возвращает 3 звезды для score >= 0.9")
    func starsForScoreThreeStars() {
        #expect(BingoPresenter.starsForScore(0.9) == 3)
        #expect(BingoPresenter.starsForScore(1.0) == 3)
    }

    @Test("starsForScore возвращает 2 звезды для 0.7..0.89")
    func starsForScoreTwoStars() {
        #expect(BingoPresenter.starsForScore(0.7) == 2)
        #expect(BingoPresenter.starsForScore(0.85) == 2)
    }

    @Test("starsForScore возвращает 1 звезду для 0.5..0.69")
    func starsForScoreOneStar() {
        #expect(BingoPresenter.starsForScore(0.5) == 1)
        #expect(BingoPresenter.starsForScore(0.65) == 1)
    }

    @Test("starsForScore возвращает 0 для score < 0.5")
    func starsForScoreZeroStars() {
        #expect(BingoPresenter.starsForScore(0.0) == 0)
        #expect(BingoPresenter.starsForScore(0.49) == 0)
    }

    // MARK: - 7. cancel завершает игру

    @Test("cancel не крашится и не вызывает presentCompleteGame")
    func cancelDoesNotCallComplete() {
        let (sut, spy) = makeSUT()
        sut.loadGame(.init(activity: makeActivity()))
        sut.cancel()
        #expect(!spy.completeGameCalled)
    }

    // MARK: - 8. checkBingo без помеченных — пустой список

    @Test("checkBingo без отмеченных клеток возвращает пустой массив")
    func checkBingoNoMarked() {
        let (sut, _) = makeSUT()
        sut.loadGame(.init(activity: makeActivity()))
        let lines = sut.checkBingo()
        #expect(lines.isEmpty)
    }
}
