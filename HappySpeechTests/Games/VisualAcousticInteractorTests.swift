@testable import HappySpeech
import XCTest

// MARK: - Spy

@MainActor
private final class SpyVisualAcousticPresenter: VisualAcousticPresentationLogic {
    var loadRoundCalled = false
    var playAudioCalled = false
    var chooseWordCalled = false
    var nextRoundCalled = false
    var completeCalled = false

    var lastLoadRound: VisualAcousticModels.LoadRound.Response?
    var lastChoiceWord: VisualAcousticModels.ChoiceWord.Response?
    var lastComplete: VisualAcousticModels.Complete.Response?

    func presentLoadRound(_ response: VisualAcousticModels.LoadRound.Response) {
        loadRoundCalled = true
        lastLoadRound = response
    }
    func presentPlayAudio(_ response: VisualAcousticModels.PlayAudio.Response) {
        playAudioCalled = true
    }
    func presentChoiceWord(_ response: VisualAcousticModels.ChoiceWord.Response) {
        chooseWordCalled = true
        lastChoiceWord = response
    }
    func presentNextRound(_ response: VisualAcousticModels.NextRound.Response) {
        nextRoundCalled = true
    }
    func presentComplete(_ response: VisualAcousticModels.Complete.Response) {
        completeCalled = true
        lastComplete = response
    }
}

// MARK: - Tests

@MainActor
final class VisualAcousticInteractorTests: XCTestCase {

    private func makeActivity(sound: String = "С") -> SessionActivity {
        SessionActivity(
            id: "test-va",
            gameType: .sorting,
            lessonId: "lesson-1",
            soundTarget: sound,
            difficulty: 1,
            isCompleted: false,
            score: nil
        )
    }

    private func makeSUT() -> (VisualAcousticInteractor, SpyVisualAcousticPresenter) {
        let sut = VisualAcousticInteractor()
        let spy = SpyVisualAcousticPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 1. loadRound загружает первый раунд

    func test_loadRound_loadsFirstRound() {
        let (sut, spy) = makeSUT()
        sut.loadRound(.init(activity: makeActivity(), roundIndex: 0))
        XCTAssertTrue(spy.loadRoundCalled)
        XCTAssertEqual(spy.lastLoadRound?.roundIndex, 0)
        XCTAssertEqual(spy.lastLoadRound?.totalRounds, 6)
    }

    // MARK: - 2. buildRounds возвращает 6 раундов

    func test_buildRounds_sixPerGroup() {
        for group in ["whistling", "hissing", "sonants", "velar"] {
            let rounds = VisualAcousticInteractor.buildRounds(for: group, total: 6)
            XCTAssertEqual(rounds.count, 6, "Группа \(group) должна иметь 6 раундов")
        }
    }

    // MARK: - 3. resolveSoundGroup

    func test_resolveSoundGroup_allGroups() {
        XCTAssertEqual(VisualAcousticInteractor.resolveSoundGroup(for: "С"), "whistling")
        XCTAssertEqual(VisualAcousticInteractor.resolveSoundGroup(for: "Ш"), "hissing")
        XCTAssertEqual(VisualAcousticInteractor.resolveSoundGroup(for: "Р"), "sonants")
        XCTAssertEqual(VisualAcousticInteractor.resolveSoundGroup(for: "К"), "velar")
    }

    // MARK: - 4. chooseWord: правильный ответ

    func test_chooseWord_correct() {
        let (sut, spy) = makeSUT()
        sut.loadRound(.init(activity: makeActivity(), roundIndex: 0))
        guard let round = spy.lastLoadRound?.round else { return }
        sut.chooseWord(.init(choiceIndex: round.correctIndex))
        XCTAssertTrue(spy.chooseWordCalled)
        XCTAssertEqual(spy.lastChoiceWord?.isCorrect, true)
    }

    // MARK: - 5. chooseWord: неправильный ответ

    func test_chooseWord_wrong() {
        let (sut, spy) = makeSUT()
        sut.loadRound(.init(activity: makeActivity(), roundIndex: 0))
        guard let round = spy.lastLoadRound?.round else { return }
        let wrongIdx = round.correctIndex == 0 ? 1 : 0
        sut.chooseWord(.init(choiceIndex: wrongIdx))
        XCTAssertEqual(spy.lastChoiceWord?.isCorrect, false)
    }

    // MARK: - 6. complete после 0 правильных → score = 0

    func test_complete_zeroCorrect_scoreZero() {
        let (sut, spy) = makeSUT()
        sut.loadRound(.init(activity: makeActivity(), roundIndex: 0))
        sut.complete()
        XCTAssertTrue(spy.completeCalled)
        XCTAssertEqual(spy.lastComplete?.score, 0.0)
    }

    // MARK: - 7. cancel не вызывает complete

    func test_cancel_doesNotComplete() {
        let (sut, spy) = makeSUT()
        sut.loadRound(.init(activity: makeActivity(), roundIndex: 0))
        sut.cancel()
        XCTAssertFalse(spy.completeCalled)
    }

    // MARK: - 8. correctWord передаётся в response

    func test_correctWord_transmitted() {
        let (sut, spy) = makeSUT()
        sut.loadRound(.init(activity: makeActivity(), roundIndex: 0))
        guard let round = spy.lastLoadRound?.round else { return }
        sut.chooseWord(.init(choiceIndex: round.correctIndex))
        let expectedWord = round.choices[round.correctIndex]
        XCTAssertEqual(spy.lastChoiceWord?.correctWord, expectedWord)
    }
}
