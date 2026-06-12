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
    var noInputCalled = false

    var lastLoadQuest: NarrativeQuestModels.LoadQuest.Response?
    var lastStartStage: NarrativeQuestModels.StartStage.Response?
    var lastEvaluate: NarrativeQuestModels.EvaluateWord.Response?
    var lastComplete: NarrativeQuestModels.CompleteQuest.Response?
    var lastNoInput: NarrativeQuestModels.NoInput.Response?

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
    func presentNoInput(_ response: NarrativeQuestModels.NoInput.Response) {
        noInputCalled = true
        lastNoInput = response
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

    // MARK: - No-input path: балл не начисляется, этап не продвигается

    func test_handleNoInput_presentsNoInput_withoutScoring() {
        let (sut, spy) = makeSUT()
        sut.loadQuest(.init(soundTarget: "С", childName: "Маша"))
        sut.startStage(.init(stageIndex: 0))
        sut.handleNoInput(.init(reason: .micDenied))
        XCTAssertTrue(spy.noInputCalled)
        XCTAssertFalse(spy.evaluateWordCalled)
        XCTAssertFalse(spy.advanceStageCalled)
        XCTAssertFalse((spy.lastNoInput?.message ?? "").isEmpty)
    }

    func test_handleNoInput_doesNotCollectEmoji() {
        let (sut, spy) = makeSUT()
        sut.loadQuest(.init(soundTarget: "С", childName: "Маша"))
        sut.startStage(.init(stageIndex: 0))
        sut.handleNoInput(.init(reason: .asrFailed))
        sut.completeQuest(.init())
        XCTAssertEqual(spy.lastComplete?.collectedEmojis.count, 0)
    }

    // MARK: - F1-016: spaced repetition

    private func makeSchedulerSUT() -> (NarrativeQuestInteractor, SpyNarrativePresenter, MockReviewSchedulerService) {
        let spy = SpyNarrativePresenter()
        let scheduler = MockReviewSchedulerService()
        let sut = NarrativeQuestInteractor(presenter: spy, reviewScheduler: scheduler)
        return (sut, spy, scheduler)
    }

    /// Ждёт, пока fire-and-forget `Task` запишет исход в мок (до ~1 с).
    private func waitForOutcome(_ scheduler: MockReviewSchedulerService, atLeast count: Int) async {
        for _ in 0..<50 {
            if await scheduler.outcomeCount >= count { return }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    func test_evaluateWord_passed_recordsPositiveOutcome() async {
        let (sut, _, scheduler) = makeSchedulerSUT()
        sut.loadQuest(.init(soundTarget: "С", childName: "Маша", childId: "child-q1"))
        sut.startStage(.init(stageIndex: 0))
        sut.evaluateWord(.init(transcript: "сова", confidence: 0.95))
        await waitForOutcome(scheduler, atLeast: 1)
        let last = await scheduler.lastOutcome
        XCTAssertEqual(last?.childId, "child-q1")
        XCTAssertEqual(last?.itemId, "сова")   // целевое слово этапа
        XCTAssertEqual(last?.sound, "С")        // whistling-группа этапа → «С»
        XCTAssertEqual(last?.correct, true)
    }

    func test_evaluateWord_failed_recordsNegativeOutcome() async {
        let (sut, _, scheduler) = makeSchedulerSUT()
        sut.loadQuest(.init(soundTarget: "Ш", childName: "Ваня", childId: "child-q2"))
        sut.startStage(.init(stageIndex: 0))
        sut.evaluateWord(.init(transcript: "абракадабра", confidence: 0.1))
        await waitForOutcome(scheduler, atLeast: 1)
        let last = await scheduler.lastOutcome
        XCTAssertEqual(last?.childId, "child-q2")
        XCTAssertEqual(last?.sound, "Ш")   // hissing-группа этапа → «Ш»
        XCTAssertEqual(last?.correct, false)
    }

    func test_evaluateWord_emptyChildId_doesNotRecord() async {
        let (sut, _, scheduler) = makeSchedulerSUT()
        sut.loadQuest(.init(soundTarget: "С", childName: "Маша", childId: ""))
        sut.startStage(.init(stageIndex: 0))
        sut.evaluateWord(.init(transcript: "сова", confidence: 0.95))
        try? await Task.sleep(nanoseconds: 120_000_000)
        let count = await scheduler.outcomeCount
        XCTAssertEqual(count, 0, "Пустой childId не пишет в расписание повторов")
    }

    func test_cyrillicSound_forQuestGroup_mapping() {
        XCTAssertEqual(NarrativeQuestInteractor.cyrillicSound(forQuestGroup: "whistling"), "С")
        XCTAssertEqual(NarrativeQuestInteractor.cyrillicSound(forQuestGroup: "hissing"), "Ш")
        XCTAssertEqual(NarrativeQuestInteractor.cyrillicSound(forQuestGroup: "sonants"), "Р")
        XCTAssertEqual(NarrativeQuestInteractor.cyrillicSound(forQuestGroup: "velar"), "К")
        XCTAssertEqual(NarrativeQuestInteractor.cyrillicSound(forQuestGroup: "other"), "other")
    }

    // MARK: - gap #10: recording/ASR pipeline moved into Interactor

    private func makeRecordingSUT(
        audio: QuestSpyAudio,
        asr: QuestSpyASR
    ) -> (NarrativeQuestInteractor, SpyNarrativePresenter) {
        let spy = SpyNarrativePresenter()
        let sut = NarrativeQuestInteractor(presenter: spy)
        sut.connect(audioService: audio, asrService: asr)
        return (sut, spy)
    }

    /// startListeningIntent: помечает этап записываемым (recordWord) и стартует
    /// запись с микрофона в Interactor (не во View).
    func test_startListeningIntent_marksRecording_andStartsAudio() async {
        let audio = QuestSpyAudio()
        let (sut, spy) = makeRecordingSUT(audio: audio, asr: QuestSpyASR())
        sut.loadQuest(.init(soundTarget: "С", childName: "Маша"))
        sut.startStage(.init(stageIndex: 0))

        sut.startListeningIntent(stageIndex: 0)
        XCTAssertTrue(spy.recordWordCalled, "Этап помечается записываемым синхронно")
        await waitUntil { audio.startRecordingCalled }
        XCTAssertTrue(audio.startRecordingCalled, "Запись стартует в Interactor")
    }

    /// stopListeningEarlyIntent: останавливает запись, ASR → evaluateWord.
    func test_stopListeningEarlyIntent_transcribesAndEvaluates() async {
        let audio = QuestSpyAudio()
        let asr = QuestSpyASR(transcript: "сова", confidence: 0.95)
        let (sut, spy) = makeRecordingSUT(audio: audio, asr: asr)
        sut.loadQuest(.init(soundTarget: "С", childName: "Маша"))
        sut.startStage(.init(stageIndex: 0))
        sut.startListeningIntent(stageIndex: 0)
        await waitUntil { audio.startRecordingCalled }

        sut.stopListeningEarlyIntent()
        await waitUntil { spy.evaluateWordCalled }

        XCTAssertTrue(audio.stopRecordingCalled)
        XCTAssertTrue(spy.evaluateWordCalled, "Транскрипт ушёл в скоринг")
        XCTAssertEqual(spy.lastEvaluate?.passed, true)
    }

    /// Отказ микрофона → noInput, без фабрикации оценки.
    func test_startListeningIntent_permissionDenied_presentsNoInput() async {
        let audio = QuestSpyAudio()
        audio.isPermissionGranted = false
        audio.permissionResult = false
        let (sut, spy) = makeRecordingSUT(audio: audio, asr: QuestSpyASR())
        sut.loadQuest(.init(soundTarget: "С", childName: "Маша"))
        sut.startStage(.init(stageIndex: 0))

        sut.startListeningIntent(stageIndex: 0)
        await waitUntil { spy.noInputCalled }

        XCTAssertTrue(spy.noInputCalled, "Отказ микрофона → noInput")
        XCTAssertFalse(spy.evaluateWordCalled, "Оценка не фабрикуется без ввода")
        XCTAssertFalse(audio.startRecordingCalled)
    }

    /// Сбой ASR → noInput (этап не продвигается, балл не начислен).
    func test_stopListeningEarlyIntent_asrFailure_presentsNoInput() async {
        let audio = QuestSpyAudio()
        let asr = QuestSpyASR()
        asr.shouldThrow = true
        let (sut, spy) = makeRecordingSUT(audio: audio, asr: asr)
        sut.loadQuest(.init(soundTarget: "С", childName: "Маша"))
        sut.startStage(.init(stageIndex: 0))
        sut.startListeningIntent(stageIndex: 0)
        await waitUntil { audio.startRecordingCalled }

        sut.stopListeningEarlyIntent()
        await waitUntil { spy.noInputCalled }

        XCTAssertTrue(spy.noInputCalled, "Сбой ASR → noInput")
        XCTAssertFalse(spy.evaluateWordCalled, "Без транскрипта оценка не выставляется")
    }

    /// Утилита: ждёт условие до ~1 с (для fire-and-forget recordingTask).
    private func waitUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<100 {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

// MARK: - Local mocks (gap #10 recording/ASR path)

private final class QuestSpyAudio: AudioService, @unchecked Sendable {
    var isPermissionGranted: Bool = true
    var amplitude: Float = 0
    var isRecording: Bool = false
    var permissionResult: Bool = true
    private(set) var startRecordingCalled = false
    private(set) var stopRecordingCalled = false

    func requestPermission() async -> Bool { permissionResult }
    func startRecording() async throws {
        startRecordingCalled = true
        isRecording = true
    }
    func stopRecording() async throws -> URL {
        stopRecordingCalled = true
        isRecording = false
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("quest.m4a")
    }
    func playAudio(url: URL) async throws {}
    func stopPlayback() {}
    func amplitudeBuffer() -> [Float] { [] }
}

private final class QuestSpyASR: ASRService, @unchecked Sendable {
    var isReady: Bool = true
    var transcript: String
    var confidence: Double
    var shouldThrow = false

    init(transcript: String = "сова", confidence: Double = 0.9) {
        self.transcript = transcript
        self.confidence = confidence
    }

    func transcribe(url: URL) async throws -> ASRResult {
        if shouldThrow { throw AppError.asrTranscriptionFailed("mock asr fail") }
        return ASRResult(transcript: transcript, confidence: confidence, wordTimestamps: [])
    }
    func loadModel() async throws {}
    func loadModel(tier: ASRTier) async throws {}
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
    func presentNoInput(_ response: NarrativeQuestModels.NoInput.Response) {}
    func presentAdvanceStage(_ response: NarrativeQuestModels.AdvanceStage.Response) {}
    func presentCompleteQuest(_ response: NarrativeQuestModels.CompleteQuest.Response) {}
}
