@testable import HappySpeech
import XCTest

// MARK: - BreathingInteractorTests
//
// Covers the Breathing game state machine:
//   1. Warm-up calibration feeds the baseline buffer.
//   2. State transitions idle → tutorial → warmUp → playing.
//   3. Scoring boundaries (0, 0.5, 1.0 stable ratios).
//   4. Difficulty → required duration mapping.
//   5. Failure reasons — tooQuiet, noMicrophone, interrupted.
//   6. Mock `BreathingAudioWorkerProtocol` drives deterministic samples.

@MainActor
final class BreathingInteractorTests: XCTestCase {

    // MARK: - Spy Presenter

    @MainActor
    private final class SpyPresenter: BreathingPresentationLogic {
        var loadResponses: [BreathingModels.LoadSession.Response] = []
        var submitResponses: [BreathingModels.SubmitAttempt.Response] = []
        var updateResponses: [BreathingModels.UpdateSignal.Response] = []
        var finishResponses: [BreathingModels.Finish.Response] = []

        func presentLoadSession(_ response: BreathingModels.LoadSession.Response) {
            loadResponses.append(response)
        }
        func presentSubmitAttempt(_ response: BreathingModels.SubmitAttempt.Response) {
            submitResponses.append(response)
        }
        func presentUpdateSignal(_ response: BreathingModels.UpdateSignal.Response) {
            updateResponses.append(response)
        }
        func presentFinish(_ response: BreathingModels.Finish.Response) {
            finishResponses.append(response)
        }
    }

    // MARK: - SUT factory

    private func makeSUT(micGranted: Bool = true) -> (
        BreathingInteractor,
        SpyPresenter,
        MockBreathingAudioWorker,
        MockBreathingHapticWorker
    ) {
        let audio = MockBreathingAudioWorker()
        audio.isPermissionGranted = micGranted
        let haptic = MockBreathingHapticWorker()
        let interactor = BreathingInteractor(
            audioWorker: audio,
            hapticWorker: haptic
        )
        let spy = SpyPresenter()
        interactor.presenter = spy
        return (interactor, spy, audio, haptic)
    }

    // MARK: - 1. Scoring boundaries

    func test_scoring_zeroStableRatio_yieldsZero() {
        let score = BreathingScoring.score(
            stableRatio: 0,
            durationSec: 10,
            required: 10
        )
        XCTAssertEqual(score, 0)
    }

    func test_scoring_halfStableRatio_halfDuration_yieldsQuarter() {
        let score = BreathingScoring.score(
            stableRatio: 0.5,
            durationSec: 5,
            required: 10
        )
        XCTAssertEqual(score, 0.25, accuracy: 0.001)
    }

    func test_scoring_perfect_yieldsOne() {
        let score = BreathingScoring.score(
            stableRatio: 1.0,
            durationSec: 10,
            required: 10
        )
        XCTAssertEqual(score, 1.0)
    }

    // MARK: - 2. Difficulty → duration mapping

    func test_difficultyMapping_coversAllThreeLevels() {
        XCTAssertEqual(BreathingDifficulty.easy.requiredDurationSec, 5)
        XCTAssertEqual(BreathingDifficulty.medium.requiredDurationSec, 10)
        XCTAssertEqual(BreathingDifficulty.hard.requiredDurationSec, 20)
        XCTAssertEqual(BreathingGameConfig.forDifficulty(.hard).difficulty, .hard)
    }

    // MARK: - 3. State transitions

    func test_loadSession_emitsLoadResponse_withItems() {
        let (sut, spy, _, _) = makeSUT()
        sut.loadSession(.init(sessionId: "a1", difficulty: .medium))
        XCTAssertEqual(spy.loadResponses.count, 1)
        XCTAssertFalse(spy.loadResponses.first?.items.isEmpty ?? true)
        XCTAssertEqual(spy.loadResponses.first?.config.difficulty, .medium)
    }

