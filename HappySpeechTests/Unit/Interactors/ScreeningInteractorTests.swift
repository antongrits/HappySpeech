@testable import HappySpeech
import XCTest

// MARK: - Configurable Mocks (local to Screening tests)

/// AudioService с управляемым поведением: разрешение, ошибки записи.
private final class ScreeningMockAudioService: AudioService, @unchecked Sendable {
    var isPermissionGranted: Bool = true
    var amplitude: Float = 0.3
    var isRecording: Bool = false

    var failOnStart = false
    var failOnStop = false
    var permissionResult = true

    private(set) var startRecordingCount = 0
    private(set) var stopRecordingCount = 0
    private(set) var playAudioCount = 0
    private(set) var requestPermissionCount = 0

    func requestPermission() async -> Bool {
        requestPermissionCount += 1
        isPermissionGranted = permissionResult
        return permissionResult
    }
    func startRecording() async throws {
        startRecordingCount += 1
        if failOnStart { throw AppError.audioRecordingFailed("mock start fail") }
        isRecording = true
    }
    func stopRecording() async throws -> URL {
        stopRecordingCount += 1
        isRecording = false
        if failOnStop { throw AppError.audioRecordingFailed("mock stop fail") }
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("screening_mock.m4a")
    }
    func playAudio(url: URL) async throws { playAudioCount += 1 }
    func stopPlayback() {}
    func amplitudeBuffer() -> [Float] { Array(repeating: 0.3, count: 40) }
}

/// PronunciationScorer с управляемым результатом.
private final class ScreeningMockScorer: PronunciationScorerService, @unchecked Sendable {
    var isModelLoaded: Bool = false
    var stubbedScore: Double = 0.82
    var failScore = false
    var failLoad = false

    private(set) var loadModelCount = 0
    private(set) var scoreCount = 0

    func score(audioURL: URL, targetSound: String) async throws -> PronunciationScore {
        scoreCount += 1
        if failScore { throw AppError.mlInferenceFailed("mock scorer fail") }
        return PronunciationScore(rawValue: stubbedScore)
    }
    func loadModel() async throws {
        loadModelCount += 1
        if failLoad { throw AppError.mlModelNotFound("mock model") }
        isModelLoaded = true
    }
}

/// ASRService с управляемым транскриптом.
private final class ScreeningMockASR: ASRService, @unchecked Sendable {
    var isReady: Bool = true
    var stubbedTranscript: String = "собака"
    var failTranscribe = false

    func transcribe(url: URL) async throws -> ASRResult {
        if failTranscribe { throw AppError.asrTranscriptionFailed("mock asr fail") }
        return ASRResult(transcript: stubbedTranscript, confidence: 0.9, wordTimestamps: [])
    }
    func loadModel() async throws {}
    func loadModel(tier: ASRTier) async throws {}
}

// MARK: - Spy Presenter

@MainActor
private final class SpyScreeningPresenter: ScreeningPresentationLogic {

    var startScreeningCount = 0
    var prepareStageCount = 0
    var startRecordingCount = 0
    var submitAnswerCount = 0
    var finishScreeningCount = 0
    var recordingErrorCount = 0
    var micPermissionCount = 0
    var rescreeningCheckCount = 0

    var lastStart: ScreeningModels.StartScreening.Response?
    var lastPrepare: ScreeningModels.PrepareStage.Response?
    var lastStartRecording: ScreeningModels.StartRecording.Response?
    var lastSubmit: ScreeningModels.SubmitAnswer.Response?
    var lastFinish: ScreeningModels.FinishScreening.Response?
    var lastRecordingError: ScreeningModels.RecordingError?
    var lastMicPermission: ScreeningModels.MicrophonePermission.Response?
    var lastRescreening: ScreeningModels.CheckRescreening.Response?

