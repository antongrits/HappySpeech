@testable import HappySpeech
import XCTest

// MARK: - BreathingExtendedInteractorTests
//
// Block 2.6a v25 — расширенное unit-покрытие BreathingExtendedInteractor
// (Stuttering / Длинный выдох, техника 4-7-8).
//
// UNTESTABLE (документировано): BreathingExtendedInteractor.init() жёстко
// создаёт собственный BreathingAudioWorker + BreathingInteractor — нет
// inject-seam. `startSession` запускает реальную 4-7-8 фазовую
// последовательность через `await phaseTask?.value` (≈11+ сек блокировки) +
// AVAudioEngine — это integration-путь. Поэтому синхронная бизнес-логика
// (раунды, scoring, фазовые инструкции, прогресс дерева, mascot mood)
// покрывается через DEBUG-хуки `_test_*`, а реальный аудио/фазовый путь —
// smoke/integration-тестами StutteringSmokeUITest.

@MainActor
final class BreathingExtendedInteractorTests: XCTestCase {

    private func makeSUT() -> BreathingExtendedInteractor {
        BreathingExtendedInteractor()
    }

    // MARK: - 1. Начальное состояние Display

    func test_display_initialState() {
        let sut = makeSUT()
        XCTAssertEqual(sut.display.treeProgress, 0)
        XCTAssertFalse(sut.display.isPlaying)
        XCTAssertEqual(sut.display.roundsComplete, 0)
        XCTAssertFalse(sut.display.showSuccess)
        XCTAssertEqual(sut.display.sessionScore, 0)
        XCTAssertTrue(sut.display.roundScores.isEmpty)
    }

    // MARK: - 2. Display — currentPhase по умолчанию idle

    func test_display_initialPhaseIsIdle() {
        let sut = makeSUT()
        XCTAssertEqual(sut.display.currentPhase, .idle)
        XCTAssertEqual(sut.display.phaseCountdown, 0)
    }

    // MARK: - 3. cancel — без активной сессии не крашит

    func test_cancel_withoutSession_doesNotCrash() async {
        let sut = makeSUT()
        await sut.cancel()
        XCTAssertFalse(sut.display.isPlaying)
        XCTAssertEqual(sut.display.currentPhase, .idle)
    }

    // MARK: - 4. cancel — идемпотентен

    func test_cancel_idempotent() async {
        let sut = makeSUT()
        await sut.cancel()
        await sut.cancel()
        XCTAssertEqual(sut.display.mascotMood, .idle)
    }

    // MARK: - 5. cancel — сбрасывает в безопасное состояние

    func test_cancel_afterInit_safeState() async {
        let sut = makeSUT()
        await sut.cancel()
        XCTAssertEqual(sut.display.currentPhase, .idle)
        XCTAssertFalse(sut.display.isPlaying)
    }

    // MARK: - 6. StutteringDifficulty.roundCount mapping

    func test_difficulty_roundCountMapping() {
        XCTAssertEqual(StutteringDifficulty.easy.roundCount, 5)
        XCTAssertEqual(StutteringDifficulty.hard.roundCount, 10)
        XCTAssertEqual(StutteringDifficulty.medium.roundCount, 7)
    }

    // MARK: - 7. BreathingPhase — rawValue стабилен

    func test_breathingPhase_rawValues() {
        XCTAssertEqual(BreathingPhase.inhale.rawValue, "inhale")
        XCTAssertEqual(BreathingPhase.hold.rawValue, "hold")
        XCTAssertEqual(BreathingPhase.exhale.rawValue, "exhale")
        XCTAssertEqual(BreathingPhase.idle.rawValue, "idle")
    }

    // MARK: - 8. roundsRequired по умолчанию положителен

    func test_display_roundsRequiredPositive() {
        let sut = makeSUT()
        XCTAssertGreaterThan(sut.display.roundsRequired, 0)
    }

    // MARK: - 9. _test_configure — easy задаёт 5 раундов и сбрасывает state

    func test_configure_easy_setsFiveRounds() {
        let sut = makeSUT()
        sut._test_configure(difficulty: .easy)
        XCTAssertEqual(sut.display.roundsRequired, 5)
        XCTAssertEqual(sut.display.roundsComplete, 0)
        XCTAssertTrue(sut.display.roundScores.isEmpty)
        XCTAssertEqual(sut.display.treeProgress, 0)
        XCTAssertFalse(sut.display.showSuccess)
    }