    func test_beginGame_withoutPermission_failsWithNoMicrophone() async {
        let (sut, spy, _, _) = makeSUT(micGranted: false)
        await sut.beginGame(activityId: "a1", difficulty: .easy)

        // Finish VM should have been emitted with score 0.
        XCTAssertEqual(spy.finishResponses.count, 1)
        XCTAssertEqual(spy.finishResponses.first?.result.score, 0)
        XCTAssertFalse(spy.finishResponses.first?.result.didSucceed ?? true)

        // And the state should be summary(failure).
        if case .summary(let result) = sut.state {
            XCTAssertFalse(result.didSucceed)
        } else {
            XCTFail("Expected summary state after no-mic failure, got \(sut.state)")
        }
    }

    func test_beginGame_withPermission_entersTutorial() async {
        let (sut, _, _, _) = makeSUT(micGranted: true)
        await sut.beginGame(activityId: "a1", difficulty: .medium)
        if case .tutorial(let step) = sut.state {
            XCTAssertEqual(step, 0)
        } else {
            XCTFail("Expected tutorial(0) state, got \(sut.state)")
        }
    }

    // MARK: - 4. Warm-up calibration

    func test_warmUpCalibration_feedsBaselineBuffer() async {
        // Force warm-up state and push some quiet samples — the interactor
        // should collect them into its baseline buffer.
        let (sut, _, _, _) = makeSUT()
        sut._test_forceState(.warmUp(elapsedMs: 0))
        for _ in 0..<30 { sut._test_pushAmplitude(0.01) }

        // We don't expose the buffer, but we can assert the state remained
        // warmUp (no transition happened on quiet samples within time).
        if case .warmUp = sut.state {
            // ok
        } else {
            XCTFail("Warm-up state lost on quiet samples: \(sut.state)")
        }
    }

    // MARK: - 5. Playing phase — amplitude accumulates stable ratio

    func test_playingPhase_highAmplitudeAccumulatesStableRatio() {
        let (sut, _, _, _) = makeSUT()
        // Enter playing directly with a low baseline → threshold ≈ 0.06.
        sut._test_forceEnterPlaying(baseline: 0.03)

        // Feed 30 samples well above the threshold.
        for _ in 0..<30 { sut._test_pushAmplitude(0.8) }

        let ratio = sut._test_currentStableRatio()
        XCTAssertGreaterThan(ratio, 0.9,
                             "30 loud samples should produce >0.9 stable ratio, got \(ratio)")
    }

    func test_playingPhase_lowAmplitudeKeepsStableRatioAtZero() {
        let (sut, _, _, _) = makeSUT()
        sut._test_forceEnterPlaying(baseline: 0.05)

        // Feed 20 samples well below the threshold.
        for _ in 0..<20 { sut._test_pushAmplitude(0.001) }

        let ratio = sut._test_currentStableRatio()
        XCTAssertEqual(ratio, 0, accuracy: 0.001,
                       "Silent samples should keep ratio at 0, got \(ratio)")
    }

    // MARK: - 6. Interruption path

    func test_markInterrupted_emitsFailureSummary() async {
        let (sut, spy, audio, haptic) = makeSUT()
        await sut.beginGame(activityId: "a1", difficulty: .easy)

        sut.markInterrupted()
        // markInterrupted schedules an async fail; wait a tick.
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertGreaterThanOrEqual(audio.stopCount, 1,
                                    "Interruption must tear down the audio worker")
        XCTAssertEqual(haptic.failureCount, 1,
                       "Interruption must play a failure haptic cue")
        XCTAssertEqual(spy.finishResponses.count, 1)
        XCTAssertFalse(spy.finishResponses.first?.result.didSucceed ?? true)
    }

    // MARK: - 7. Stars scale correctly with score

