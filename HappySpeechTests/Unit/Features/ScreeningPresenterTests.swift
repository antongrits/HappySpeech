import XCTest
@testable import HappySpeech

// MARK: - ScreeningPresenterTests
//
// Phase 2.6 batch 3 — покрытие ScreeningPresenter (6% → цель ≥90%).

@MainActor
final class ScreeningPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: ScreeningDisplayLogic {
        var startVM: ScreeningModels.StartScreening.ViewModel?
        var prepareVM: ScreeningModels.PrepareStage.ViewModel?
        var recordingVM: ScreeningModels.StartRecording.ViewModel?
        var submitVM: ScreeningModels.SubmitAnswer.ViewModel?
        var finishVM: ScreeningModels.FinishScreening.ViewModel?
        var recordingError: ScreeningModels.RecordingError?
        var micPermVM: ScreeningModels.MicrophonePermission.ViewModel?
        var rescreeningVM: ScreeningModels.CheckRescreening.ViewModel?

        func displayStartScreening(_ vm: ScreeningModels.StartScreening.ViewModel) { startVM = vm }
        func displayPrepareStage(_ vm: ScreeningModels.PrepareStage.ViewModel) { prepareVM = vm }
        func displayStartRecording(_ vm: ScreeningModels.StartRecording.ViewModel) { recordingVM = vm }
        func displaySubmitAnswer(_ vm: ScreeningModels.SubmitAnswer.ViewModel) { submitVM = vm }
        func displayFinishScreening(_ vm: ScreeningModels.FinishScreening.ViewModel) { finishVM = vm }
        func displayRecordingError(_ error: ScreeningModels.RecordingError) { recordingError = error }
        func displayMicrophonePermission(_ vm: ScreeningModels.MicrophonePermission.ViewModel) { micPermVM = vm }
        func displayRescreeningCheck(_ vm: ScreeningModels.CheckRescreening.ViewModel) { rescreeningVM = vm }
    }

    private func makeSUT() -> (ScreeningPresenter, DisplaySpy) {
        let sut = ScreeningPresenter()
        let spy = DisplaySpy()
        sut.display = spy
        return (sut, spy)
    }

    private func makePrompt(targetSound: String = "С") -> ScreeningPrompt {
        ScreeningPrompt(
            id: "prompt-\(targetSound)",
            block: .wordPronunciation,
            targetSound: targetSound,
            stimulus: "Сом",
            imageAsset: "word_cat",
            referenceAudio: nil,
            acceptableHoldSeconds: nil
        )
    }

    private func makeOutcome(
        sounds: [String: SoundVerdict] = ["С": .normal],
        priority: [String] = []
    ) -> ScreeningOutcome {
        ScreeningOutcome(
            childId: "child-1",
            completedAt: Date(),
            perSound: sounds,
            priorityTargetSounds: priority,
            recommendedSessionDurationSec: 600,
            initialStagePerSound: [:]
        )
    }

    // MARK: - presentStartScreening

    func test_presentStartScreening_estimatedMinutes_atLeastOne() async {
        let (sut, spy) = makeSUT()
        let prompts = [makePrompt(targetSound: "С"), makePrompt(targetSound: "Р")]
        await sut.presentStartScreening(.init(
            prompts: prompts,
            totalBlocks: 3,
            lyalyaPhrase: "Привет!"
        ))
        XCTAssertNotNil(spy.startVM)
        XCTAssertGreaterThanOrEqual(spy.startVM?.estimatedMinutes ?? 0, 1)
        XCTAssertEqual(spy.startVM?.lyalyaPhrase, "Привет!")
        XCTAssertEqual(spy.startVM?.prompts.count, 2)
    }

    func test_presentStartScreening_singlePrompt_oneMinute() async {
        let (sut, spy) = makeSUT()
        await sut.presentStartScreening(.init(
            prompts: [makePrompt()],
            totalBlocks: 1,
            lyalyaPhrase: "Начнём"
        ))
        XCTAssertEqual(spy.startVM?.estimatedMinutes, 1)
    }

    // MARK: - presentPrepareStage

    func test_presentPrepareStage_progressFraction_correct() async {
        let (sut, spy) = makeSUT()
        await sut.presentPrepareStage(.init(
            stageIndex: 1,
            totalStages: 4,
            prompt: makePrompt(targetSound: "Р"),
            lyalyaPhrase: "Молодец",
            canRecord: true
        ))
        XCTAssertNotNil(spy.prepareVM)
        XCTAssertEqual(spy.prepareVM?.progressFraction ?? 0, 0.5, accuracy: 0.01)
        XCTAssertTrue(spy.prepareVM?.showRecordButton == true)
        XCTAssertEqual(spy.prepareVM?.targetWord, "Сом")
    }

    func test_presentPrepareStage_zeroStages_zeroFraction() async {
        let (sut, spy) = makeSUT()
        await sut.presentPrepareStage(.init(
            stageIndex: 0,
            totalStages: 0,
            prompt: makePrompt(),
            lyalyaPhrase: "Привет",
            canRecord: false
        ))
        XCTAssertEqual(spy.prepareVM?.progressFraction ?? 1, 0, accuracy: 0.01)
        XCTAssertFalse(spy.prepareVM?.showRecordButton ?? true)
    }

    // MARK: - presentStartRecording

    func test_presentStartRecording_isRecordingTrue() async {
        let (sut, spy) = makeSUT()
        await sut.presentStartRecording(.init(stageIndex: 0, maxDurationSec: 5))
        XCTAssertTrue(spy.recordingVM?.isRecording == true)
        XCTAssertFalse(spy.recordingVM?.timerLabelText.isEmpty ?? true)
        XCTAssertEqual(spy.recordingVM?.stageIndex, 0)
    }

    // MARK: - presentSubmitAnswer

    func test_presentSubmitAnswer_notComplete_nextIndex() async {
        let (sut, spy) = makeSUT()
        await sut.presentSubmitAnswer(.init(
            isBlockComplete: false,
            isScreeningComplete: false,
            currentPromptIndex: 2,
            adaptiveStopTriggered: false
        ))
        XCTAssertFalse(spy.submitVM?.shouldShowSummary ?? true)
        XCTAssertEqual(spy.submitVM?.nextPromptIndex, 3)
        XCTAssertNil(spy.submitVM?.adaptiveStopMessage)
    }

    func test_presentSubmitAnswer_screeningComplete_showsSummary() async {
        let (sut, spy) = makeSUT()
        await sut.presentSubmitAnswer(.init(
            isBlockComplete: true,
            isScreeningComplete: true,
            currentPromptIndex: 9,
            adaptiveStopTriggered: false
        ))
        XCTAssertTrue(spy.submitVM?.shouldShowSummary == true)
        XCTAssertNil(spy.submitVM?.nextPromptIndex)
    }

    func test_presentSubmitAnswer_adaptiveStop_hasMessage() async {
        let (sut, spy) = makeSUT()
        await sut.presentSubmitAnswer(.init(
            isBlockComplete: false,
            isScreeningComplete: true,
            currentPromptIndex: 3,
            adaptiveStopTriggered: true
        ))
        XCTAssertNotNil(spy.submitVM?.adaptiveStopMessage)
        XCTAssertFalse(spy.submitVM?.adaptiveStopMessage?.isEmpty ?? true)
    }

    func test_presentSubmitAnswer_blockComplete_notScreeningComplete_showsBlockTransition() async {
        let (sut, spy) = makeSUT()
        await sut.presentSubmitAnswer(.init(
            isBlockComplete: true,
            isScreeningComplete: false,
            currentPromptIndex: 2,
            adaptiveStopTriggered: false
        ))
        XCTAssertTrue(spy.submitVM?.shouldShowBlockTransition == true)
        XCTAssertFalse(spy.submitVM?.shouldShowSummary ?? true)
    }

    // MARK: - presentFinishScreening

    func test_presentFinishScreening_allNormal_summaryNotEmpty() async {
        let (sut, spy) = makeSUT()
        let outcome = makeOutcome(sounds: ["С": .normal, "Р": .normal], priority: [])
        await sut.presentFinishScreening(.init(
            outcome: outcome,
            wasAdaptiveStopped: false,
            testedSoundsCount: 10,
            totalSoundsCount: 10,
            lyalyaFinishPhrase: "Отлично!"
        ))
        XCTAssertNotNil(spy.finishVM)
        XCTAssertFalse(spy.finishVM?.outcomeSummary.isEmpty ?? true)
        XCTAssertEqual(spy.finishVM?.lyalyaFinishPhrase, "Отлично!")
        XCTAssertFalse(spy.finishVM?.wasAdaptiveStopped ?? true)
    }

    func test_presentFinishScreening_withIntervention_soundsInSummary() async {
        let (sut, spy) = makeSUT()
        let outcome = makeOutcome(
            sounds: ["С": .intervention, "Р": .monitor],
            priority: ["С", "Р"]
        )
        await sut.presentFinishScreening(.init(
            outcome: outcome,
            wasAdaptiveStopped: false,
            testedSoundsCount: 10,
            totalSoundsCount: 10,
            lyalyaFinishPhrase: "Справились"
        ))
        XCTAssertEqual(spy.finishVM?.priorityTargetSounds, ["С", "Р"])
        XCTAssertFalse(spy.finishVM?.outcomeSummary.isEmpty ?? true)
    }

    func test_presentFinishScreening_verdicts_sortedBySeverity() async {
        let (sut, spy) = makeSUT()
        let outcome = makeOutcome(
            sounds: ["С": .normal, "Р": .intervention, "Л": .monitor],
            priority: ["Р"]
        )
        await sut.presentFinishScreening(.init(
            outcome: outcome,
            wasAdaptiveStopped: false,
            testedSoundsCount: 10,
            totalSoundsCount: 10,
            lyalyaFinishPhrase: "Конец"
        ))
        // Intervention > Monitor > Normal — первый verdict должен быть intervention
        let verdicts = spy.finishVM?.perSoundVerdicts ?? []
        XCTAssertFalse(verdicts.isEmpty)
        if let first = verdicts.first {
            XCTAssertEqual(first.verdict, .intervention)
        }
    }

    func test_presentFinishScreening_adaptiveStopped_labelNotEmpty() async {
        let (sut, spy) = makeSUT()
        let outcome = makeOutcome(sounds: ["С": .normal], priority: [])
        await sut.presentFinishScreening(.init(
            outcome: outcome,
            wasAdaptiveStopped: true,
            testedSoundsCount: 4,
            totalSoundsCount: 10,
            lyalyaFinishPhrase: "Остановка"
        ))
        XCTAssertTrue(spy.finishVM?.wasAdaptiveStopped == true)
        XCTAssertFalse(spy.finishVM?.testedLabel.isEmpty ?? true)
    }

    // MARK: - presentRecordingError

    func test_presentRecordingError_passesError() async {
        let (sut, spy) = makeSUT()
        let error = ScreeningModels.RecordingError(errorMessage: "Нет микрофона", canContinueWithoutRecording: true)
        await sut.presentRecordingError(error)
        XCTAssertEqual(spy.recordingError?.errorMessage, "Нет микрофона")
    }

    // MARK: - presentMicrophonePermission

    func test_presentMicrophonePermission_granted_nilDeniedMessage() async {
        let (sut, spy) = makeSUT()
        await sut.presentMicrophonePermission(.init(isGranted: true))
        XCTAssertTrue(spy.micPermVM?.isGranted == true)
        XCTAssertNil(spy.micPermVM?.deniedMessage)
    }

    func test_presentMicrophonePermission_denied_hasDeniedMessage() async {
        let (sut, spy) = makeSUT()
        await sut.presentMicrophonePermission(.init(isGranted: false))
        XCTAssertFalse(spy.micPermVM?.isGranted ?? true)
        XCTAssertNotNil(spy.micPermVM?.deniedMessage)
        XCTAssertFalse(spy.micPermVM?.deniedMessage?.isEmpty ?? true)
    }

    // MARK: - presentRescreeningCheck

    func test_presentRescreeningCheck_eligible_nilWarning() async {
        let (sut, spy) = makeSUT()
        await sut.presentRescreeningCheck(.init(
            isEligible: true,
            daysSinceLastScreening: nil,
            previousOutcomeSummary: nil
        ))
        XCTAssertTrue(spy.rescreeningVM?.isEligible == true)
        XCTAssertNil(spy.rescreeningVM?.warningMessage)
        XCTAssertNil(spy.rescreeningVM?.previousSummaryText)
    }

    func test_presentRescreeningCheck_notEligible_hasWarning() async {
        let (sut, spy) = makeSUT()
        await sut.presentRescreeningCheck(.init(
            isEligible: false,
            daysSinceLastScreening: 7,
            previousOutcomeSummary: nil
        ))
        XCTAssertFalse(spy.rescreeningVM?.isEligible ?? true)
        XCTAssertNotNil(spy.rescreeningVM?.warningMessage)
    }

    func test_presentRescreeningCheck_withPreviousSummary_hasSummaryText() async {
        let (sut, spy) = makeSUT()
        let prev = ScreeningModels.PreviousOutcomeSummary(
            completedAt: Date(),
            severity: "mild",
            problematicSounds: ["С", "Р"],
            daysSince: 30
        )
        await sut.presentRescreeningCheck(.init(
            isEligible: true,
            daysSinceLastScreening: nil,
            previousOutcomeSummary: prev
        ))
        XCTAssertNotNil(spy.rescreeningVM?.previousSummaryText)
        XCTAssertFalse(spy.rescreeningVM?.previousSummaryText?.isEmpty ?? true)
    }

    func test_presentRescreeningCheck_noProblematicSounds_hasText() async {
        let (sut, spy) = makeSUT()
        let prev = ScreeningModels.PreviousOutcomeSummary(
            completedAt: Date(),
            severity: "normal",
            problematicSounds: [],
            daysSince: 14
        )
        await sut.presentRescreeningCheck(.init(
            isEligible: true,
            daysSinceLastScreening: nil,
            previousOutcomeSummary: prev
        ))
        XCTAssertNotNil(spy.rescreeningVM?.previousSummaryText)
    }
}