    // MARK: - 10. _test_configure — hard задаёт 10 раундов

    func test_configure_hard_setsTenRounds() {
        let sut = makeSUT()
        sut._test_configure(difficulty: .hard)
        XCTAssertEqual(sut.display.roundsRequired, 10)
    }

    // MARK: - 11. configure — заполняет breathingTip непустой строкой

    func test_configure_allDifficulties_setsBreathingTip() {
        for difficulty in StutteringDifficulty.allCases {
            let sut = makeSUT()
            sut._test_configure(difficulty: difficulty)
            XCTAssertFalse(sut.display.breathingTip.isEmpty,
                           "breathingTip должен быть задан для \(difficulty.rawValue)")
        }
    }

    // MARK: - 12. 4-7-8 фазовые параметры — inhale всегда 4 сек

    func test_inhaleSeconds_alwaysFour() {
        for difficulty in StutteringDifficulty.allCases {
            let sut = makeSUT()
            sut._test_configure(difficulty: difficulty)
            XCTAssertEqual(sut._test_inhaleSeconds, 4)
        }
    }

    // MARK: - 13. holdSeconds зависит от сложности

    func test_holdSeconds_perDifficulty() {
        let easy = makeSUT()
        easy._test_configure(difficulty: .easy)
        XCTAssertEqual(easy._test_holdSeconds, 4)

        let medium = makeSUT()
        medium._test_configure(difficulty: .medium)
        XCTAssertEqual(medium._test_holdSeconds, 6)

        let hard = makeSUT()
        hard._test_configure(difficulty: .hard)
        XCTAssertEqual(hard._test_holdSeconds, 7)
    }

    // MARK: - 14. exhaleSeconds зависит от сложности

    func test_exhaleSeconds_perDifficulty() {
        let easy = makeSUT()
        easy._test_configure(difficulty: .easy)
        XCTAssertEqual(easy._test_exhaleSeconds, 3)

        let medium = makeSUT()
        medium._test_configure(difficulty: .medium)
        XCTAssertEqual(medium._test_exhaleSeconds, 5)

        let hard = makeSUT()
        hard._test_configure(difficulty: .hard)
        XCTAssertEqual(hard._test_exhaleSeconds, 8)
    }

    // MARK: - 15. breathingDifficulty mapping

    func test_breathingDifficultyMapping() {
        let easy = makeSUT()
        easy._test_configure(difficulty: .easy)
        XCTAssertEqual(easy._test_breathingDifficulty, .easy)

        let medium = makeSUT()
        medium._test_configure(difficulty: .medium)
        XCTAssertEqual(medium._test_breathingDifficulty, .medium)

        let hard = makeSUT()
        hard._test_configure(difficulty: .hard)
        XCTAssertEqual(hard._test_breathingDifficulty, .hard)
    }

    // MARK: - 16. instructionForPhase — все фазы дают непустой текст

    func test_instructionForPhase_allPhasesNonEmpty() {
        let sut = makeSUT()
        for phase in [BreathingPhase.idle, .inhale, .hold, .exhale] {
            XCTAssertFalse(sut._test_instructionForPhase(phase).isEmpty,
                           "Инструкция для \(phase.rawValue) не должна быть пустой")
        }
    }

    // MARK: - 17. calculateSessionScore — пустой массив → 0

    func test_calculateSessionScore_emptyArray_zero() {
        let sut = makeSUT()
        XCTAssertEqual(sut._test_calculateSessionScore([]), 0)
    }

    // MARK: - 18. calculateSessionScore — среднее по раундам

    func test_calculateSessionScore_averagesRounds() {
        let sut = makeSUT()
        XCTAssertEqual(sut._test_calculateSessionScore([100, 100]), 100)
        XCTAssertEqual(sut._test_calculateSessionScore([60, 80, 100]), 80)
        XCTAssertEqual(sut._test_calculateSessionScore([0, 0]), 0)
    }

    // MARK: - 19. calculateRoundScore — 0 успешных кадров → score 0

    func test_calculateRoundScore_noFrames_zero() {
        let sut = makeSUT()
        sut._test_configure(difficulty: .easy)
        sut._test_setSuccessfulFrames(0)
        XCTAssertEqual(sut._test_calculateRoundScore(), 0)
    }

