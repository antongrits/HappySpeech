@testable import HappySpeech
import XCTest

// MARK: - NarrativeQuestPresenterTests
//
// Phase 2.6.1 v25 — покрытие NarrativeQuestPresenter (13 тестов).
// Тестируются все 6 методов: presentLoadQuest, presentStartStage,
// presentRecordWord, presentEvaluateWord, presentAdvanceStage,
// presentCompleteQuest.

@MainActor
final class NarrativeQuestPresenterTests: XCTestCase {

    // MARK: - DisplaySpy

    @MainActor
    private final class DisplaySpy: NarrativeQuestDisplayLogic {
        var loadQuestVM: NarrativeQuestModels.LoadQuest.ViewModel?
        var startStageVM: NarrativeQuestModels.StartStage.ViewModel?
        var recordWordVM: NarrativeQuestModels.RecordWord.ViewModel?
        var evaluateWordVM: NarrativeQuestModels.EvaluateWord.ViewModel?
        var advanceStageVM: NarrativeQuestModels.AdvanceStage.ViewModel?
        var completeQuestVM: NarrativeQuestModels.CompleteQuest.ViewModel?

        func displayLoadQuest(_ viewModel: NarrativeQuestModels.LoadQuest.ViewModel) { loadQuestVM = viewModel }
        func displayStartStage(_ viewModel: NarrativeQuestModels.StartStage.ViewModel) { startStageVM = viewModel }
        func displayRecordWord(_ viewModel: NarrativeQuestModels.RecordWord.ViewModel) { recordWordVM = viewModel }
        func displayEvaluateWord(_ viewModel: NarrativeQuestModels.EvaluateWord.ViewModel) { evaluateWordVM = viewModel }
        func displayAdvanceStage(_ viewModel: NarrativeQuestModels.AdvanceStage.ViewModel) { advanceStageVM = viewModel }
        func displayCompleteQuest(_ viewModel: NarrativeQuestModels.CompleteQuest.ViewModel) { completeQuestVM = viewModel }
    }

    private func makeSUT() -> (NarrativeQuestPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = NarrativeQuestPresenter()
        presenter.displayLogic = spy
        return (presenter, spy)
    }

    private func makeStage(
        stageNumber: Int = 1,
        narration: String = "Ляля пошла в лес",
        targetWord: String = "сова",
        successNarration: String = "Молодец!"
    ) -> NarrativeQuestStage {
        NarrativeQuestStage(
            stageNumber: stageNumber,
            narration: narration,
            task: "Скажи слово «\(targetWord)»",
            targetWord: targetWord,
            targetSoundGroup: "whistling",
            successNarration: successNarration,
            rewardEmoji: "owl",
            hint: "Звук С в начале"
        )
    }

    private func makeScript() -> NarrativeQuestScript {
        let stages = (1...4).map { i in makeStage(stageNumber: i) }
        return NarrativeQuestScript(
            id: "quest-s-001",
            title: "Квест Совы",
            introNarration: "Жила-была Сова...",
            stages: stages,
            finalRewardEmoji: "trophy",
            finalMessage: "Ты прошёл квест!"
        )
    }

    // MARK: - presentLoadQuest

    func test_presentLoadQuest_titlePassedThrough() {
        let (sut, spy) = makeSUT()
        let response = NarrativeQuestModels.LoadQuest.Response(script: makeScript())
        sut.presentLoadQuest(response)
        XCTAssertNotNil(spy.loadQuestVM)
        XCTAssertEqual(spy.loadQuestVM?.questTitle, "Квест Совы")
        XCTAssertEqual(spy.loadQuestVM?.totalStages, 4)
        XCTAssertEqual(spy.loadQuestVM?.finalRewardEmoji, "trophy")
    }

    func test_presentLoadQuest_introNarrationPassedThrough() {
        let (sut, spy) = makeSUT()
        let response = NarrativeQuestModels.LoadQuest.Response(script: makeScript())
        sut.presentLoadQuest(response)
        XCTAssertFalse(spy.loadQuestVM?.introNarration.isEmpty ?? true)
    }

    // MARK: - presentStartStage

    func test_presentStartStage_passesStageData() {
        let (sut, spy) = makeSUT()
        let stage = makeStage(stageNumber: 2, targetWord: "самолёт")
        let response = NarrativeQuestModels.StartStage.Response(
            stage: stage,
            stageNumber: 2,
            totalStages: 4,
            progressFraction: 0.25
        )
        sut.presentStartStage(response)
        XCTAssertEqual(spy.startStageVM?.targetWord, "самолёт")
        XCTAssertEqual(spy.startStageVM?.stageNumber, 2)
        XCTAssertEqual(spy.startStageVM?.progressFraction ?? -1, 0.25, accuracy: 0.001)
    }

    func test_presentStartStage_hintPassedThrough() {
        let (sut, spy) = makeSUT()
        let stage = makeStage()
        let response = NarrativeQuestModels.StartStage.Response(
            stage: stage,
            stageNumber: 1,
            totalStages: 4,
            progressFraction: 0.0
        )
        sut.presentStartStage(response)
        XCTAssertFalse(spy.startStageVM?.hint.isEmpty ?? true)
    }