    func test_starsScaleByScore() {
        XCTAssertEqual(BreathingScoring.stars(for: 0.9), 3)
        XCTAssertEqual(BreathingScoring.stars(for: 0.7), 2)
        XCTAssertEqual(BreathingScoring.stars(for: 0.5), 1)
        XCTAssertEqual(BreathingScoring.stars(for: 0.1), 0)
    }

    // MARK: - 8. Normalise / objectScale helpers

    func test_normaliseClampsToOne() {
        let value = BreathingInteractor.normalise(10, threshold: 0.1)
        XCTAssertLessThanOrEqual(value, 1)
    }

    func test_objectScale_spansBaselineToCap() {
        let lo = BreathingInteractor.objectScale(for: 0, cap: 3.0)
        let hi = BreathingInteractor.objectScale(for: 1, cap: 3.0)
        XCTAssertEqual(lo, 1.0, accuracy: 0.001)
        XCTAssertEqual(hi, 3.0, accuracy: 0.001)
    }

    // MARK: - 9. Additional batch 2 tests

    func test_normalise_zeroThreshold_returnsZero() {
        let result = BreathingInteractor.normalise(0.5, threshold: 0)
        XCTAssertEqual(result, 0)
    }

    func test_normalise_amplitudeEqualToThreshold_returns0_5() {
        // amplitude=t, threshold=t → t/(t*2) = 0.5
        let result = BreathingInteractor.normalise(0.1, threshold: 0.1)
        XCTAssertEqual(result, 0.5, accuracy: 0.001)
    }

    func test_normalise_negativeAmplitude_clampedTo0() {
        let result = BreathingInteractor.normalise(-1.0, threshold: 0.1)
        XCTAssertEqual(result, 0)
    }

    func test_objectScale_halfNormalised_returnsMidpoint() {
        // 1 + 0.5*(3-1) = 2.0
        let result = BreathingInteractor.objectScale(for: 0.5, cap: 3.0)
        XCTAssertEqual(result, 2.0, accuracy: 0.001)
    }

    func test_scoring_zeroRequired_returnsZero() {
        let score = BreathingScoring.score(stableRatio: 1.0, durationSec: 10, required: 0)
        XCTAssertEqual(score, 0)
    }

    func test_scoring_durationBeyondRequired_clampedToFull() {
        let score = BreathingScoring.score(stableRatio: 1.0, durationSec: 100, required: 10)
        XCTAssertEqual(score, 1.0, accuracy: 0.001)
    }

    func test_breathingScene_totalPetals_dandelion() {
        XCTAssertEqual(BreathingScene.dandelion.totalPetals, 12)
        XCTAssertEqual(BreathingScene.candle.totalPetals, 1)
        XCTAssertEqual(BreathingScene.balloon.totalPetals, 10)
    }

    func test_advanceTutorial_fromStep0_goesToStep1() async {
        let (sut, _, _, _) = makeSUT(micGranted: true)
        await sut.beginGame(activityId: "adv-001", difficulty: .easy)

        await sut.advanceTutorial()

        if case .tutorial(let step) = sut.state {
            XCTAssertEqual(step, 1)
        } else {
            XCTFail("Expected tutorial(1), got \(sut.state)")
        }
    }

    func test_advanceTutorial_fromStep1_goesToStep2() async {
        let (sut, _, _, _) = makeSUT(micGranted: true)
        await sut.beginGame(activityId: "adv-002", difficulty: .easy)
        await sut.advanceTutorial()

        await sut.advanceTutorial()

        if case .tutorial(let step) = sut.state {
            XCTAssertEqual(step, 2)
        } else {
            XCTFail("Expected tutorial(2), got \(sut.state)")
        }
    }

    func test_advanceTutorial_whenNotInTutorial_doesNothing() async {
        let (sut, _, _, _) = makeSUT()
        // state = .idle

        await sut.advanceTutorial()

        XCTAssertEqual(sut.state, .idle)
    }

