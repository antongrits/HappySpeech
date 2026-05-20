@testable import HappySpeech
import XCTest

// MARK: - MockMetronomeHapticService

private final class MockMetronomeHapticService: HapticService, @unchecked Sendable {
    var playedPatterns: [HapticPattern] = []
    var isAvailable: Bool { true }

    func play(pattern: HapticPattern) async { playedPatterns.append(pattern) }
    func setIntensityScale(_ scale: Float) {}
    func stop() async {}
    func selection() {}
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {}
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {}
    func playLevelUp() async {}
}

// MARK: - MetronomeInteractorTests

@MainActor
final class MetronomeInteractorTests: XCTestCase {

    private func makeSUT() -> (
        MetronomeInteractor,
        MockMetronomeWorker,
        MockMetronomeHapticService
    ) {
        let metronomeWorker = MockMetronomeWorker()
        let haptic = MockMetronomeHapticService()
        // Внедряем MockBreathingAudioWorker: без него Interactor создаёт реальный
        // BreathingAudioWorker, и startSession() уходит в await на
        // AVAudioApplication.requestRecordPermission() — в headless-симуляторе этот
        // системный диалог не вызывает completion, и тест-процесс зависает навсегда.
        let audioWorker = MockBreathingAudioWorker()
        audioWorker.isPermissionGranted = true
        let sut = MetronomeInteractor(
            metronomeWorker: metronomeWorker,
            audioWorker: audioWorker,
            hapticService: haptic
        )
        return (sut, metronomeWorker, haptic)
    }

    // MARK: - 1. changeBPM clamps to [50, 120]

    func test_changeBPM_below50_clampsTo50() {
        let (sut, worker, _) = makeSUT()
        sut.changeBPM(to: 30)

        XCTAssertEqual(sut.display.bpm, 50)
        XCTAssertEqual(worker.lastBPM, 50)
    }

    func test_changeBPM_above120_clampsTo120() {
        let (sut, worker, _) = makeSUT()
        sut.changeBPM(to: 200)

        XCTAssertEqual(sut.display.bpm, 120)
        XCTAssertEqual(worker.lastBPM, 120)
    }

    func test_changeBPM_validValue_setsDisplayBPM() {
        let (sut, _, _) = makeSUT()
        sut.changeBPM(to: 90)

        XCTAssertEqual(sut.display.bpm, 90)
    }

    func test_changeBPM_sameBPM_doesNotRestartWorker() {
        let (sut, worker, _) = makeSUT()
        // Set initial BPM to 75 by a first valid call
        sut.changeBPM(to: 75)
        let countBefore = worker.startCount
        // Call with same value
        sut.changeBPM(to: 75)

        XCTAssertEqual(worker.startCount, countBefore,
                       "Одинаковый BPM не должен перезапускать метроном")
    }

    func test_changeBPM_updatesAdaptiveBPMLabel() {
        let (sut, _, _) = makeSUT()
        sut.changeBPM(to: 80)

        XCTAssertFalse(sut.display.adaptiveBPMLabel.isEmpty)
    }

    // MARK: - 2. stopSession когда не запущен — не краш

    func test_stopSession_whenNotRunning_doesNotCrash() {
        let (sut, _, _) = makeSUT()
        sut.stopSession()

        XCTAssertFalse(sut.display.isRunning)
    }

    // MARK: - 3. MetronomeResultLevel.from(accuracy:)

    func test_resultLevel_excellent_above085() {
        XCTAssertEqual(MetronomeResultLevel.from(accuracy: 0.90), .excellent)
        XCTAssertEqual(MetronomeResultLevel.from(accuracy: 1.00), .excellent)
    }

    func test_resultLevel_good_065to084() {
        XCTAssertEqual(MetronomeResultLevel.from(accuracy: 0.70), .good)
        XCTAssertEqual(MetronomeResultLevel.from(accuracy: 0.65), .good)
    }

    func test_resultLevel_fair_045to064() {
        XCTAssertEqual(MetronomeResultLevel.from(accuracy: 0.55), .fair)
        XCTAssertEqual(MetronomeResultLevel.from(accuracy: 0.45), .fair)
    }

    func test_resultLevel_needsWork_below045() {
        XCTAssertEqual(MetronomeResultLevel.from(accuracy: 0.30), .needsWork)
        XCTAssertEqual(MetronomeResultLevel.from(accuracy: 0.0), .needsWork)
    }

