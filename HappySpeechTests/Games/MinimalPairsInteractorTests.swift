import Testing
@testable import HappySpeech

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
}

// MARK: - Tests

@Suite("MinimalPairsInteractor")
@MainActor
struct MinimalPairsInteractorTests {

    private func makeSUT() -> (MinimalPairsInteractor, SpyMinimalPairsPresenter) {
        let sut = MinimalPairsInteractor()
        let spy = SpyMinimalPairsPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 1. loadSession загружает 10 раундов

    @Test("loadSession загружает 10 раундов")
    func loadSessionLoads10Rounds() async {
        let (sut, spy) = makeSUT()
        await sut.loadSession(.init(soundContrast: "С-Ш", childName: "Маша"))
        #expect(spy.loadSessionCalled)
        #expect(spy.lastLoadSession?.rounds.count == 10)
    }

    // MARK: - 2. startRound загружает первый раунд

    @Test("startRound(0) загружает раунд с roundNumber = 1")
    func startRoundZero() async {
        let (sut, spy) = makeSUT()
        await sut.loadSession(.init(soundContrast: "С-Ш", childName: "Маша"))
        await sut.startRound(.init(roundIndex: 0))
        #expect(spy.startRoundCalled)
        #expect(spy.lastStartRound?.roundNumber == 1)
        #expect(spy.lastStartRound?.total == 10)
    }

    // MARK: - 3. selectOption: правильный выбор

    @Test("selectOption(selectedIsTarget: true) → correct = true")
    func selectOptionCorrect() async {
        let (sut, spy) = makeSUT()
        await sut.loadSession(.init(soundContrast: "С-Ш", childName: "Маша"))
        await sut.startRound(.init(roundIndex: 0))
        await sut.selectOption(.init(selectedIsTarget: true))
        #expect(spy.selectOptionCalled)
        #expect(spy.lastSelectOption?.correct == true)
    }

    // MARK: - 4. selectOption: неправильный выбор

    @Test("selectOption(selectedIsTarget: false) → correct = false")
    func selectOptionWrong() async {
        let (sut, spy) = makeSUT()
        await sut.loadSession(.init(soundContrast: "С-Ш", childName: "Маша"))
        await sut.startRound(.init(roundIndex: 0))
        await sut.selectOption(.init(selectedIsTarget: false))
        #expect(spy.lastSelectOption?.correct == false)
    }

    // MARK: - 5. correctAnswer передаётся в response

    @Test("selectOption передаёт correctAnswer")
    func selectOptionTransmitsCorrectAnswer() async {
        let (sut, spy) = makeSUT()
        await sut.loadSession(.init(soundContrast: "С-Ш", childName: "Маша"))
        await sut.startRound(.init(roundIndex: 0))
        let targetWord = spy.lastStartRound?.pair.targetWord ?? ""
        await sut.selectOption(.init(selectedIsTarget: true))
        #expect(spy.lastSelectOption?.correctAnswer == targetWord)
    }

    // MARK: - 6. completeSession вычисляет correctCount

    @Test("completeSession без ответов → correctCount = 0")
    func completeSessionNoAnswers() async {
        let (sut, spy) = makeSUT()
        await sut.loadSession(.init(soundContrast: "С-Ш", childName: "Маша"))
        await sut.completeSession(.init())
        #expect(spy.completeCalled)
        #expect(spy.lastComplete?.correctCount == 0)
        #expect(spy.lastComplete?.totalRounds == 10)
    }

    // MARK: - 7. startRound с out-of-bounds игнорируется

    @Test("startRound с индексом >= rounds.count не крашится")
    func startRoundOutOfBounds() async {
        let (sut, spy) = makeSUT()
        await sut.loadSession(.init(soundContrast: "С-Ш", childName: "Маша"))
        await sut.startRound(.init(roundIndex: 99))
        #expect(!spy.startRoundCalled)
    }

    // MARK: - 8. MinimalPairRound.rounds возвращает раунды

    @Test("MinimalPairRound.rounds(count:contrast:) возвращает count раундов")
    func roundsFactory() {
        let rounds = MinimalPairRound.rounds(count: 5, contrast: "Р-Л")
        #expect(rounds.count == 5)
    }
}
