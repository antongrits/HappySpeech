import Testing
@testable import HappySpeech

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

@Suite("VisualAcousticInteractor")
@MainActor
struct VisualAcousticInteractorTests {

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

    @Test("loadRound загружает раунд 0 и 6 всего")
    func loadRoundLoadsFirstRound() {
        let (sut, spy) = makeSUT()
        sut.loadRound(.init(activity: makeActivity(), roundIndex: 0))
        #expect(spy.loadRoundCalled)
        #expect(spy.lastLoadRound?.roundIndex == 0)
        #expect(spy.lastLoadRound?.totalRounds == 6)
    }

    // MARK: - 2. buildRounds возвращает 6 раундов

    @Test("buildRounds возвращает 6 раундов для каждой группы")
    func buildRoundsSixPerGroup() {
        for group in ["whistling", "hissing", "sonants", "velar"] {
            let rounds = VisualAcousticInteractor.buildRounds(for: group, total: 6)
            #expect(rounds.count == 6, "Группа \(group) должна иметь 6 раундов")
        }
    }

    // MARK: - 3. resolveSoundGroup

    @Test("resolveSoundGroup корректно маппит все группы")
    func resolveSoundGroup() {
        #expect(VisualAcousticInteractor.resolveSoundGroup(for: "С") == "whistling")
        #expect(VisualAcousticInteractor.resolveSoundGroup(for: "Ш") == "hissing")
        #expect(VisualAcousticInteractor.resolveSoundGroup(for: "Р") == "sonants")
        #expect(VisualAcousticInteractor.resolveSoundGroup(for: "К") == "velar")
    }

    // MARK: - 4. chooseWord: правильный ответ

    @Test("chooseWord с правильным индексом → isCorrect = true")
    func chooseWordCorrect() {
        let (sut, spy) = makeSUT()
        sut.loadRound(.init(activity: makeActivity(), roundIndex: 0))
        guard let round = spy.lastLoadRound?.round else { return }
        sut.chooseWord(.init(choiceIndex: round.correctIndex))
        #expect(spy.chooseWordCalled)
        #expect(spy.lastChoiceWord?.isCorrect == true)
    }

    // MARK: - 5. chooseWord: неправильный ответ

    @Test("chooseWord с неправильным индексом → isCorrect = false")
    func chooseWordWrong() {
        let (sut, spy) = makeSUT()
        sut.loadRound(.init(activity: makeActivity(), roundIndex: 0))
        guard let round = spy.lastLoadRound?.round else { return }
        let wrongIdx = round.correctIndex == 0 ? 1 : 0
        sut.chooseWord(.init(choiceIndex: wrongIdx))
        #expect(spy.lastChoiceWord?.isCorrect == false)
    }

    // MARK: - 6. complete вычисляет score

    @Test("complete после 0 правильных ответов → score = 0")
    func completeZeroCorrect() {
        let (sut, spy) = makeSUT()
        sut.loadRound(.init(activity: makeActivity(), roundIndex: 0))
        sut.complete()
        #expect(spy.completeCalled)
        #expect(spy.lastComplete?.score == 0.0)
    }

    // MARK: - 7. cancel не вызывает complete

    @Test("cancel не вызывает presentComplete")
    func cancelDoesNotComplete() {
        let (sut, spy) = makeSUT()
        sut.loadRound(.init(activity: makeActivity(), roundIndex: 0))
        sut.cancel()
        #expect(!spy.completeCalled)
    }

    // MARK: - 8. correctWord передаётся в response

    @Test("chooseWord передаёт correctWord в response")
    func correctWordTransmitted() {
        let (sut, spy) = makeSUT()
        sut.loadRound(.init(activity: makeActivity(), roundIndex: 0))
        guard let round = spy.lastLoadRound?.round else { return }
        sut.chooseWord(.init(choiceIndex: round.correctIndex))
        let expectedWord = round.choices[round.correctIndex]
        #expect(spy.lastChoiceWord?.correctWord == expectedWord)
    }
}