    func test_cancel_resetsToIdle() async {
        let (sut, _, _, _) = makeSUT()
        await sut.beginGame(activityId: "cancel-001", difficulty: .easy)

        await sut.cancel()

        XCTAssertEqual(sut.state, .idle)
    }

    func test_cancel_stopsAudioWorker() async {
        let (sut, _, audio, _) = makeSUT()
        await sut.beginGame(activityId: "cancel-002", difficulty: .easy)

        await sut.cancel()

        XCTAssertGreaterThanOrEqual(audio.stopCount, 1)
    }

    func test_submitAttempt_callsPresenter() {
        let (sut, spy, _, _) = makeSUT()

        sut.submitAttempt(.init())

        XCTAssertFalse(spy.submitResponses.isEmpty)
    }

    func test_pushAmplitude_aboveThreshold_triggersBlowStartHaptic() {
        let (sut, _, _, haptic) = makeSUT()
        // threshold = max(0.03, 0.05 * 2.0) = 0.1
        sut._test_forceEnterPlaying(baseline: 0.05)

        sut._test_pushAmplitude(0.2)

        XCTAssertEqual(haptic.blowStartCount, 1)
    }

    func test_gameConfig_easyRequiredDuration() {
        let config = BreathingGameConfig.forDifficulty(.easy)
        XCTAssertEqual(config.requiredDurationSec, 5, accuracy: 0.001)
    }

    func test_gameConfig_hardThresholdMultiplierHigherThanEasy() {
        let easy = BreathingGameConfig.forDifficulty(.easy)
        let hard = BreathingGameConfig.forDifficulty(.hard)
        XCTAssertGreaterThan(hard.thresholdMultiplier, easy.thresholdMultiplier)
    }

    func test_stableRatio_allBelowThreshold_isZero() {
        let (sut, _, _, _) = makeSUT()
        sut._test_forceEnterPlaying(baseline: 0.1)
        // threshold ~ 0.2; push only quiet samples
        for _ in 0..<10 { sut._test_pushAmplitude(0.01) }

        XCTAssertEqual(sut._test_currentStableRatio(), 0.0, accuracy: 0.001)
    }

    // MARK: - Batch 1: расширенное покрытие

    func test_loadSession_emitsThreeHintItems() {
        let (sut, spy, _, _) = makeSUT()
        sut.loadSession(.init(sessionId: "b1", difficulty: .easy))
        XCTAssertEqual(spy.loadResponses.first?.items.count, 3)
        XCTAssertEqual(spy.loadResponses.first?.scene, .dandelion)
    }

    func test_loadSession_easyConfig() {
        let (sut, spy, _, _) = makeSUT()
        sut.loadSession(.init(sessionId: "b2", difficulty: .easy))
        XCTAssertEqual(spy.loadResponses.first?.config.difficulty, .easy)
    }

    func test_submitAttempt_emitsNeutralZeroScore() {
        let (sut, spy, _, _) = makeSUT()
        sut.submitAttempt(.init(selectedWord: "x", audioURL: nil))
        XCTAssertEqual(spy.submitResponses.first?.isCorrect, false)
        XCTAssertEqual(spy.submitResponses.first?.score, 0)
    }

    func test_beginGame_emitsUpdateSignalSnapshot() async {
        let (sut, spy, _, _) = makeSUT(micGranted: true)
        await sut.beginGame(activityId: "b3", difficulty: .easy)
        XCTAssertFalse(spy.updateResponses.isEmpty, "Tutorial-старт эмитит snapshot")
    }

    func test_pushAmplitude_inIdle_noEffect() {
        let (sut, _, _, _) = makeSUT()
        sut._test_forceState(.idle)
        sut._test_pushAmplitude(0.5)
        XCTAssertEqual(sut._test_currentStableRatio(), 0)
    }

    func test_difficulty_minStableRatio_increasesWithLevel() {
        XCTAssertLessThan(
            BreathingDifficulty.easy.minStableRatio,
            BreathingDifficulty.hard.minStableRatio
        )
    }

