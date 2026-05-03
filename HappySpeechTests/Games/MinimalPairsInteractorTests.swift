@testable import HappySpeech
import XCTest

// MARK: - Spy

@MainActor
private final class SpyMinimalPairsPresenter: MinimalPairsPresentationLogic {
    var loadSessionCalled = false
    var startRoundCalled = false
    var selectOptionCalled = false
    var completeCalled = false

    var lastLoadSession: MinimalPairsModels.LoadSession.Response?
    var lastStartRound: MinimalPairsModels.StartRound.Response?
    var lastSelectOption: MinimalPairsModels.SelectOption.Response?
    var lastComplete: MinimalPairsModels.CompleteSession.Response?

    func presentLoadSession(_ response: MinimalPairsModels.LoadSession.Response) {
        loadSessionCalled = true
        lastLoadSession = response
    }
    func presentStartRound(_ response: MinimalPairsModels.StartRound.Response) {
        startRoundCalled = true
        lastStartRound = response
    }
    func presentSelectOption(_ response: MinimalPairsModels.SelectOption.Response) {
        selectOptionCalled = true
        lastSelectOption = response
    }
    func presentCompleteSession(_ response: MinimalPairsModels.CompleteSession.Response) {
        completeCalled = true
        lastComplete = response
    }
    func presentReplayWord(_ response: MinimalPairsModels.ReplayWord.Response) {}
    func presentHint(_ response: MinimalPairsModels.RequestHint.Response) {}
    func presentBonusRoundAdded(_ response: MinimalPairsModels.BonusRoundAdded.Response) {}
}

// MARK: - Tests

@MainActor
final class MinimalPairsInteractorTests: XCTestCase {

    private func makeSUT() -> (MinimalPairsInteractor, SpyMinimalPairsPresenter) {
        let sut = MinimalPairsInteractor()
        let spy = SpyMinimalPairsPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 1. loadSession загружает 10 раундов

    func test_loadSession_loads10Rounds() async {
        let (sut, spy) = makeSUT()
        await sut.loadSession(.init(soundContrast: "С-Ш", childName: "Маша", childAge: 8))
        XCTAssertTrue(spy.loadSessionCalled)
        XCTAssertEqual(spy.lastLoadSession?.rounds.count, 10)
    }

    // MARK: - 2. startRound загружает первый раунд

    func test_startRound_zero_roundNumber1() async {
        let (sut, spy) = makeSUT()
        await sut.loadSession(.init(soundContrast: "С-Ш", childName: "Маша", childAge: 8))
        await sut.startRound(.init(roundIndex: 0))
        XCTAssertTrue(spy.startRoundCalled)
        XCTAssertEqual(spy.lastStartRound?.roundNumber, 1)
        XCTAssertEqual(spy.lastStartRound?.total, 10)
    }

    // MARK: - 3. selectOption: правильный выбор

    func test_selectOption_correct() async {
        let (sut, spy) = makeSUT()
        await sut.loadSession(.init(soundContrast: "С-Ш", childName: "Маша", childAge: 8))
        await sut.startRound(.init(roundIndex: 0))
        await sut.selectOption(.init(selectedIsTarget: true))
        XCTAssertTrue(spy.selectOptionCalled)
        XCTAssertEqual(spy.lastSelectOption?.correct, true)
    }

    // MARK: - 4. selectOption: неправильный выбор

    func test_selectOption_wrong() async {
        let (sut, spy) = makeSUT()
        await sut.loadSession(.init(soundContrast: "С-Ш", childName: "Маша", childAge: 8))
        await sut.startRound(.init(roundIndex: 0))
        await sut.selectOption(.init(selectedIsTarget: false))
        XCTAssertEqual(spy.lastSelectOption?.correct, false)
    }

    // MARK: - 5. correctAnswer передаётся в response

    func test_selectOption_transmitsCorrectAnswer() async {
        let (sut, spy) = makeSUT()
        await sut.loadSession(.init(soundContrast: "С-Ш", childName: "Маша", childAge: 8))
        await sut.startRound(.init(roundIndex: 0))
        let targetWord = spy.lastStartRound?.pair.targetWord ?? ""
        await sut.selectOption(.init(selectedIsTarget: true))
        XCTAssertEqual(spy.lastSelectOption?.correctAnswer, targetWord)
    }

    // MARK: - 6. completeSession без ответов → correctCount = 0

    func test_completeSession_noAnswers_correctCountZero() async {
        let (sut, spy) = makeSUT()
        await sut.loadSession(.init(soundContrast: "С-Ш", childName: "Маша", childAge: 8))
        await sut.completeSession(.init())
        XCTAssertTrue(spy.completeCalled)
        XCTAssertEqual(spy.lastComplete?.correctCount, 0)
        XCTAssertEqual(spy.lastComplete?.totalRounds, 10)
    }

    // MARK: - 7. startRound с out-of-bounds не крашится

    func test_startRound_outOfBounds_ignored() async {
        let (sut, spy) = makeSUT()
        await sut.loadSession(.init(soundContrast: "С-Ш", childName: "Маша", childAge: 8))
        await sut.startRound(.init(roundIndex: 99))
        XCTAssertFalse(spy.startRoundCalled)
    }

    // MARK: - 8. MinimalPairRound.rounds возвращает count раундов

    func test_roundsFactory_returnsCount() {
        let rounds = MinimalPairRound.rounds(count: 5, contrast: "Р-Л")
        XCTAssertEqual(rounds.count, 5)
    }
}
