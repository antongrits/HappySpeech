@testable import HappySpeech
import XCTest

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

@MainActor
final class NarrativeQuestInteractorTests: XCTestCase {

    private func makeSUT() -> (NarrativeQuestInteractor, SpyNarrativePresenter) {
        let spy = SpyNarrativePresenter()
        let sut = NarrativeQuestInteractor(presenter: spy)
        return (sut, spy)
    }

    // MARK: - 1. loadQuest загружает скрипт с 4 этапами

    func test_loadQuest_whistling_fourStages() {
        let (sut, spy) = makeSUT()
        sut.loadQuest(.init(soundTarget: "С", childName: "Маша"))
        XCTAssertTrue(spy.loadQuestCalled)
        XCTAssertEqual(spy.lastLoadQuest?.script.stages.count, 4)
    }

    // MARK: - 2. questCatalog содержит все группы

    func test_questCatalog_allGroups() {
        for group in ["whistling", "hissing", "sonants", "velar"] {
            XCTAssertNotNil(NarrativeQuestInteractor.questCatalog[group],
                            "Группа \(group) должна быть в каталоге")
        }
    }

    // MARK: - 3. resolveSoundGroup

    func test_resolveSoundGroup() {
        XCTAssertEqual(NarrativeQuestInteractor.resolveSoundGroup("С"), "whistling")
        XCTAssertEqual(NarrativeQuestInteractor.resolveSoundGroup("Ш"), "hissing")
        XCTAssertEqual(NarrativeQuestInteractor.resolveSoundGroup("Р"), "sonants")
        XCTAssertEqual(NarrativeQuestInteractor.resolveSoundGroup("К"), "velar")
    }

    // MARK: - 4. startStage(0) передаёт stageNumber = 1

    func test_startStage_zero_stageNumber1() {
        let (sut, spy) = makeSUT()
        sut.loadQuest(.init(soundTarget: "С", childName: "Маша"))
        sut.startStage(.init(stageIndex: 0))
        XCTAssertTrue(spy.startStageCalled)
        XCTAssertEqual(spy.lastStartStage?.stageNumber, 1)
    }

    // MARK: - 5. evaluateWord: точное совпадение → passed

    func test_evaluateWord_exactMatch_passed() {
        let (sut, spy) = makeSUT()
        sut.loadQuest(.init(soundTarget: "С", childName: "Маша"))
        sut.startStage(.init(stageIndex: 0))
        sut.evaluateWord(.init(transcript: "сова", confidence: 0.95))
        XCTAssertTrue(spy.evaluateWordCalled)
        XCTAssertEqual(spy.lastEvaluate?.passed, true)
        XCTAssertEqual(spy.lastEvaluate?.score, 1.0)
    }

    // MARK: - 6. evaluateWord: пустой transcript → score через confidence

    func test_evaluateWord_emptyTranscript_fallback() {
        let (score, passed) = NarrativeQuestInteractor.scoreAttempt(
            transcript: "",
            target: "сова",
            confidence: 0.75
        )
        XCTAssertEqual(score, 0.75)
        XCTAssertTrue(passed)  // 0.75 >= passThreshold 0.6
    }

    // MARK: - 7. completeQuest → averageScore in [0,1]

    func test_completeQuest_scoreInRange() {
        let (sut, spy) = makeSUT()
        sut.loadQuest(.init(soundTarget: "С", childName: "Маша"))
        sut.completeQuest(.init())
        XCTAssertTrue(spy.completeQuestCalled)
        let avg = spy.lastComplete?.averageScore ?? -1
        XCTAssertGreaterThanOrEqual(avg, 0)
        XCTAssertLessThanOrEqual(avg, 1)
    }

    // MARK: - 8. cancel не вызывает completeQuest

    func test_cancel_doesNotComplete() {
        let (sut, spy) = makeSUT()
        sut.loadQuest(.init(soundTarget: "С", childName: "Маша"))
        sut.cancel()
        XCTAssertFalse(spy.completeQuestCalled)
    }

    // MARK: - 9. scoreAttempt: transcript содержит target → score = 1.0

    func test_scoreAttempt_contains() {
        let (score, passed) = NarrativeQuestInteractor.scoreAttempt(
            transcript: "сова летит",
            target: "сова",
            confidence: 0.9
        )
        XCTAssertEqual(score, 1.0)
        XCTAssertTrue(passed)
    }
}