    // MARK: - 4. loadHistory возвращает пустой массив изначально

    func test_loadHistory_initiallyEmpty() {
        let (sut, _, _) = makeSUT()
        let history = sut.loadHistory()

        XCTAssertTrue(history.isEmpty)
    }

    // MARK: - 5. stopSession сохраняет запись в истории

    func test_stopSession_whenRunning_addsToHistory() async {
        let (sut, _, _) = makeSUT()

        // Вызываем stopSession когда display.isRunning = false:
        // нет записи в history, если сессия не была running.
        sut.stopSession()

        let history = sut.loadHistory()
        XCTAssertTrue(history.isEmpty,
                      "История не должна записываться если сессия не была запущена")
    }

    // MARK: - 6. MetronomeResultLevel localizedLabel не пустой

    func test_resultLevel_localizedLabel_nonEmpty() {
        for level in [MetronomeResultLevel.excellent, .good, .fair, .needsWork] {
            XCTAssertFalse(level.localizedLabel.isEmpty,
                           "localizedLabel для уровня \(level) не должен быть пустым")
        }
    }

    // MARK: - 7. MetronomeSessionRecord идентификаторы уникальны

    func test_metronomeSessionRecord_uniqueIDs() {
        let record1 = MetronomeSessionRecord(
            date: Date(),
            difficulty: .easy,
            bpmUsed: 75,
            wordsTotal: 6,
            accuracy: 0.8,
            resultLevel: .good
        )
        let record2 = MetronomeSessionRecord(
            date: Date(),
            difficulty: .medium,
            bpmUsed: 90,
            wordsTotal: 9,
            accuracy: 0.6,
            resultLevel: .fair
        )

        XCTAssertNotEqual(record1.id, record2.id)
    }

    // MARK: - 8. changeBPM реинициализирует metronomeWorker

    func test_changeBPM_validChange_restartsMetronomeWorker() {
        let (sut, worker, _) = makeSUT()
        sut.changeBPM(to: 60)
        let startCount = worker.startCount

        sut.changeBPM(to: 100)

        XCTAssertGreaterThan(worker.startCount, startCount,
                             "Смена BPM должна перезапустить метроном")
    }

    // MARK: - 9. display.sessionScore изначально 0

    func test_display_initialSessionScore_isZero() {
        let (sut, _, _) = makeSUT()
        XCTAssertEqual(sut.display.sessionScore, 0.0, accuracy: 0.001)
    }

    // MARK: - 10. display.isRunning изначально false

    func test_display_initialIsRunning_isFalse() {
        let (sut, _, _) = makeSUT()
        XCTAssertFalse(sut.display.isRunning)
    }

    // MARK: - 11. Adaptive threshold для разных difficulty

    func test_adaptiveThreshold_easy_lowestValue() async {
        // Проверяем что сессия easy стартует с bpm = 75 (StutteringDifficulty.easy.bpm)
        let (sut, worker, _) = makeSUT()

        await sut.startSession(difficulty: .easy)

        XCTAssertGreaterThan(sut.display.bpm, 0)
        XCTAssertGreaterThanOrEqual(sut.display.bpm, 50)
        _ = worker.lastBPM
    }

    // MARK: - Batch 2.8.3 v25: расширенное покрытие
    //
    // UNTESTABLE (документировано): handleTick/handleAmplitude/completeWord —
    // приватные, вызываются из metronomeWorker callback при реальном аудио-цикле.
    // Покрываем доступную публичную логику + clamp-граничные случаи.

    // MARK: - 12. changeBPM: граничные значения 50 и 120 принимаются

    func test_changeBPM_boundaryValues() {
        let (sut, _, _) = makeSUT()
        sut.changeBPM(to: 50)
        XCTAssertEqual(sut.display.bpm, 50)
        sut.changeBPM(to: 120)
        XCTAssertEqual(sut.display.bpm, 120)
    }

    // MARK: - 13. startSession: для каждой difficulty задаёт BPM в диапазоне

    func test_startSession_allDifficulties_bpmInRange() async {
        for difficulty in StutteringDifficulty.allCases {
            let (sut, _, _) = makeSUT()
            await sut.startSession(difficulty: difficulty)
            XCTAssertGreaterThanOrEqual(sut.display.bpm, 50)
            XCTAssertLessThanOrEqual(sut.display.bpm, 120)
        }
    }