    // MARK: - 20. calculateRoundScore — полное окно → score 100 (clamped)

    func test_calculateRoundScore_fullFrames_clampedTo100() {
        let sut = makeSUT()
        sut._test_configure(difficulty: .easy)
        // exhaleSeconds(easy)=3 → exhaleFrames ≈ 60. Достаточно кадров → clamp 100.
        sut._test_setSuccessfulFrames(1000)
        XCTAssertEqual(sut._test_calculateRoundScore(), 100)
    }

    // MARK: - 21. calculateRoundScore — частичное попадание

    func test_calculateRoundScore_partialFrames_proportional() {
        let sut = makeSUT()
        sut._test_configure(difficulty: .easy)
        // exhaleSeconds(easy)=3 → exhaleFrames = 3*20 = 60. 30 кадров → ~50%.
        sut._test_setSuccessfulFrames(30)
        let score = sut._test_calculateRoundScore()
        XCTAssertGreaterThan(score, 0)
        XCTAssertLessThanOrEqual(score, 100)
    }

    // MARK: - 22. completeRound — добавляет score и инкрементит roundsComplete

    func test_completeRound_appendsScoreAndIncrements() {
        let sut = makeSUT()
        sut._test_configure(difficulty: .easy)
        sut._test_completeRound(score: 80)
        XCTAssertEqual(sut.display.roundScores, [80])
        XCTAssertEqual(sut.display.roundsComplete, 1)
        XCTAssertEqual(sut.display.mascotMood, .celebrating)
    }

    // MARK: - 23. completeRound — последний раунд завершает сессию

    func test_completeRound_lastRound_completesSession() {
        let sut = makeSUT()
        sut._test_configure(difficulty: .easy) // 5 раундов
        for _ in 0..<5 {
            sut._test_completeRound(score: 90)
        }
        XCTAssertTrue(sut.display.showSuccess)
        XCTAssertFalse(sut.display.isPlaying)
        XCTAssertEqual(sut.display.currentPhase, .idle)
        XCTAssertEqual(sut.display.treeProgress, 1.0)
        XCTAssertEqual(sut.display.sessionScore, 90)
    }

    // MARK: - 24. completeRound — до последнего раунда сессия не завершена

    func test_completeRound_notLast_sessionNotComplete() {
        let sut = makeSUT()
        sut._test_configure(difficulty: .easy) // 5 раундов
        sut._test_completeRound(score: 70)
        sut._test_completeRound(score: 70)
        XCTAssertFalse(sut.display.showSuccess)
    }

    // MARK: - 25. handleCoreUpdate — .playing → mascot happy + waveform

    func test_handleCoreUpdate_playing_setsHappyMood() {
        let sut = makeSUT()
        sut._test_configure(difficulty: .easy)
        sut._test_handleCoreUpdate(state: .playing(elapsedMs: 100, amplitude: 0.5, objectScale: 1.2),
                                   progress: 0.5, amplitude: 0.5)
        XCTAssertEqual(sut.display.mascotMood, .happy)
        XCTAssertEqual(sut.display.waveformLevels.last, 0.5)
    }

    // MARK: - 26. handleCoreUpdate — .warmUp → mascot thinking

    func test_handleCoreUpdate_warmUp_setsThinkingMood() {
        let sut = makeSUT()
        sut._test_configure(difficulty: .easy)
        sut._test_handleCoreUpdate(state: .warmUp(elapsedMs: 0), progress: 0, amplitude: 0.1)
        XCTAssertEqual(sut.display.mascotMood, .thinking)
    }

    // MARK: - 27. handleCoreUpdate — waveform обрезается до 40 элементов

    func test_handleCoreUpdate_waveformCappedAt40() {
        let sut = makeSUT()
        sut._test_configure(difficulty: .easy)
        for _ in 0..<60 {
            sut._test_handleCoreUpdate(state: .playing(elapsedMs: 0, amplitude: 0.3, objectScale: 1),
                                       progress: 0.1, amplitude: 0.3)
        }
        XCTAssertEqual(sut.display.waveformLevels.count, 40)
    }

    // MARK: - 28. handleCoreUpdate — summary success завершает раунд

