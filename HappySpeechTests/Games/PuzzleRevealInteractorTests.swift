@testable import HappySpeech
import XCTest

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

@MainActor
final class PuzzleRevealInteractorTests: XCTestCase {

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

    func test_loadPuzzle_creates9Tiles() {
        let (sut, spy) = makeSUT()
        sut.loadPuzzle(.init(activity: makeActivity(), puzzleIndex: 0))
        XCTAssertTrue(spy.loadPuzzleCalled)
        XCTAssertEqual(spy.lastLoadPuzzle?.tiles.count, 9)
    }

    // MARK: - 2. все плитки изначально закрыты

    func test_allTilesClosed_onLoad() {
        let (sut, spy) = makeSUT()
        sut.loadPuzzle(.init(activity: makeActivity(), puzzleIndex: 0))
        guard let tiles = spy.lastLoadPuzzle?.tiles else { return }
        let openTiles = tiles.filter(\.isRevealed)
        XCTAssertTrue(openTiles.isEmpty)
    }

    // MARK: - 3. resolveSoundGroup

    func test_resolveSoundGroup_allGroups() {
        XCTAssertEqual(PuzzleRevealInteractor.resolveSoundGroup(for: "С"), "whistling")
        XCTAssertEqual(PuzzleRevealInteractor.resolveSoundGroup(for: "Ш"), "hissing")
        XCTAssertEqual(PuzzleRevealInteractor.resolveSoundGroup(for: "Р"), "sonants")
        XCTAssertEqual(PuzzleRevealInteractor.resolveSoundGroup(for: "К"), "velar")
    }

    // MARK: - 4. tileCount = 9, totalPuzzles = 5

    func test_configConstants() {
        XCTAssertEqual(PuzzleRevealInteractor.tileCount, 9)
        XCTAssertEqual(PuzzleRevealInteractor.totalPuzzles, 5)
    }

    // MARK: - 5. startRecord вызывает presentStartRecord