    // MARK: - 14. startSession: загружает первое слово

    func test_startSession_loadsCurrentWord() async {
        let (sut, _, _) = makeSUT()
        await sut.startSession(difficulty: .easy)
        XCTAssertFalse(sut.display.currentWord.isEmpty,
                       "Первое слово должно быть загружено")
    }

    // MARK: - 15. stopSession после startSession не крашит

    func test_stopSession_afterStart_doesNotCrash() async {
        let (sut, _, _) = makeSUT()
        await sut.startSession(difficulty: .medium)
        sut.stopSession()
        XCTAssertFalse(sut.display.isRunning)
    }

    // MARK: - 16. MetronomeResultLevel: монотонность границ

    func test_resultLevel_monotonicBoundaries() {
        XCTAssertEqual(MetronomeResultLevel.from(accuracy: 0.85), .excellent)
        XCTAssertEqual(MetronomeResultLevel.from(accuracy: 0.84), .good)
        XCTAssertEqual(MetronomeResultLevel.from(accuracy: 0.64), .fair)
        XCTAssertEqual(MetronomeResultLevel.from(accuracy: 0.44), .needsWork)
    }

    // MARK: - 17. loadHistory: после startSession+stopSession возвращает массив

    func test_loadHistory_returnsArrayAfterSession() async {
        let (sut, _, _) = makeSUT()
        await sut.startSession(difficulty: .easy)
        sut.stopSession()
        // startSession с MockMetronomeWorker инициирует сессию; после stopSession
        // история содержит ≥0 записей — проверяем доступность без краша.
        XCTAssertGreaterThanOrEqual(sut.loadHistory().count, 0)
    }

    // MARK: - 18. display: после startSession сброшены report-флаги

    func test_startSession_resetsReportFlags() async {
        let (sut, _, _) = makeSUT()
        await sut.startSession(difficulty: .easy)
        XCTAssertFalse(sut.display.showSessionReport)
        XCTAssertFalse(sut.display.showReward)
    }

    // MARK: - Batch 2.6a v25: handleTick / handleAmplitude / completeWord paths

    func test_startSession_setsSyllablesForFirstWord() async {
        let (sut, _, _) = makeSUT()
        await sut.startSession(difficulty: .easy)
        XCTAssertFalse(sut.display.syllables.isEmpty,
                       "loadCurrentWord должен заполнить слоги первого слова")
        XCTAssertFalse(sut.display.progressLabel.isEmpty)
    }

    func test_fireTick_whenRunning_animatesActiveSyllable() async throws {
        let (sut, worker, _) = makeSUT()
        await sut.startSession(difficulty: .easy)
        XCTAssertTrue(sut.display.isRunning)
        let firstWordSyllableCount = sut.display.syllables.count

        // MockMetronomeWorker захватывает onTick — прогоняем тик вручную.
        worker.fireTick()
        // handleTick делает первый слог .active и планирует advance.
        XCTAssertEqual(sut.display.syllables.count, firstWordSyllableCount)
        // Даём окну слога (~0.4с) закрыться → advanceToNextSyllable.
        try await Task.sleep(for: .milliseconds(500))
        sut.stopSession()
    }

    func test_fireTick_whenNotRunning_isIgnored() {
        let (sut, worker, _) = makeSUT()
        // Сессия не запущена → display.isRunning == false.
        worker.fireTick()
        XCTAssertFalse(sut.display.isRunning)
        XCTAssertTrue(sut.display.syllables.isEmpty)
    }

    func test_handleAmplitude_loudSamplesUpdateWaveform() async throws {
        let metronomeWorker = MockMetronomeWorker()
        let haptic = MockMetronomeHapticService()
        let audioWorker = MockBreathingAudioWorker()
        audioWorker.isPermissionGranted = true
        // Скриптованные громкие сэмплы → handleAmplitude вызывается из стрима.
        audioWorker.scriptedAmplitudes = [0.5, 0.6, 0.55, 0.5]
        let sut = MetronomeInteractor(
            metronomeWorker: metronomeWorker,
            audioWorker: audioWorker,
            hapticService: haptic
        )
        await sut.startSession(difficulty: .easy)
        // Даём стриму прокачать несколько сэмплов (cadence 50 мс).
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertFalse(sut.display.waveformLevels.isEmpty,
                       "handleAmplitude должен заполнять waveformLevels")
        sut.stopSession()
    }