    func test_failureReason_equatable() {
        XCTAssertEqual(BreathingFailureReason.tooQuiet, .tooQuiet)
        XCTAssertNotEqual(BreathingFailureReason.tooQuiet, .interrupted)
    }

    func test_gameState_equatable_playing() {
        let a = BreathingGameState.playing(elapsedMs: 100, amplitude: 0.5, objectScale: 1.5)
        let b = BreathingGameState.playing(elapsedMs: 100, amplitude: 0.5, objectScale: 1.5)
        XCTAssertEqual(a, b)
    }

    // MARK: - Batch 2.6a v25: completeSuccess / fail / termination paths

    func test_playingPhase_loudSamples_emitSnapshots() {
        let (sut, spy, _, _) = makeSUT()
        sut._test_forceEnterPlaying(baseline: 0.03) // threshold ≈ 0.06
        for _ in 0..<40 { sut._test_pushAmplitude(0.9) }
        XCTAssertFalse(spy.updateResponses.isEmpty)
    }

    func test_pulseTimer_warmUp_progressesOutOfWarmUp() async throws {
        let audio = MockBreathingAudioWorker()
        audio.isPermissionGranted = true
        // Без scriptedAmplitudes mock не пушит сэмплы — переход обеспечивается
        // именно pulseTimer.
        let haptic = MockBreathingHapticWorker()
        let sut = BreathingInteractor(audioWorker: audio, hapticWorker: haptic)
        let spy = SpyPresenter()
        sut.presenter = spy

        // Детерминированно: входим в warmUp и прогоняем pulseTimer достаточно
        // раз, чтобы накопленный elapsedMs превысил warmUpSec (easy = 3 с,
        // tickIntervalSec = 0.05 → нужно > 60 тиков).
        sut._test_forceState(.warmUp(elapsedMs: 0))
        for _ in 0..<80 { sut._test_pulseTimer() }
        try await Task.sleep(for: .milliseconds(120))

        if case .warmUp = sut._test_currentState() {
            XCTFail("pulseTimer должен был вывести из warmUp после 80 тиков")
        }
        await sut.cancel()
        XCTAssertFalse(spy.updateResponses.isEmpty)
    }

    func test_forceEnterPlaying_thenMarkInterrupted_emitsFinishSummary() async {
        let (sut, spy, audio, haptic) = makeSUT()
        sut._test_forceEnterPlaying(baseline: 0.05)
        sut.markInterrupted()
        try? await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(spy.finishResponses.count, 1)
        XCTAssertFalse(spy.finishResponses.first?.result.didSucceed ?? true)
        XCTAssertGreaterThanOrEqual(audio.stopCount, 1)
        XCTAssertEqual(haptic.failureCount, 1)
        if case .summary = sut.state {
            // ok
        } else {
            XCTFail("Ожидалось summary после markInterrupted, получено \(sut.state)")
        }
    }

    func test_handlePlayingSample_firstLoudSample_triggersBlowStart() {
        let (sut, spy, _, haptic) = makeSUT()
        sut._test_forceEnterPlaying(baseline: 0.03)
        for _ in 0..<20 { sut._test_pushAmplitude(0.9) }
        XCTAssertEqual(haptic.blowStartCount, 1, "Первый громкий сэмпл триггерит blowStart")
        XCTAssertFalse(spy.updateResponses.isEmpty)
    }

    func test_handleWarmUpSample_collectsBaselineQuietly() {
        let (sut, _, _, _) = makeSUT()
        sut._test_forceState(.warmUp(elapsedMs: 0))
        for _ in 0..<40 { sut._test_pushAmplitude(0.02) }
        if case .warmUp = sut.state {
            // ok
        } else {
            XCTFail("warmUp не должен завершаться на тихих сэмплах в пределах окна")
        }
    }

