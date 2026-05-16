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

    // MARK: - Batch 1: расширенное покрытие

    func test_sessionRoundCount_byAge() async {
        let (sut5, spy5) = makeSUT()
        await sut5.loadSession(.init(soundContrast: "С-Ш", childName: "Маша", childAge: 5))
        XCTAssertEqual(spy5.lastLoadSession?.rounds.count, 7)

        let (sut6, spy6) = makeSUT()
        await sut6.loadSession(.init(soundContrast: "С-Ш", childName: "Маша", childAge: 6))
        XCTAssertEqual(spy6.lastLoadSession?.rounds.count, 8)

        let (sut7, spy7) = makeSUT()
        await sut7.loadSession(.init(soundContrast: "С-Ш", childName: "Маша", childAge: 7))
        XCTAssertEqual(spy7.lastLoadSession?.rounds.count, 9)

        let (sut8, spy8) = makeSUT()
        await sut8.loadSession(.init(soundContrast: "С-Ш", childName: "Маша", childAge: 8))
        XCTAssertEqual(spy8.lastLoadSession?.rounds.count, 10)
    }

    func test_buildRounds_emptyContrast_usesFullCatalog() {
        let rounds = MinimalPairsInteractor.buildRounds(contrast: "", count: 10)
        XCTAssertEqual(rounds.count, 10)
    }

    func test_buildRounds_unknownContrast_fallsBack() {
        // Несуществующий контраст → pool пуст → используется весь каталог
        let rounds = MinimalPairsInteractor.buildRounds(contrast: "Я-Ю", count: 5)
        XCTAssertEqual(rounds.count, 5)
    }

    func test_selectOption_streakIncrements() async {
        let (sut, spy) = makeSUT()
        await sut.loadSession(.init(soundContrast: "С-Ш", childName: "Маша", childAge: 8))
        await sut.startRound(.init(roundIndex: 0))
        await sut.selectOption(.init(selectedIsTarget: true))
        XCTAssertEqual(spy.lastSelectOption?.streakCount, 1)
    }

    func test_selectOption_wrongResetsStreak() async {
        let (sut, spy) = makeSUT()
        await sut.loadSession(.init(soundContrast: "С-Ш", childName: "Маша", childAge: 8))
        await sut.startRound(.init(roundIndex: 0))
        await sut.selectOption(.init(selectedIsTarget: true))
        await sut.startRound(.init(roundIndex: 1))
        await sut.selectOption(.init(selectedIsTarget: false))
        XCTAssertEqual(spy.lastSelectOption?.streakCount, 0)
    }

    func test_completeSession_pairAccuracyPopulated() async {
        let (sut, spy) = makeSUT()
        await sut.loadSession(.init(soundContrast: "С-Ш", childName: "Маша", childAge: 8))
        await sut.startRound(.init(roundIndex: 0))
        await sut.selectOption(.init(selectedIsTarget: true))
        await sut.completeSession(.init())
        XCTAssertFalse(spy.lastComplete?.pairAccuracy.isEmpty ?? true)
    }

    func test_completeSession_afterCorrect_correctCountPositive() async {
        let (sut, spy) = makeSUT()
        await sut.loadSession(.init(soundContrast: "С-Ш", childName: "Маша", childAge: 8))
        await sut.startRound(.init(roundIndex: 0))
        await sut.selectOption(.init(selectedIsTarget: true))
        await sut.completeSession(.init())
        XCTAssertEqual(spy.lastComplete?.correctCount, 1)
    }

    func test_completeSession_twice_secondIgnored() async {
        let (sut, spy) = makeSUT()
        await sut.loadSession(.init(soundContrast: "С-Ш", childName: "Маша", childAge: 8))
        await sut.completeSession(.init())
        spy.completeCalled = false
        await sut.completeSession(.init())
        XCTAssertFalse(spy.completeCalled, "Повторный complete игнорируется (isSessionOver)")
    }

    func test_cancelSession_doesNotComplete() async {
        let (sut, spy) = makeSUT()
        await sut.loadSession(.init(soundContrast: "С-Ш", childName: "Маша", childAge: 8))
        sut.cancelSession()
        await sut.completeSession(.init())
        XCTAssertFalse(spy.completeCalled)
    }

    func test_requestHint_capturedThroughHintSpy() async {
        let spy = HintSpyMinimalPairsPresenter()
        let sut = MinimalPairsInteractor()
        sut.presenter = spy
        await sut.loadSession(.init(soundContrast: "С-Ш", childName: "Маша", childAge: 8))
        await sut.startRound(.init(roundIndex: 0))
        await sut.requestHint(.init())
        XCTAssertEqual(spy.lastHint?.level, .highlight)
        await sut.requestHint(.init())
        XCTAssertEqual(spy.lastHint?.level, .voiceClarification)
        // Третий запрос — cap reached
        await sut.requestHint(.init())
        XCTAssertEqual(spy.lastHint?.capReached, true)
    }

    func test_replayWord_capReachedAfterThree() async {
        let spy = HintSpyMinimalPairsPresenter()
        let sut = MinimalPairsInteractor()
        sut.presenter = spy
        await sut.loadSession(.init(soundContrast: "С-Ш", childName: "Маша", childAge: 8))
        await sut.startRound(.init(roundIndex: 0))
        await sut.replayCurrentWord()
        await sut.replayCurrentWord()
        await sut.replayCurrentWord()
        await sut.replayCurrentWord()
        XCTAssertEqual(spy.lastReplay?.capReached, true)
    }

    func test_hintLevels_rawValues() {
        XCTAssertEqual(MinimalPairsHintLevel.highlight.rawValue, 1)
        XCTAssertEqual(MinimalPairsHintLevel.voiceClarification.rawValue, 2)
    }

    func test_extendedCatalog_hasMinimum16Pairs() {
        XCTAssertGreaterThanOrEqual(MinimalPairRound.extendedCatalog.count, 16)
        XCTAssertEqual(MinimalPairRound.catalog.count, 10)
    }
}

// MARK: - Hint/Replay capturing presenter (batch 1)

@MainActor
private final class HintSpyMinimalPairsPresenter: MinimalPairsPresentationLogic {
    var lastHint: MinimalPairsModels.RequestHint.Response?
    var lastReplay: MinimalPairsModels.ReplayWord.Response?
    var lastBonus: MinimalPairsModels.BonusRoundAdded.Response?

    func presentLoadSession(_ response: MinimalPairsModels.LoadSession.Response) {}
    func presentStartRound(_ response: MinimalPairsModels.StartRound.Response) {}
    func presentSelectOption(_ response: MinimalPairsModels.SelectOption.Response) {}
    func presentCompleteSession(_ response: MinimalPairsModels.CompleteSession.Response) {}
    func presentReplayWord(_ response: MinimalPairsModels.ReplayWord.Response) { lastReplay = response }
    func presentHint(_ response: MinimalPairsModels.RequestHint.Response) { lastHint = response }
    func presentBonusRoundAdded(_ response: MinimalPairsModels.BonusRoundAdded.Response) { lastBonus = response }
}
