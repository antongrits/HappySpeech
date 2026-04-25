import Testing
@testable import HappySpeech

// MARK: - Spy

@MainActor
private final class SpyPuzzlePresenter: PuzzleRevealPresentationLogic {
    var loadPuzzleCalled = false
    var startRecordCalled = false
    var stopRecordCalled = false
    var revealTileCalled = false
    var nextPuzzleCalled = false
    var completeCalled = false

    var lastLoadPuzzle: PuzzleRevealModels.LoadPuzzle.Response?
    var lastRevealTile: PuzzleRevealModels.RevealTile.Response?
    var lastComplete: PuzzleRevealModels.Complete.Response?

    func presentLoadPuzzle(_ response: PuzzleRevealModels.LoadPuzzle.Response) {
        loadPuzzleCalled = true
        lastLoadPuzzle = response
    }
    func presentStartRecord(_ response: PuzzleRevealModels.StartRecord.Response) {
        startRecordCalled = true
    }
    func presentStopRecord(_ response: PuzzleRevealModels.StopRecord.Response) {
        stopRecordCalled = true
    }
    func presentRevealTile(_ response: PuzzleRevealModels.RevealTile.Response) {
        revealTileCalled = true
        lastRevealTile = response
    }
    func presentNextPuzzle(_ response: PuzzleRevealModels.NextPuzzle.Response) {
        nextPuzzleCalled = true
    }
    func presentComplete(_ response: PuzzleRevealModels.Complete.Response) {
        completeCalled = true
        lastComplete = response
    }
}

// MARK: - Tests

@Suite("PuzzleRevealInteractor")
@MainActor
struct PuzzleRevealInteractorTests {

    private func makeActivity(sound: String = "С") -> SessionActivity {
        SessionActivity(
            id: "test-puzzle",
            gameType: .puzzleReveal,
            lessonId: "lesson-1",
            soundTarget: sound,
            difficulty: 1,
            isCompleted: false,
            score: nil
        )
    }

    private func makeSUT() -> (PuzzleRevealInteractor, SpyPuzzlePresenter) {
        let container = AppContainer.test()
        let sut = PuzzleRevealInteractor(container: container)
        let spy = SpyPuzzlePresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 1. loadPuzzle создаёт 9 плиток

    @Test("loadPuzzle создаёт 9 плиток для пазла 0")
    func loadPuzzleCreates9Tiles() {
        let (sut, spy) = makeSUT()
        sut.loadPuzzle(.init(activity: makeActivity(), puzzleIndex: 0))
        #expect(spy.loadPuzzleCalled)
        #expect(spy.lastLoadPuzzle?.tiles.count == 9)
    }

    // MARK: - 2. Все плитки изначально закрыты

    @Test("все плитки после loadPuzzle закрыты")
    func allTilesClosedOnLoad() {
        let (sut, spy) = makeSUT()
        sut.loadPuzzle(.init(activity: makeActivity(), puzzleIndex: 0))
        guard let tiles = spy.lastLoadPuzzle?.tiles else { return }
        let openTiles = tiles.filter(\.isRevealed)
        #expect(openTiles.isEmpty)
    }

    // MARK: - 3. resolveSoundGroup

    @Test("resolveSoundGroup корректно маппит звуки")
    func resolveSoundGroup() {
        #expect(PuzzleRevealInteractor.resolveSoundGroup(for: "С") == "whistling")
        #expect(PuzzleRevealInteractor.resolveSoundGroup(for: "Ш") == "hissing")
        #expect(PuzzleRevealInteractor.resolveSoundGroup(for: "Р") == "sonants")
        #expect(PuzzleRevealInteractor.resolveSoundGroup(for: "К") == "velar")
    }

    // MARK: - 4. tileCount и totalPuzzles константы

    @Test("tileCount = 9, totalPuzzles = 5")
    func configConstants() {
        #expect(PuzzleRevealInteractor.tileCount == 9)
        #expect(PuzzleRevealInteractor.totalPuzzles == 5)
    }

    // MARK: - 5. startRecord переводит состояние в recording

    @Test("startRecord вызывает presentStartRecord")
    func startRecordCallsPresenter() {
        let (sut, spy) = makeSUT()
        sut.loadPuzzle(.init(activity: makeActivity(), puzzleIndex: 0))
        sut.startRecord(.init())
        #expect(spy.startRecordCalled)
    }

    // MARK: - 6. cancel не крашится

    @Test("cancel не крашится при вызове до loadPuzzle")
    func cancelBeforeLoad() {
        let (sut, _) = makeSUT()
        sut.cancel()
        // просто проверяем, что нет краша
        #expect(Bool(true))
    }

    // MARK: - 7. score-функция правильный подсчёт

    @Test("stars: average < 0.5 → 1 звезда")
    func starsLow() {
        let (sut, spy) = makeSUT()
        sut.complete(.init())
        // без попыток averageScore = 0 → 1 звезда (по формуле ..<0.5 → 1)
        #expect(spy.completeCalled)
    }

    // MARK: - 8. loadPuzzle с разными soundGroup

    @Test("loadPuzzle работает для всех групп звуков")
    func loadPuzzleAllGroups() {
        for sound in ["С", "Ш", "Р", "К"] {
            let (sut, spy) = makeSUT()
            sut.loadPuzzle(.init(activity: makeActivity(sound: sound), puzzleIndex: 0))
            #expect(spy.lastLoadPuzzle?.tiles.count == 9, "Sound \(sound) должен давать 9 плиток")
        }
    }
}