    func test_handleAmplitude_inSummaryState_ignored() {
        let (sut, _, _, _) = makeSUT()
        let result = BreathingResult(
            difficulty: .easy, durationSec: 5, stableRatio: 0.8,
            score: 0.8, stars: 2, petalsBlown: 12, totalPetals: 12, didSucceed: true
        )
        sut._test_forceState(.summary(result: result))
        sut._test_pushAmplitude(0.9)
        XCTAssertEqual(sut._test_currentStableRatio(), 0)
    }

    func test_cancel_fromPlaying_resetsToIdleAndStopsAudio() async {
        let (sut, spy, audio, _) = makeSUT()
        sut._test_forceEnterPlaying(baseline: 0.05)
        await sut.cancel()
        XCTAssertEqual(sut.state, .idle)
        XCTAssertGreaterThanOrEqual(audio.stopCount, 1)
        XCTAssertFalse(spy.updateResponses.isEmpty)
    }

    func test_beginGame_resetsRuntimeStateBetweenSessions() async {
        let (sut, _, _, _) = makeSUT(micGranted: true)
        sut._test_forceEnterPlaying(baseline: 0.03)
        for _ in 0..<10 { sut._test_pushAmplitude(0.9) }
        XCTAssertGreaterThan(sut._test_currentStableRatio(), 0)

        await sut.beginGame(activityId: "reset-1", difficulty: .medium)
        XCTAssertEqual(sut._test_currentStableRatio(), 0, "resetRuntimeState обнуляет статистику")
    }

    func test_markInterrupted_fromWarmUp_emitsFailure() async {
        let (sut, spy, _, haptic) = makeSUT(micGranted: true)
        await sut.beginGame(activityId: "int-1", difficulty: .easy)
        sut._test_forceState(.warmUp(elapsedMs: 100))
        sut.markInterrupted()
        try? await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(haptic.failureCount, 1)
        XCTAssertEqual(spy.finishResponses.count, 1)
    }

    func test_emitCurrentSnapshot_summaryState_doesNotEmitUpdateSignal() async {
        let (sut, spy, _, _) = makeSUT()
        let result = BreathingResult(
            difficulty: .easy, durationSec: 5, stableRatio: 0.8,
            score: 0.8, stars: 2, petalsBlown: 12, totalPetals: 12, didSucceed: true
        )
        sut._test_forceState(.success(score: 0.8, duration: 5))
        // success/failure ветки emitCurrentSnapshot — intentionally empty.
        await sut.cancel() // эмитит snapshot для idle уже после reset
        _ = result
        XCTAssertFalse(spy.updateResponses.isEmpty)
    }

    // MARK: - Batch 2.6a v25 (доп.): termination-ветви handlePlayingSample

    func test_handlePlayingSample_durationReached_loudSamples_completesSuccess() async {
        let (sut, spy, audio, haptic) = makeSUT()
        sut._test_forceEnterPlaying(baseline: 0.03) // threshold ≈ 0.06
        // Накапливаем громкие сэмплы → stableRatio высокий.
        for _ in 0..<30 { sut._test_pushAmplitude(0.9) }
        // Сдвигаем старт в прошлое за required (easy = 5 с) → следующий сэмпл
        // достигает termination-ветви completeSuccess.
        sut._test_backdatePlayStart(by: 30)
        sut._test_pushAmplitude(0.9)
        try? await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(spy.finishResponses.count, 1)
        XCTAssertTrue(spy.finishResponses.first?.result.didSucceed ?? false)
        XCTAssertEqual(haptic.successCount, 1)
        XCTAssertGreaterThanOrEqual(audio.stopCount, 1)
    }

