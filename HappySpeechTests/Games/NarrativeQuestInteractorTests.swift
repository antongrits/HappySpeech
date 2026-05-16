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

    // MARK: - Batch 1: расширенное покрытие

    func test_loadQuest_allGroups_loadCorrectScript() {
        for (target, expectedStages) in [("С", 4), ("Ш", 4), ("Р", 4), ("К", 4)] {
            let (sut, spy) = makeSUT()
            sut.loadQuest(.init(soundTarget: target, childName: "Маша"))
            XCTAssertEqual(spy.lastLoadQuest?.script.stages.count, expectedStages)
        }
    }

    func test_startStage_outOfBounds_ignored() {
        let (sut, spy) = makeSUT()
        sut.loadQuest(.init(soundTarget: "С", childName: "Маша"))
        spy.startStageCalled = false
        sut.startStage(.init(stageIndex: 99))
        XCTAssertFalse(spy.startStageCalled)
    }

    func test_startStage_progressFraction() {
        let (sut, spy) = makeSUT()
        sut.loadQuest(.init(soundTarget: "С", childName: "Маша"))
        sut.startStage(.init(stageIndex: 2))
        // 2 / 4 = 0.5
        XCTAssertEqual(spy.lastStartStage?.progressFraction ?? -1, 0.5, accuracy: 0.01)
    }

    func test_recordWord_setsListening() {
        var listeningStates: [Bool] = []
        let spy = RecordSpyNarrativePresenter { listeningStates.append($0) }
        let sut = NarrativeQuestInteractor(presenter: spy)
        sut.loadQuest(.init(soundTarget: "С", childName: "Маша"))
        sut.startStage(.init(stageIndex: 0))
        sut.recordWord(.init(stageIndex: 0))
        XCTAssertTrue(listeningStates.contains(true))
    }

    func test_evaluateWord_failed_lowScore() {
        let (sut, spy) = makeSUT()
        sut.loadQuest(.init(soundTarget: "С", childName: "Маша"))
        sut.startStage(.init(stageIndex: 0))
        sut.evaluateWord(.init(transcript: "абракадабра", confidence: 0.1))
        XCTAssertEqual(spy.lastEvaluate?.passed, false)
        XCTAssertEqual(spy.lastEvaluate?.score, 0.5)
    }

    func test_evaluateWord_rewardEmojiPresent() {
        let (sut, spy) = makeSUT()
        sut.loadQuest(.init(soundTarget: "С", childName: "Маша"))
        sut.startStage(.init(stageIndex: 0))
        sut.evaluateWord(.init(transcript: "сова", confidence: 0.95))
        XCTAssertFalse(spy.lastEvaluate?.rewardEmoji.isEmpty ?? true)
    }

    func test_advanceStage_lastStage_completesQuest() {
        let (sut, spy) = makeSUT()
        sut.loadQuest(.init(soundTarget: "С", childName: "Маша"))
        sut.startStage(.init(stageIndex: 3))   // последний этап (index 3 из 4)
        sut.advanceStage(.init())
        XCTAssertTrue(spy.completeQuestCalled)
    }

    func test_advanceStage_midStage_emitsNextIndex() {
        let (sut, spy) = makeSUT()
        sut.loadQuest(.init(soundTarget: "С", childName: "Маша"))
        sut.startStage(.init(stageIndex: 0))
        sut.advanceStage(.init())
        XCTAssertTrue(spy.advanceStageCalled)
    }

    func test_resolveSoundGroup_fallbackById() {
        XCTAssertEqual(NarrativeQuestInteractor.resolveSoundGroup("sonorant"), "sonants")
        XCTAssertEqual(NarrativeQuestInteractor.resolveSoundGroup("hissing"), "hissing")
        XCTAssertEqual(NarrativeQuestInteractor.resolveSoundGroup("неизвестно"), "whistling")
    }

    func test_scoreAttempt_prefixMatch_highConfidence() {
        let (score, passed) = NarrativeQuestInteractor.scoreAttempt(
            transcript: "соба", target: "сова", confidence: 0.9
        )
        // prefix >= 2, confidence >= 0.6 → 0.85
        XCTAssertEqual(score, 0.85)
        XCTAssertTrue(passed)
    }

    func test_scoreAttempt_prefixMatch_lowConfidence() {
        let (score, passed) = NarrativeQuestInteractor.scoreAttempt(
            transcript: "соба", target: "сова", confidence: 0.3
        )
        // prefix >= 2 но confidence < 0.6 → 0.7
        XCTAssertEqual(score, 0.7)
        XCTAssertTrue(passed)
    }

    func test_scoreAttempt_emptyTarget_zero() {
        let (score, passed) = NarrativeQuestInteractor.scoreAttempt(
            transcript: "что-то", target: "", confidence: 0.9
        )
        XCTAssertEqual(score, 0)
        XCTAssertFalse(passed)
    }

    func test_scoreAttempt_noMatch_softFail() {
        let (score, passed) = NarrativeQuestInteractor.scoreAttempt(
            transcript: "молоко", target: "ракета", confidence: 0.5
        )
        XCTAssertEqual(score, 0.5)
        XCTAssertFalse(passed)
    }

    func test_completeQuest_collectedEmojisInResponse() {
        let (sut, spy) = makeSUT()
        sut.loadQuest(.init(soundTarget: "С", childName: "Маша"))
        sut.startStage(.init(stageIndex: 0))
        sut.evaluateWord(.init(transcript: "сова", confidence: 0.95))
        sut.completeQuest(.init())
        XCTAssertEqual(spy.lastComplete?.collectedEmojis.count, 1)
    }
}

// MARK: - Record-spy presenter (batch 1)

@MainActor
private final class RecordSpyNarrativePresenter: NarrativeQuestPresentationLogic {
    private let onRecord: (Bool) -> Void

    init(onRecord: @escaping (Bool) -> Void) {
        self.onRecord = onRecord
    }

    func presentLoadQuest(_ response: NarrativeQuestModels.LoadQuest.Response) {}
    func presentStartStage(_ response: NarrativeQuestModels.StartStage.Response) {}
    func presentRecordWord(_ response: NarrativeQuestModels.RecordWord.Response) {
        onRecord(response.isListening)
    }
    func presentEvaluateWord(_ response: NarrativeQuestModels.EvaluateWord.Response) {}
    func presentAdvanceStage(_ response: NarrativeQuestModels.AdvanceStage.Response) {}
    func presentCompleteQuest(_ response: NarrativeQuestModels.CompleteQuest.Response) {}
}