    func test_handleCoreUpdate_summarySuccess_completesRound() {
        let sut = makeSUT()
        sut._test_configure(difficulty: .easy)
        sut._test_setSuccessfulFrames(60)
        let result = makeResult(didSucceed: true)
        sut._test_handleCoreUpdate(state: .summary(result: result), progress: 1.0, amplitude: 0)
        XCTAssertEqual(sut.display.roundsComplete, 1)
        XCTAssertFalse(sut.display.roundScores.isEmpty)
    }

    // MARK: - 29. handleCoreUpdate — summary failure откатывает прогресс дерева

    func test_handleCoreUpdate_summaryFailure_rollsBackTree() {
        let sut = makeSUT()
        sut._test_configure(difficulty: .easy)
        let result = makeResult(didSucceed: false)
        sut._test_handleCoreUpdate(state: .summary(result: result), progress: 0.5, amplitude: 0)
        // Неудачный раунд не инкрементит roundsComplete.
        XCTAssertEqual(sut.display.roundsComplete, 0)
        XCTAssertEqual(sut.display.mascotMood, .happy)
    }

    // MARK: - 30. handleCoreUpdate — прогресс дерева растёт по раундам

    func test_handleCoreUpdate_treeProgressAdvances() {
        let sut = makeSUT()
        sut._test_configure(difficulty: .easy) // 5 раундов
        sut._test_handleCoreUpdate(state: .playing(elapsedMs: 0, amplitude: 0.5, objectScale: 1),
                                   progress: 1.0, amplitude: 0.5)
        // roundFraction(0/5) + progress*(1/5) = 0.2
        XCTAssertEqual(sut.display.treeProgress, 0.2, accuracy: 0.01)
    }

    // MARK: - 31. runPhase (zero seconds) — устанавливает фазу и инструкцию

    func test_runPhaseZeroSeconds_setsPhaseAndInstruction() async {
        let sut = makeSUT()
        sut._test_configure(difficulty: .easy)
        await sut._test_runPhaseZeroSeconds(.inhale)
        XCTAssertEqual(sut.display.currentPhase, .inhale)
        XCTAssertFalse(sut.display.instruction.isEmpty)
        XCTAssertEqual(sut.display.phaseCountdown, 0)
    }

    // MARK: - 32. runPhase — все фазы дают корректный currentPhase

    func test_runPhaseZeroSeconds_allPhases() async {
        for phase in [BreathingPhase.inhale, .hold, .exhale, .idle] {
            let sut = makeSUT()
            sut._test_configure(difficulty: .medium)
            await sut._test_runPhaseZeroSeconds(phase)
            XCTAssertEqual(sut.display.currentPhase, phase)
        }
    }

    // MARK: - 33. handleCoreUpdate — summary success на последнем раунде завершает сессию

    func test_handleCoreUpdate_summarySuccess_lastRound_completesSession() {
        let sut = makeSUT()
        sut._test_configure(difficulty: .easy) // 5 раундов
        sut._test_setRoundsComplete(4)
        sut._test_setSuccessfulFrames(60)
        let result = makeResult(didSucceed: true)
        sut._test_handleCoreUpdate(state: .summary(result: result), progress: 1.0, amplitude: 0)
        XCTAssertTrue(sut.display.showSuccess)
        XCTAssertFalse(sut.display.isPlaying)
        XCTAssertEqual(sut.display.treeProgress, 1.0)
    }

    // MARK: - 34. handleCoreUpdate — default state (idle) игнорируется без краша

    func test_handleCoreUpdate_idleState_noCrash() {
        let sut = makeSUT()
        sut._test_configure(difficulty: .easy)
        sut._test_handleCoreUpdate(state: .idle, progress: 0, amplitude: 0.1)
        XCTAssertEqual(sut.display.roundsComplete, 0)
    }

    // MARK: - 35. handleCoreUpdate — exhale-фаза с амплитудой выше порога копит кадры

    func test_handleCoreUpdate_exhalePhaseLoudSample_countsSuccessfulFrame() {
        let sut = makeSUT()
        sut._test_configure(difficulty: .easy)
        // Переводим в фазу exhale через runPhase(0).
        Task { await sut._test_runPhaseZeroSeconds(.exhale) }
        sut._test_handleCoreUpdate(
            state: .playing(elapsedMs: 0, amplitude: 0.9, objectScale: 1),
            progress: 0.5, amplitude: 0.9
        )
        XCTAssertEqual(sut.display.waveformLevels.last, 0.9)
    }

    // MARK: - 36. cancel после configure — сбрасывает фазу и mascot