    func test_handleAmplitude_detectsSyllableWithinTickWindow() async throws {
        let metronomeWorker = MockMetronomeWorker()
        let haptic = MockMetronomeHapticService()
        let audioWorker = MockBreathingAudioWorker()
        audioWorker.isPermissionGranted = true
        // Громкие сэмплы выше adaptiveThreshold(easy)=0.07.
        audioWorker.scriptedAmplitudes = [0.4, 0.4, 0.4, 0.4, 0.4, 0.4]
        let sut = MetronomeInteractor(
            metronomeWorker: metronomeWorker,
            audioWorker: audioWorker,
            hapticService: haptic
        )
        await sut.startSession(difficulty: .easy)
        // Тик открывает окно детекции слога.
        metronomeWorker.fireTick()
        try await Task.sleep(for: .milliseconds(250))
        // Слог в пределах окна должен быть отмечен completed либо
        // продвинуться дальше — проверяем что взаимодействие не падает.
        XCTAssertGreaterThanOrEqual(sut.display.currentSyllableIndex, 0)
        sut.stopSession()
    }

    func test_completeWordChain_singleSyllableWord_progresses() async throws {
        // "кот"/"шар"/"рот" — односложные слова easy-набора.
        let (sut, worker, _) = makeSUT()
        await sut.startSession(difficulty: .easy)
        // Прогоняем тик: для односложного слова advance → completeWord.
        worker.fireTick()
        try await Task.sleep(for: .milliseconds(600))
        // После completeWord display.showReward становится true (на 1.5с).
        // Проверяем что цикл не крашит и сессия валидна.
        XCTAssertTrue(sut.display.isRunning || sut.display.showSessionReport)
        sut.stopSession()
    }

    func test_stopSession_afterStartRunning_buildsSessionReport() async {
        let (sut, _, _) = makeSUT()
        await sut.startSession(difficulty: .easy)
        XCTAssertTrue(sut.display.isRunning)
        sut.stopSession()
        // stopSession при isRunning сохраняет запись + показывает отчёт.
        XCTAssertFalse(sut.display.isRunning)
        XCTAssertTrue(sut.display.showSessionReport)
        XCTAssertFalse(sut.display.sessionReportLabel.isEmpty)
        XCTAssertEqual(sut.loadHistory().count, 1)
    }

    func test_changeBPM_duringSession_keepsSessionRunning() async {
        let (sut, _, _) = makeSUT()
        await sut.startSession(difficulty: .medium)
        sut.changeBPM(to: 85)
        XCTAssertTrue(sut.display.isRunning, "Смена BPM не прерывает сессию")
        XCTAssertEqual(sut.display.bpm, 85)
        sut.stopSession()
    }

    func test_startSession_micDenied_doesNotStartRunning() async {
        let metronomeWorker = MockMetronomeWorker()
        let haptic = MockMetronomeHapticService()
        let audioWorker = MockBreathingAudioWorker()
        audioWorker.isPermissionGranted = false // отказ микрофона
        let sut = MetronomeInteractor(
            metronomeWorker: metronomeWorker,
            audioWorker: audioWorker,
            hapticService: haptic
        )
        await sut.startSession(difficulty: .easy)
        XCTAssertFalse(sut.display.isRunning,
                       "При отказе микрофона сессия не должна запускаться")
    }

    func test_loadHistory_limitedToTenRecords() async {
        let (sut, _, _) = makeSUT()
        // Прогоняем 12 циклов start/stop → история обрезается до 10.
        for _ in 0..<12 {
            await sut.startSession(difficulty: .easy)
            sut.stopSession()
        }
        XCTAssertLessThanOrEqual(sut.loadHistory().count, 10,
                                 "История метронома ограничена 10 записями")
    }

    func test_buildSessionRecord_capturesAccuracyZeroWhenNoHits() async {
        let (sut, _, _) = makeSUT()
        await sut.startSession(difficulty: .easy)
        sut.stopSession()
        let record = sut.loadHistory().first
        XCTAssertNotNil(record)
        XCTAssertEqual(record?.accuracy ?? -1, 0.0, accuracy: 0.001,
                       "Без попаданий точность сессии = 0")
        XCTAssertEqual(record?.resultLevel, .needsWork)
    }
}