    // MARK: - presentRecordWord

    func test_presentRecordWord_isListening_labelSetToSpeak() {
        let (sut, spy) = makeSUT()
        sut.presentRecordWord(NarrativeQuestModels.RecordWord.Response(isListening: true))
        XCTAssertTrue(spy.recordWordVM?.isListening ?? false)
        XCTAssertFalse(spy.recordWordVM?.micLabel.isEmpty ?? true)
    }

    func test_presentRecordWord_notListening_labelSetToPress() {
        let (sut, spy) = makeSUT()
        sut.presentRecordWord(NarrativeQuestModels.RecordWord.Response(isListening: false))
        XCTAssertFalse(spy.recordWordVM?.isListening ?? true)
        XCTAssertFalse(spy.recordWordVM?.micLabel.isEmpty ?? true)
    }

    // MARK: - presentEvaluateWord

    func test_presentEvaluateWord_passed_successOverlayShown() {
        let (sut, spy) = makeSUT()
        let response = NarrativeQuestModels.EvaluateWord.Response(
            score: 0.9,
            passed: true,
            rewardEmoji: "owl",
            successNarration: "Молодец! Сова аплодирует."
        )
        sut.presentEvaluateWord(response)
        XCTAssertTrue(spy.evaluateWordVM?.feedbackSuccess ?? false)
        XCTAssertTrue(spy.evaluateWordVM?.showSuccessOverlay ?? false)
        XCTAssertEqual(spy.evaluateWordVM?.feedbackText, "Молодец! Сова аплодирует.")
    }

    func test_presentEvaluateWord_passed_emptySuccessNarration_defaultFeedback() {
        let (sut, spy) = makeSUT()
        let response = NarrativeQuestModels.EvaluateWord.Response(
            score: 0.9,
            passed: true,
            rewardEmoji: "owl",
            successNarration: ""
        )
        sut.presentEvaluateWord(response)
        XCTAssertFalse(spy.evaluateWordVM?.feedbackText.isEmpty ?? true)
    }

    func test_presentEvaluateWord_failed_noOverlay() {
        let (sut, spy) = makeSUT()
        let response = NarrativeQuestModels.EvaluateWord.Response(
            score: 0.3,
            passed: false,
            rewardEmoji: "owl",
            successNarration: ""
        )
        sut.presentEvaluateWord(response)
        XCTAssertFalse(spy.evaluateWordVM?.feedbackSuccess ?? true)
        XCTAssertFalse(spy.evaluateWordVM?.showSuccessOverlay ?? true)
        XCTAssertFalse(spy.evaluateWordVM?.feedbackText.isEmpty ?? true)
    }

    // MARK: - presentAdvanceStage

    func test_presentAdvanceStage_hasNext_isLastFalse() {
        let (sut, spy) = makeSUT()
        let response = NarrativeQuestModels.AdvanceStage.Response(
            nextStageIndex: 1,
            collectedEmojis: ["owl"],
            progressFraction: 0.25,
            stageNumber: 1
        )
        sut.presentAdvanceStage(response)
        XCTAssertFalse(spy.advanceStageVM?.isLast ?? true)
        XCTAssertEqual(spy.advanceStageVM?.collectedEmojis.count, 1)
    }

    func test_presentAdvanceStage_noNext_isLastTrue() {
        let (sut, spy) = makeSUT()
        let response = NarrativeQuestModels.AdvanceStage.Response(
            nextStageIndex: nil,
            collectedEmojis: ["owl", "star", "rocket", "trophy"],
            progressFraction: 1.0,
            stageNumber: 4
        )
        sut.presentAdvanceStage(response)
        XCTAssertTrue(spy.advanceStageVM?.isLast ?? false)
    }

    // MARK: - presentCompleteQuest

    func test_presentCompleteQuest_3stars_scoreLabelContainsPercent() {
        let (sut, spy) = makeSUT()
        let response = NarrativeQuestModels.CompleteQuest.Response(
            averageScore: 0.95,
            starsEarned: 3,
            collectedEmojis: ["owl", "star", "rocket", "trophy"],
            finalRewardEmoji: "trophy",
            finalMessage: "Ты прошёл квест!"
        )
        sut.presentCompleteQuest(response)
        XCTAssertEqual(spy.completeQuestVM?.starsEarned, 3)
        XCTAssertTrue(spy.completeQuestVM?.scoreLabel.contains("%") ?? false)
        XCTAssertEqual(spy.completeQuestVM?.completionMessage, "Ты прошёл квест!")
    }

    func test_presentCompleteQuest_normalizedScoreClamped() {
        let (sut, spy) = makeSUT()
        let response = NarrativeQuestModels.CompleteQuest.Response(
            averageScore: 1.5,
            starsEarned: 3,
            collectedEmojis: [],
            finalRewardEmoji: "trophy",
            finalMessage: ""
        )
        sut.presentCompleteQuest(response)
        XCTAssertLessThanOrEqual(spy.completeQuestVM?.normalizedScore ?? 2, 1.0)
    }
}
