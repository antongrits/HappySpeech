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
}