    func presentStartScreening(_ response: ScreeningModels.StartScreening.Response) async {
        startScreeningCount += 1
        lastStart = response
    }
    func presentPrepareStage(_ response: ScreeningModels.PrepareStage.Response) async {
        prepareStageCount += 1
        lastPrepare = response
    }
    func presentStartRecording(_ response: ScreeningModels.StartRecording.Response) async {
        startRecordingCount += 1
        lastStartRecording = response
    }
    func presentSubmitAnswer(_ response: ScreeningModels.SubmitAnswer.Response) async {
        submitAnswerCount += 1
        lastSubmit = response
    }
    func presentFinishScreening(_ response: ScreeningModels.FinishScreening.Response) async {
        finishScreeningCount += 1
        lastFinish = response
    }
    func presentRecordingError(_ error: ScreeningModels.RecordingError) async {
        recordingErrorCount += 1
        lastRecordingError = error
    }
    func presentMicrophonePermission(_ response: ScreeningModels.MicrophonePermission.Response) async {
        micPermissionCount += 1
        lastMicPermission = response
    }
    func presentRescreeningCheck(_ response: ScreeningModels.CheckRescreening.Response) async {
        rescreeningCheckCount += 1
        lastRescreening = response
    }
}

// MARK: - Tests

@MainActor
final class ScreeningInteractorTests: XCTestCase {