    func test_startRecord_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.loadPuzzle(.init(activity: makeActivity(), puzzleIndex: 0))
        sut.startRecord(.init())
        XCTAssertTrue(spy.startRecordCalled)
    }

    // MARK: - 6. cancel не крашится до loadPuzzle

    func test_cancel_beforeLoad_doesNotCrash() {
        let (sut, _) = makeSUT()
        sut.cancel()
        XCTAssertTrue(true)
    }

    // MARK: - 7. complete вызывает presenter

    func test_complete_callsPresenter() {
        let (sut, spy) = makeSUT()
        sut.complete(.init())
        XCTAssertTrue(spy.completeCalled)
    }

    // MARK: - 8. loadPuzzle работает для всех групп звуков

    func test_loadPuzzle_allSoundGroups() {
        for sound in ["С", "Ш", "Р", "К"] {
            let (sut, spy) = makeSUT()
            sut.loadPuzzle(.init(activity: makeActivity(sound: sound), puzzleIndex: 0))
            XCTAssertEqual(spy.lastLoadPuzzle?.tiles.count, 9, "Sound \(sound) должен давать 9 плиток")
        }
    }

    // MARK: - Batch 1: расширенное покрытие

    func test_loadPuzzle_setsPuzzleIndex() {
        let (sut, spy) = makeSUT()
        sut.loadPuzzle(.init(activity: makeActivity(), puzzleIndex: 2))
        XCTAssertEqual(spy.lastLoadPuzzle?.puzzleIndex, 2)
        XCTAssertEqual(spy.lastLoadPuzzle?.totalPuzzles, 5)
    }

    func test_loadPuzzle_negativeIndex_clampedToZero() {
        let (sut, spy) = makeSUT()
        sut.loadPuzzle(.init(activity: makeActivity(), puzzleIndex: -3))
        XCTAssertEqual(spy.lastLoadPuzzle?.puzzleIndex, 0)
    }

    func test_loadPuzzle_largeIndex_clampedToLast() {
        let (sut, spy) = makeSUT()
        sut.loadPuzzle(.init(activity: makeActivity(), puzzleIndex: 99))
        XCTAssertLessThanOrEqual(spy.lastLoadPuzzle?.puzzleIndex ?? 99, 4)
    }

    func test_loadPuzzle_attemptNumberStartsAt1() {
        let (sut, spy) = makeSUT()
        sut.loadPuzzle(.init(activity: makeActivity(), puzzleIndex: 0))
        XCTAssertEqual(spy.lastLoadPuzzle?.attemptNumber, 1)
    }

    func test_loadPuzzle_wordNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.loadPuzzle(.init(activity: makeActivity(sound: "Ш"), puzzleIndex: 0))
        XCTAssertFalse(spy.lastLoadPuzzle?.word.isEmpty ?? true)
        XCTAssertFalse(spy.lastLoadPuzzle?.hintText.isEmpty ?? true)
    }

    func test_startRecord_twice_secondIgnored() {
        let (sut, spy) = makeSUT()
        sut.loadPuzzle(.init(activity: makeActivity(), puzzleIndex: 0))
        sut.startRecord(.init())
        spy.startRecordCalled = false
        sut.startRecord(.init())
        XCTAssertFalse(spy.startRecordCalled, "Повторный startRecord игнорируется")
    }

    func test_stopRecord_withoutStart_ignored() {
        let (sut, spy) = makeSUT()
        sut.loadPuzzle(.init(activity: makeActivity(), puzzleIndex: 0))
        sut.stopRecord(.init())
        XCTAssertFalse(spy.stopRecordCalled, "stopRecord без startRecord игнорируется")
    }

    func test_stopRecord_afterStart_emitsStopRecord() {
        let (sut, spy) = makeSUT()
        sut.loadPuzzle(.init(activity: makeActivity(), puzzleIndex: 0))
        sut.startRecord(.init())
        sut.stopRecord(.init())
        // presentStopRecord вызывается синхронно (revealTile может быть async через ASR)
        XCTAssertTrue(spy.stopRecordCalled)
    }

    func test_stopRecord_revealsTile_eventually() async {
        let (sut, spy) = makeSUT()
        sut.loadPuzzle(.init(activity: makeActivity(), puzzleIndex: 0))
        sut.startRecord(.init())
        sut.stopRecord(.init())
        // revealTile может прийти синхронно (fallback) или асинхронно (ASR-путь)
        for _ in 0..<20 where !spy.revealTileCalled {
            try? await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertTrue(spy.revealTileCalled)
        let score = spy.lastRevealTile?.score ?? -1
        XCTAssertGreaterThanOrEqual(score, 0)
        XCTAssertLessThanOrEqual(score, 1)
    }

    func test_nextPuzzle_lastPuzzle_completes() {
        let (sut, spy) = makeSUT()
        sut.loadPuzzle(.init(activity: makeActivity(), puzzleIndex: 4))
        sut.nextPuzzle(.init())
        XCTAssertTrue(spy.completeCalled)
    }

    func test_nextPuzzle_midPuzzle_loadsNext() {
        let (sut, spy) = makeSUT()
        sut.loadPuzzle(.init(activity: makeActivity(), puzzleIndex: 0))
        sut.nextPuzzle(.init())
        XCTAssertTrue(spy.nextPuzzleCalled)
        XCTAssertEqual(spy.lastLoadPuzzle?.puzzleIndex, 1)
    }

    func test_complete_emptyScores_starsAtLeastOne() {
        let (sut, spy) = makeSUT()
        sut.complete(.init())
        // Пустой allRevealScores → avg 0 → 1 звезда (< 0.5)
        XCTAssertGreaterThanOrEqual(spy.lastComplete?.starsEarned ?? 0, 1)
    }

    func test_resolveSoundGroup_unknownFallback() {
        XCTAssertEqual(PuzzleRevealInteractor.resolveSoundGroup(for: "Б"), "whistling")
        XCTAssertEqual(PuzzleRevealInteractor.resolveSoundGroup(for: ""), "whistling")
    }
}
