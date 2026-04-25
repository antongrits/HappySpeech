import Testing
@testable import HappySpeech

// MARK: - Spy

@MainActor
private final class SpyNarrativePresenter: NarrativeQuestPresentationLogic {
    var loadQuestCalled = false
    var startStageCalled = false
    var recordWordCalled = false
    var evaluateWordCalled = false
    var advanceStageCalled = false
    var completeQuestCalled = false

    var lastLoadQuest: NarrativeQuestModels.LoadQuest.Response?
    var lastStartStage: NarrativeQuestModels.StartStage.Response?
    var lastEvaluate: NarrativeQuestModels.EvaluateWord.Response?
    var lastComplete: NarrativeQuestModels.CompleteQuest.Response?

    func presentLoadQuest(_ response: NarrativeQuestModels.LoadQuest.Response) {
        loadQuestCalled = true
        lastLoadQuest = response
    }
    func presentStartStage(_ response: NarrativeQuestModels.StartStage.Response) {
        startStageCalled = true
        lastStartStage = response
    }
    func presentRecordWord(_ response: NarrativeQuestModels.RecordWord.Response) {
        recordWordCalled = true
    }
    func presentEvaluateWord(_ response: NarrativeQuestModels.EvaluateWord.Response) {
        evaluateWordCalled = true
        lastEvaluate = response
    }
    func presentAdvanceStage(_ response: NarrativeQuestModels.AdvanceStage.Response) {
        advanceStageCalled = true
    }
    func presentCompleteQuest(_ response: NarrativeQuestModels.CompleteQuest.Response) {
        completeQuestCalled = true
        lastComplete = response
    }
}

// MARK: - Tests

@Suite("NarrativeQuestInteractor")
@MainActor
struct NarrativeQuestInteractorTests {

    private func makeSUT() -> (NarrativeQuestInteractor, SpyNarrativePresenter) {
        let spy = SpyNarrativePresenter()
        let sut = NarrativeQuestInteractor(presenter: spy)
        return (sut, spy)
    }

    // MARK: - 1. loadQuest загружает скрипт

    @Test("loadQuest загружает скрипт с 4 этапами для whistling")
    func loadQuestWhistling() {
        let (sut, spy) = makeSUT()
        sut.loadQuest(.init(soundTarget: "С", childName: "Маша"))
        #expect(spy.loadQuestCalled)
        #expect(spy.lastLoadQuest?.script.stages.count == 4)
    }

    // MARK: - 2. questCatalog содержит все группы

    @Test("questCatalog содержит квесты для всех 4 групп")
    func questCatalogAllGroups() {
        for group in ["whistling", "hissing", "sonants", "velar"] {
            #expect(NarrativeQuestInteractor.questCatalog[group] != nil,
                    "Группа \(group) должна быть в каталоге")
        }
    }

    // MARK: - 3. resolveSoundGroup

    @Test("resolveSoundGroup корректно маппит звуки")
    func resolveSoundGroup() {
        #expect(NarrativeQuestInteractor.resolveSoundGroup("С") == "whistling")
        #expect(NarrativeQuestInteractor.resolveSoundGroup("Ш") == "hissing")
        #expect(NarrativeQuestInteractor.resolveSoundGroup("Р") == "sonants")
        #expect(NarrativeQuestInteractor.resolveSoundGroup("К") == "velar")
    }

    // MARK: - 4. startStage передаёт правильный этап

    @Test("startStage(0) передаёт стейдж с stageNumber = 1")
    func startStageZero() {
        let (sut, spy) = makeSUT()
        sut.loadQuest(.init(soundTarget: "С", childName: "Маша"))
        sut.startStage(.init(stageIndex: 0))
        #expect(spy.startStageCalled)
        #expect(spy.lastStartStage?.stageNumber == 1)
    }

    // MARK: - 5. evaluateWord: точное совпадение → passed

    @Test("evaluateWord: transcript == target → score = 1.0, passed = true")
    func evaluateWordExactMatch() {
        let (sut, spy) = makeSUT()
        sut.loadQuest(.init(soundTarget: "С", childName: "Маша"))
        sut.startStage(.init(stageIndex: 0))
        sut.evaluateWord(.init(transcript: "сова", confidence: 0.95))
        #expect(spy.evaluateWordCalled)
        #expect(spy.lastEvaluate?.passed == true)
        #expect(spy.lastEvaluate?.score == 1.0)
    }

    // MARK: - 6. evaluateWord: пустой transcript → score через confidence

    @Test("evaluateWord: пустой transcript даёт score через fallback")
    func evaluateWordEmptyTranscript() {
        let (_, _) = makeSUT()
        let (score, passed) = NarrativeQuestInteractor.scoreAttempt(
            transcript: "",
            target: "сова",
            confidence: 0.75
        )
        #expect(score == 0.75)
        #expect(passed == true)  // 0.75 >= passThreshold 0.6
    }

    // MARK: - 7. completeQuest вычисляет averageScore

    @Test("completeQuest передаёт averageScore в диапазоне [0, 1]")
    func completeQuestScoreInRange() {
        let (sut, spy) = makeSUT()
        sut.loadQuest(.init(soundTarget: "С", childName: "Маша"))
        sut.completeQuest(.init())
        #expect(spy.completeQuestCalled)
        let avg = spy.lastComplete?.averageScore ?? -1
        #expect(avg >= 0 && avg <= 1)
    }

    // MARK: - 8. cancel не крашится

    @Test("cancel не крашится и не вызывает completeQuest")
    func cancelDoesNotComplete() {
        let (sut, spy) = makeSUT()
        sut.loadQuest(.init(soundTarget: "С", childName: "Маша"))
        sut.cancel()
        #expect(!spy.completeQuestCalled)
    }

    // MARK: - 9. scoreAttempt: точное содержание транскрипта

    @Test("scoreAttempt: transcript точно совпадает с target → score = 1.0")
    func scoreAttemptContains() {
        // Используем точное вхождение (cleanTranscript.contains(cleanTarget))
        let (score, passed) = NarrativeQuestInteractor.scoreAttempt(
            transcript: "сова летит",
            target: "сова",
            confidence: 0.9
        )
        #expect(score == 1.0)
        #expect(passed)
    }
}