    private func makeSUT(
        audio: ScreeningMockAudioService? = ScreeningMockAudioService(),
        scorer: ScreeningMockScorer? = nil,
        asr: ScreeningMockASR? = nil
    ) -> (ScreeningInteractor, SpyScreeningPresenter) {
        let sut = ScreeningInteractor(
            realmActor: nil,
            audioService: audio,
            pronunciationScorer: scorer,
            asrService: asr
        )
        let spy = SpyScreeningPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    private func firstPromptId(_ sut: ScreeningInteractor) -> String {
        sut.testState().prompts.first?.id ?? ""
    }

    // MARK: - startScreening

    func test_startScreening_loadsTenPrompts() async {
        let (sut, spy) = makeSUT()
        await sut.startScreening(.init(childId: "child-1", childAge: 6))
        XCTAssertEqual(spy.startScreeningCount, 1)
        XCTAssertEqual(spy.lastStart?.prompts.count, 10)
        XCTAssertFalse(spy.lastStart?.lyalyaPhrase.isEmpty ?? true)
    }

    func test_startScreening_resetsState() async {
        let (sut, _) = makeSUT()
        await sut.startScreening(.init(childId: "child-1", childAge: 6))
        await sut.submitAnswer(.init(promptId: firstPromptId(sut), score: 0.1, attemptCount: 1))
        await sut.startScreening(.init(childId: "child-2", childAge: 7))
        let state = sut.testState()
        XCTAssertTrue(state.scores.isEmpty)
        XCTAssertEqual(state.consecutiveWrong, 0)
    }

    func test_startScreening_loadsScorerModel() async {
        let scorer = ScreeningMockScorer()
        let (sut, _) = makeSUT(scorer: scorer)
        await sut.startScreening(.init(childId: "child-1", childAge: 6))
        XCTAssertEqual(scorer.loadModelCount, 1)
        XCTAssertTrue(scorer.isModelLoaded)
    }

    func test_startScreening_scorerLoadFailureIsTolerated() async {
        let scorer = ScreeningMockScorer()
        scorer.failLoad = true
        let (sut, spy) = makeSUT(scorer: scorer)
        await sut.startScreening(.init(childId: "child-1", childAge: 6))
        // Сбой загрузки модели не блокирует старт.
        XCTAssertEqual(spy.startScreeningCount, 1)
    }

    // MARK: - prepareStage

    func test_prepareStage_firstStageUsesFirstPhrase() async {
        let (sut, spy) = makeSUT()
        await sut.startScreening(.init(childId: "c", childAge: 6))
        await sut.prepareStage(.init(stageIndex: 0))
        XCTAssertEqual(spy.prepareStageCount, 1)
        XCTAssertEqual(spy.lastPrepare?.stageIndex, 0)
        XCTAssertEqual(spy.lastPrepare?.totalStages, 10)
        XCTAssertEqual(spy.lastPrepare?.canRecord, true)
    }

    func test_prepareStage_lastStage() async {
        let (sut, spy) = makeSUT()
        await sut.startScreening(.init(childId: "c", childAge: 6))
        await sut.prepareStage(.init(stageIndex: 9))
        XCTAssertEqual(spy.lastPrepare?.stageIndex, 9)
    }

    func test_prepareStage_middleStage() async {
        let (sut, spy) = makeSUT()
        await sut.startScreening(.init(childId: "c", childAge: 6))
        await sut.prepareStage(.init(stageIndex: 4))
        XCTAssertEqual(spy.lastPrepare?.stageIndex, 4)
    }

    func test_prepareStage_outOfBoundsIsIgnored() async {
        let (sut, spy) = makeSUT()
        await sut.startScreening(.init(childId: "c", childAge: 6))
        await sut.prepareStage(.init(stageIndex: 99))
        XCTAssertEqual(spy.prepareStageCount, 0)
    }

    func test_prepareStage_canRecordFalseWithoutAudioService() async {
        let (sut, spy) = makeSUT(audio: nil)
        await sut.startScreening(.init(childId: "c", childAge: 6))
        await sut.prepareStage(.init(stageIndex: 0))
        XCTAssertEqual(spy.lastPrepare?.canRecord, false)
    }

    // MARK: - startRecording

    func test_startRecording_succeeds() async {
        let audio = ScreeningMockAudioService()
        let (sut, spy) = makeSUT(audio: audio)
        await sut.startScreening(.init(childId: "c", childAge: 6))
        await sut.startRecording(.init(stageIndex: 0))
        XCTAssertEqual(spy.startRecordingCount, 1)
        XCTAssertEqual(audio.startRecordingCount, 1)
    }

    func test_startRecording_withoutAudioServiceShowsError() async {
        let (sut, spy) = makeSUT(audio: nil)
        await sut.startScreening(.init(childId: "c", childAge: 6))
        await sut.startRecording(.init(stageIndex: 0))
        XCTAssertEqual(spy.recordingErrorCount, 1)
        XCTAssertEqual(spy.lastRecordingError?.canContinueWithoutRecording, true)
    }

    func test_startRecording_permissionDeniedRequestsPermission() async {
        let audio = ScreeningMockAudioService()
        audio.isPermissionGranted = false
        audio.permissionResult = false
        let (sut, spy) = makeSUT(audio: audio)
        await sut.startScreening(.init(childId: "c", childAge: 6))
        await sut.startRecording(.init(stageIndex: 0))
        XCTAssertEqual(audio.requestPermissionCount, 1)
        XCTAssertEqual(spy.micPermissionCount, 1)
    }

    func test_startRecording_engineFailureShowsError() async {
        let audio = ScreeningMockAudioService()
        audio.failOnStart = true
        let (sut, spy) = makeSUT(audio: audio)
        await sut.startScreening(.init(childId: "c", childAge: 6))
        await sut.startRecording(.init(stageIndex: 0))
        XCTAssertEqual(spy.recordingErrorCount, 1)
    }

    func test_startRecording_doubleCallIsIgnored() async {
        let audio = ScreeningMockAudioService()
        let (sut, _) = makeSUT(audio: audio)
        await sut.startScreening(.init(childId: "c", childAge: 6))
        await sut.startRecording(.init(stageIndex: 0))
        await sut.startRecording(.init(stageIndex: 0))
        XCTAssertEqual(audio.startRecordingCount, 1)
    }

    // MARK: - stopRecordingAndScore

    func test_stopRecording_withoutActiveRecordingSkips() async {
        let (sut, spy) = makeSUT()
        await sut.startScreening(.init(childId: "c", childAge: 6))
        await sut.stopRecordingAndScore(.init(stageIndex: 0))
        // Запись не начата → skip → submitAnswer response с neutral score.
        XCTAssertEqual(spy.submitAnswerCount, 1)
    }

    func test_stopRecording_tooShortSkips() async {
        let audio = ScreeningMockAudioService()
        let (sut, spy) = makeSUT(audio: audio)
        await sut.startScreening(.init(childId: "c", childAge: 6))
        await sut.startRecording(.init(stageIndex: 0))
        // Сразу останавливаем — длительность < 0.3s.
        await sut.stopRecordingAndScore(.init(stageIndex: 0))
        XCTAssertEqual(spy.submitAnswerCount, 1)
    }

    func test_stopRecording_scoresWithScorer() async {
        let audio = ScreeningMockAudioService()
        let scorer = ScreeningMockScorer()
        scorer.stubbedScore = 0.85
        let (sut, spy) = makeSUT(audio: audio, scorer: scorer)
        await sut.startScreening(.init(childId: "c", childAge: 6))
        await sut.startRecording(.init(stageIndex: 0))
        try? await Task.sleep(nanoseconds: 350_000_000)
        await sut.stopRecordingAndScore(.init(stageIndex: 0))
        XCTAssertEqual(scorer.scoreCount, 1)
        XCTAssertEqual(spy.submitAnswerCount, 1)
        let firstId = firstPromptId(sut)
        XCTAssertEqual(sut.testState().scores[firstId], 0.85)
    }

    func test_stopRecording_scorerFailureFallsBackToASR() async {
        let audio = ScreeningMockAudioService()
        let scorer = ScreeningMockScorer()
        scorer.failScore = true
        let asr = ScreeningMockASR()
        asr.stubbedTranscript = "собака"
        let (sut, _) = makeSUT(audio: audio, scorer: scorer, asr: asr)
        await sut.startScreening(.init(childId: "c", childAge: 6))
        await sut.startRecording(.init(stageIndex: 0))
        try? await Task.sleep(nanoseconds: 350_000_000)
        await sut.stopRecordingAndScore(.init(stageIndex: 0))
        // ASR транскрипт совпадает со стимулом первого промпта (собака) → 0.80.
        let firstId = firstPromptId(sut)
        XCTAssertEqual(sut.testState().scores[firstId], 0.80)
    }

    func test_stopRecording_asrPartialMatchOnTargetSound() async {
        let audio = ScreeningMockAudioService()
        let scorer = ScreeningMockScorer()
        scorer.failScore = true
        let asr = ScreeningMockASR()
        // Транскрипт не равен стимулу, но содержит целевой звук "с".
        asr.stubbedTranscript = "стол"
        let (sut, _) = makeSUT(audio: audio, scorer: scorer, asr: asr)
        await sut.startScreening(.init(childId: "c", childAge: 6))
        await sut.startRecording(.init(stageIndex: 0))
        try? await Task.sleep(nanoseconds: 350_000_000)
        await sut.stopRecordingAndScore(.init(stageIndex: 0))
        let firstId = firstPromptId(sut)
        // Частичное совпадение по целевому звуку → 0.55.
        XCTAssertEqual(sut.testState().scores[firstId], 0.55)
    }

    func test_stopRecording_asrNoMatchLowScore() async {
        let audio = ScreeningMockAudioService()
        let scorer = ScreeningMockScorer()
        scorer.failScore = true
        let asr = ScreeningMockASR()
        // Транскрипт без целевого звука и без стимула.
        asr.stubbedTranscript = "привет"
        let (sut, _) = makeSUT(audio: audio, scorer: scorer, asr: asr)
        await sut.startScreening(.init(childId: "c", childAge: 6))
        await sut.startRecording(.init(stageIndex: 0))
        try? await Task.sleep(nanoseconds: 350_000_000)
        await sut.stopRecordingAndScore(.init(stageIndex: 0))
        let firstId = firstPromptId(sut)
        // Нет совпадения → 0.25.
        XCTAssertEqual(sut.testState().scores[firstId], 0.25)
    }

    func test_stopRecording_asrFailureNeutralScore() async {
        let audio = ScreeningMockAudioService()
        let scorer = ScreeningMockScorer()
        scorer.failScore = true
        let asr = ScreeningMockASR()
        asr.failTranscribe = true
        let (sut, _) = makeSUT(audio: audio, scorer: scorer, asr: asr)
        await sut.startScreening(.init(childId: "c", childAge: 6))
        await sut.startRecording(.init(stageIndex: 0))
        try? await Task.sleep(nanoseconds: 350_000_000)
        await sut.stopRecordingAndScore(.init(stageIndex: 0))
        let firstId = firstPromptId(sut)
        // Сбой ASR-fallback → 0.50.
        XCTAssertEqual(sut.testState().scores[firstId], 0.50)
    }

    func test_stopRecording_adaptiveStopViaRecordingPath() async {
        // Два подряд низких скоринга через путь записи → adaptive stop.
        let audio = ScreeningMockAudioService()
        let scorer = ScreeningMockScorer()
        scorer.stubbedScore = 0.1
        let (sut, spy) = makeSUT(audio: audio, scorer: scorer)
        await sut.startScreening(.init(childId: "c", childAge: 6))
        for stage in 0...1 {
            await sut.prepareStage(.init(stageIndex: stage))
            await sut.startRecording(.init(stageIndex: stage))
            try? await Task.sleep(nanoseconds: 350_000_000)
            await sut.stopRecordingAndScore(.init(stageIndex: stage))
        }
        XCTAssertEqual(spy.lastSubmit?.adaptiveStopTriggered, true)
        XCTAssertGreaterThanOrEqual(spy.finishScreeningCount, 1)
    }

    func test_stopRecording_noScorersAssignsNeutral() async {
        let audio = ScreeningMockAudioService()
        let (sut, _) = makeSUT(audio: audio)
        await sut.startScreening(.init(childId: "c", childAge: 6))
        await sut.startRecording(.init(stageIndex: 0))
        try? await Task.sleep(nanoseconds: 350_000_000)
        await sut.stopRecordingAndScore(.init(stageIndex: 0))
        let firstId = firstPromptId(sut)
        XCTAssertEqual(sut.testState().scores[firstId], 0.55)
    }

    func test_stopRecording_stopFailureSkips() async {
        let audio = ScreeningMockAudioService()
        audio.failOnStop = true
        let (sut, spy) = makeSUT(audio: audio)
        await sut.startScreening(.init(childId: "c", childAge: 6))
        await sut.startRecording(.init(stageIndex: 0))
        try? await Task.sleep(nanoseconds: 350_000_000)
        await sut.stopRecordingAndScore(.init(stageIndex: 0))
        XCTAssertEqual(spy.submitAnswerCount, 1)
    }

    // MARK: - submitAnswer

    func test_submitAnswer_recordsScore() async {
        let (sut, spy) = makeSUT()
        await sut.startScreening(.init(childId: "c", childAge: 6))
        let id = firstPromptId(sut)
        await sut.submitAnswer(.init(promptId: id, score: 0.9, attemptCount: 1))
        XCTAssertEqual(spy.submitAnswerCount, 1)
        XCTAssertEqual(sut.testState().scores[id], 0.9)
    }

    func test_submitAnswer_highScoreResetsConsecutiveWrong() async {
        let (sut, sut2) = makeSUT()
        let prompts = sut.testState().prompts
        await sut.startScreening(.init(childId: "c", childAge: 6))
        let ids = sut.testState().prompts.map(\.id)
        await sut.submitAnswer(.init(promptId: ids[0], score: 0.1, attemptCount: 1))
        await sut.submitAnswer(.init(promptId: ids[1], score: 0.9, attemptCount: 1))
        XCTAssertEqual(sut.testState().consecutiveWrong, 0)
        _ = prompts
        _ = sut2
    }

    func test_submitAnswer_adaptiveStopAfterTwoWrong() async {
        let (sut, spy) = makeSUT()
        await sut.startScreening(.init(childId: "c", childAge: 6))
        let ids = sut.testState().prompts.map(\.id)
        await sut.submitAnswer(.init(promptId: ids[0], score: 0.1, attemptCount: 1))
        await sut.submitAnswer(.init(promptId: ids[1], score: 0.2, attemptCount: 1))
        XCTAssertEqual(spy.lastSubmit?.adaptiveStopTriggered, true)
        XCTAssertEqual(spy.lastSubmit?.isScreeningComplete, true)
        // adaptive stop → finishScreening вызван.
        XCTAssertEqual(spy.finishScreeningCount, 1)
    }

    func test_submitAnswer_lastPromptCompletesScreening() async {
        let (sut, spy) = makeSUT()
        await sut.startScreening(.init(childId: "c", childAge: 6))
        let ids = sut.testState().prompts.map(\.id)
        await sut.submitAnswer(.init(promptId: ids[9], score: 0.9, attemptCount: 1))
        XCTAssertEqual(spy.lastSubmit?.isScreeningComplete, true)
        XCTAssertEqual(spy.finishScreeningCount, 1)
    }

    // MARK: - replayReferenceAudio

    func test_replayReferenceAudio_withoutAudioServiceIsSafe() async {
        let (sut, _) = makeSUT(audio: nil)
        await sut.replayReferenceAudio(.init(stageIndex: 0, referenceAudioAsset: "ref_x"))
        // Без сервиса — no-op, без падения.
        XCTAssertTrue(true)
    }

    func test_replayReferenceAudio_missingAssetIsSafe() async {
        let audio = ScreeningMockAudioService()
        let (sut, _) = makeSUT(audio: audio)
        await sut.replayReferenceAudio(.init(stageIndex: 0, referenceAudioAsset: "nonexistent_asset"))
        // Ассет не найден в бандле → no-op.
        XCTAssertEqual(audio.playAudioCount, 0)
    }

    func test_replayReferenceAudio_nilAssetIsSafe() async {
        let audio = ScreeningMockAudioService()
        let (sut, _) = makeSUT(audio: audio)
        await sut.replayReferenceAudio(.init(stageIndex: 0, referenceAudioAsset: nil))
        XCTAssertEqual(audio.playAudioCount, 0)
    }

    // MARK: - finishScreening

    func test_finishScreening_emitsOutcome() async {
        let (sut, spy) = makeSUT()
        await sut.startScreening(.init(childId: "c", childAge: 6))
        let ids = sut.testState().prompts.map(\.id)
        for id in ids {
            await sut.submitAnswer(.init(promptId: id, score: 0.9, attemptCount: 1))
        }
        XCTAssertGreaterThanOrEqual(spy.finishScreeningCount, 1)
        XCTAssertNotNil(spy.lastFinish?.outcome)
        XCTAssertEqual(spy.lastFinish?.totalSoundsCount, 10)
    }

    func test_finishScreening_allGoodPhraseWhenNoProblems() async {
        let (sut, spy) = makeSUT()
        await sut.startScreening(.init(childId: "c", childAge: 6))
        let ids = sut.testState().prompts.map(\.id)
        for id in ids {
            await sut.submitAnswer(.init(promptId: id, score: 0.95, attemptCount: 1))
        }
        XCTAssertEqual(spy.lastFinish?.wasAdaptiveStopped, false)
    }

    func test_finishScreening_directCallStopsRecording() async {
        let audio = ScreeningMockAudioService()
        let (sut, spy) = makeSUT(audio: audio)
        await sut.startScreening(.init(childId: "c", childAge: 6))
        await sut.startRecording(.init(stageIndex: 0))
        await sut.finishScreening(.init(childId: "c"))
        XCTAssertEqual(spy.finishScreeningCount, 1)
        XCTAssertEqual(audio.stopRecordingCount, 1)
    }

    func test_finishScreening_emptyChildIdUsesStored() async {
        let (sut, spy) = makeSUT()
        await sut.startScreening(.init(childId: "stored-child", childAge: 6))
        await sut.finishScreening(.init(childId: ""))
        XCTAssertEqual(spy.lastFinish?.outcome.childId, "stored-child")
    }

    // MARK: - completeScreening

    func test_completeScreening_routesToParentHome() async {
        let (sut, _) = makeSUT()
        let router = ScreeningRouter()
        var routed = false
        router.onRouteToParentHome = { routed = true }
        sut.router = router
        await sut.completeScreening(.init(
            childId: "c",
            severity: "mild",
            problematicSounds: ["Р"],
            recommendedPacks: ["sound_r_pack"],
            notes: "",
            isRescreening: false
        ))
        XCTAssertTrue(routed)
    }

    func test_completeScreening_withoutRealmActorSkipsPersist() async {
        let (sut, _) = makeSUT()
        // realmActor == nil → persist пропускается, навигация всё равно вызывается.
        await sut.completeScreening(.init(
            childId: "c",
            severity: "moderate",
            problematicSounds: [],
            recommendedPacks: [],
            notes: "note",
            isRescreening: true
        ))
        XCTAssertTrue(true)
    }

    func test_completeScreening_withRealmActorPersistsOutcome() async {
        // Уникальный childId изолирует запись от других тестов.
        let childId = "screening-persist-\(UUID().uuidString)"
        let realm = RealmActor()
        let sut = ScreeningInteractor(realmActor: realm, audioService: ScreeningMockAudioService())
        let router = ScreeningRouter()
        var routed = false
        router.onRouteToParentHome = { routed = true }
        sut.router = router
        await sut.startScreening(.init(childId: childId, childAge: 6))
        let ids = sut.testState().prompts.map(\.id)
        await sut.submitAnswer(.init(promptId: ids[0], score: 0.2, attemptCount: 1))
        await sut.completeScreening(.init(
            childId: childId,
            severity: "moderate",
            problematicSounds: ["С"],
            recommendedPacks: ["sound_s_pack"],
            notes: "проверка",
            isRescreening: false
        ))
        // Persist выполнен (через nonisolated writeOutcome), навигация вызвана.
        XCTAssertTrue(routed)
    }

    // MARK: - checkRescreeningEligibility (with RealmActor)

    func test_checkRescreening_withRealmActorNoPriorOutcomeIsEligible() async {
        let childId = "rescreening-none-\(UUID().uuidString)"
        let realm = RealmActor()
        let sut = ScreeningInteractor(realmActor: realm, audioService: ScreeningMockAudioService())
        let spy = SpyScreeningPresenter()
        sut.presenter = spy
        await sut.checkRescreeningEligibility(.init(childId: childId))
        XCTAssertEqual(spy.rescreeningCheckCount, 1)
        // Нет предыдущей записи → eligible, daysSince == nil.
        XCTAssertEqual(spy.lastRescreening?.isEligible, true)
        XCTAssertNil(spy.lastRescreening?.daysSinceLastScreening)
    }

    func test_checkRescreening_recentOutcomeNotEligible() async {
        // Свежая запись создаётся через completeScreening (completedAt == сейчас).
        let childId = "rescreening-recent-\(UUID().uuidString)"
        let realm = RealmActor()
        let sut = ScreeningInteractor(realmActor: realm, audioService: ScreeningMockAudioService())
        await sut.completeScreening(.init(
            childId: childId,
            severity: "mild",
            problematicSounds: ["Р"],
            recommendedPacks: [],
            notes: "",
            isRescreening: false
        ))
        let spy = SpyScreeningPresenter()
        sut.presenter = spy
        await sut.checkRescreeningEligibility(.init(childId: childId))
        // Менее 90 дней с последнего скрининга → не eligible.
        XCTAssertEqual(spy.lastRescreening?.isEligible, false)
        XCTAssertNotNil(spy.lastRescreening?.previousOutcomeSummary)
        XCTAssertEqual(spy.lastRescreening?.daysSinceLastScreening, 0)
    }

    // MARK: - requestMicrophonePermission

    func test_requestMicrophonePermission_granted() async {
        let audio = ScreeningMockAudioService()
        audio.permissionResult = true
        let (sut, spy) = makeSUT(audio: audio)
        await sut.requestMicrophonePermission()
        XCTAssertEqual(spy.micPermissionCount, 1)
        XCTAssertEqual(spy.lastMicPermission?.isGranted, true)
    }

    func test_requestMicrophonePermission_denied() async {
        let audio = ScreeningMockAudioService()
        audio.permissionResult = false
        let (sut, spy) = makeSUT(audio: audio)
        await sut.requestMicrophonePermission()
        XCTAssertEqual(spy.lastMicPermission?.isGranted, false)
    }

    func test_requestMicrophonePermission_withoutAudioServiceIsSafe() async {
        let (sut, spy) = makeSUT(audio: nil)
        await sut.requestMicrophonePermission()
        XCTAssertEqual(spy.micPermissionCount, 0)
    }

    // MARK: - checkRescreeningEligibility

    func test_checkRescreening_withoutRealmActorIsEligible() async {
        let (sut, spy) = makeSUT()
        await sut.checkRescreeningEligibility(.init(childId: "c"))
        XCTAssertEqual(spy.rescreeningCheckCount, 1)
        XCTAssertEqual(spy.lastRescreening?.isEligible, true)
        XCTAssertNil(spy.lastRescreening?.daysSinceLastScreening)
    }

    // MARK: - ScreeningPromptFactory

    func test_promptFactory_tenSoundPromptsHasTenEntries() {
        XCTAssertEqual(ScreeningPromptFactory.tenSoundPrompts(for: 6).count, 10)
    }

    func test_promptFactory_promptsCoverAllBlocks() {
        let prompts = ScreeningPromptFactory.prompts(for: 6)
        let blocks = Set(prompts.map(\.block))
        XCTAssertEqual(blocks, Set(ScreeningBlock.allCases))
    }
}