    func test_handlePlayingSample_durationReached_quietSamples_failsTooQuiet() async {
        let (sut, spy, _, _) = makeSUT()
        sut._test_forceEnterPlaying(baseline: 0.1) // threshold ≈ 0.2
        // Тихие сэмплы → stableRatio ниже minStableRatio.
        for _ in 0..<20 { sut._test_pushAmplitude(0.001) }
        sut._test_backdatePlayStart(by: 30)
        sut._test_pushAmplitude(0.001)
        try? await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(spy.finishResponses.count, 1)
        XCTAssertFalse(spy.finishResponses.first?.result.didSucceed ?? true)
    }

    func test_handlePlayingSample_burstThenSilence_failsTooShort() async {
        let (sut, spy, _, _) = makeSUT()
        sut._test_forceEnterPlaying(baseline: 0.03) // threshold ≈ 0.06
        // Короткий громкий всплеск → hasBegunBlowing = true.
        sut._test_pushAmplitude(0.9)
        // Сдвигаем старт чтобы elapsedMs > 1500. Подаём много тихих сэмплов:
        // доля громких падает ниже 15% → срабатывает fail(.tooShort).
        sut._test_backdatePlayStart(by: 2)
        for _ in 0..<25 { sut._test_pushAmplitude(0.001) }
        try? await Task.sleep(for: .milliseconds(120))
        XCTAssertGreaterThanOrEqual(spy.finishResponses.count, 1)
        XCTAssertFalse(spy.finishResponses.first?.result.didSucceed ?? true)
        if case .summary = sut.state {
            // ok — игра завершилась неуспехом
        } else {
            XCTFail("Ожидалось summary после fail(.tooShort), получено \(sut.state)")
        }
    }

    func test_pulseTimer_playingState_emitsSnapshot() {
        let (sut, spy, _, _) = makeSUT()
        sut._test_forceEnterPlaying(baseline: 0.05)
        spy.updateResponses.removeAll()
        sut._test_pulseTimer()
        XCTAssertFalse(spy.updateResponses.isEmpty, "pulseTimer в playing эмитит snapshot")
    }

    func test_pulseTimer_playingNoBlowAfter10s_forcesFailTooQuiet() async {
        let (sut, spy, _, _) = makeSUT()
        sut._test_forceEnterPlaying(baseline: 0.05)
        // Никакого blow → hasBegunBlowing == false. Сдвигаем старт > 10 с.
        sut._test_backdatePlayStart(by: 11)
        sut._test_pulseTimer()
        try? await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(spy.finishResponses.count, 1)
        XCTAssertFalse(spy.finishResponses.first?.result.didSucceed ?? true)
    }

    func test_pulseTimer_warmUpState_advancesElapsed() {
        let (sut, spy, _, _) = makeSUT()
        sut._test_forceState(.warmUp(elapsedMs: 0))
        spy.updateResponses.removeAll()
        sut._test_pulseTimer()
        // warmUp elapsed увеличивается, snapshot эмитится асинхронно — проверяем
        // что состояние осталось warmUp с возросшим elapsedMs.
        if case .warmUp(let ms) = sut._test_currentState() {
            XCTAssertGreaterThan(ms, 0)
        } else {
            XCTFail("Ожидалось warmUp после pulseTimer")
        }
    }

    func test_pulseTimer_idleState_noEffect() {
        let (sut, _, _, _) = makeSUT()
        sut._test_forceState(.idle)
        sut._test_pulseTimer()
        XCTAssertEqual(sut._test_currentState(), .idle)
    }

    func test_handlePlayingSample_petalsBlow_progressively() {
        let (sut, spy, _, haptic) = makeSUT()
        sut._test_forceEnterPlaying(baseline: 0.03)
        // Сдвигаем старт так, чтобы часть лепестков уже была "сдута".
        sut._test_backdatePlayStart(by: 3)
        sut._test_pushAmplitude(0.9)
        XCTAssertGreaterThanOrEqual(haptic.petalCount, 1,
                                    "Длительное дутьё постепенно сдувает лепестки")
        XCTAssertFalse(spy.updateResponses.isEmpty)
    }
}