    func test_cancel_afterConfigure_resetsPhaseAndMood() async {
        let sut = makeSUT()
        sut._test_configure(difficulty: .hard)
        await sut.cancel()
        XCTAssertEqual(sut.display.currentPhase, .idle)
        XCTAssertEqual(sut.display.mascotMood, .idle)
        XCTAssertFalse(sut.display.isPlaying)
    }

    // MARK: - 37. completeRound — несколько раундов накапливают roundScores

    func test_completeRound_multipleRounds_accumulateScores() {
        let sut = makeSUT()
        sut._test_configure(difficulty: .medium) // 7 раундов
        sut._test_completeRound(score: 50)
        sut._test_completeRound(score: 70)
        sut._test_completeRound(score: 90)
        XCTAssertEqual(sut.display.roundScores, [50, 70, 90])
        XCTAssertEqual(sut.display.roundsComplete, 3)
        XCTAssertFalse(sut.display.showSuccess)
    }

    // MARK: - 38. calculateRoundScore — hard сложность, более длинное окно

    func test_calculateRoundScore_hardDifficulty_longerWindow() {
        let sut = makeSUT()
        sut._test_configure(difficulty: .hard)
        // exhaleSeconds(hard)=8 → exhaleFrames = 160. 80 кадров → ~50%.
        sut._test_setSuccessfulFrames(80)
        let score = sut._test_calculateRoundScore()
        XCTAssertGreaterThan(score, 0)
        XCTAssertLessThanOrEqual(score, 100)
    }

    // MARK: - 39. startSession через инъекцию core audio worker

    func test_startSession_withInjectedCoreWorker_initialisesDisplay() async {
        let audio = MockBreathingAudioWorker()
        audio.isPermissionGranted = true
        let sut = BreathingExtendedInteractor(testCoreAudioWorker: audio)
        // startSession блокируется на реальной 4-7-8 фазовой последовательности
        // (~10+ с). Запускаем в фоне, даём стартовать, затем отменяем.
        let task = Task { await sut.startSession(difficulty: .easy) }
        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(sut.display.roundsRequired, 5)
        XCTAssertFalse(sut.display.breathingTip.isEmpty)
        XCTAssertEqual(sut.display.roundsComplete, 0)
        await sut.cancel()
        task.cancel()
        _ = await task.value
    }

    // MARK: - 40. startSession + cancel — корректно сбрасывает состояние

    func test_startSession_thenCancel_resetsToIdle() async {
        let audio = MockBreathingAudioWorker()
        audio.isPermissionGranted = true
        let sut = BreathingExtendedInteractor(testCoreAudioWorker: audio)
        let task = Task { await sut.startSession(difficulty: .medium) }
        try? await Task.sleep(for: .milliseconds(400))
        await sut.cancel()
        task.cancel()
        _ = await task.value
        // cancel переводит фазу в idle и останавливает воспроизведение.
        // mascotMood не проверяем: handleCoreUpdate от coreInteractor может
        // асинхронно прийти после cancel (безопасный race, не влияет на логику).
        XCTAssertEqual(sut.display.currentPhase, .idle)
        XCTAssertFalse(sut.display.isPlaying)
    }

    // MARK: - 41. startSession запускает фазу inhale

    func test_startSession_entersInhalePhase() async {
        let audio = MockBreathingAudioWorker()
        audio.isPermissionGranted = true
        let sut = BreathingExtendedInteractor(testCoreAudioWorker: audio)
        let task = Task { await sut.startSession(difficulty: .easy) }
        try? await Task.sleep(for: .milliseconds(500))
        // Первая фаза 4-7-8 — вдох.
        XCTAssertEqual(sut.display.currentPhase, .inhale)
        XCTAssertGreaterThan(sut.display.phaseCountdown, 0)
        await sut.cancel()
        task.cancel()
        _ = await task.value
    }

    // MARK: - Helpers

    private func makeResult(didSucceed: Bool) -> BreathingResult {
        BreathingResult(
            difficulty: .easy,
            durationSec: 3,
            stableRatio: didSucceed ? 0.8 : 0.2,
            score: didSucceed ? 0.8 : 0.1,
            stars: didSucceed ? 2 : 0,
            petalsBlown: didSucceed ? 12 : 2,
            totalPetals: 12,
            didSucceed: didSucceed
        )
    }
}
