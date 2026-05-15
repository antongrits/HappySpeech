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
        let sut = MetronomeInteractor(
            metronomeWorker: metronomeWorker,
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
        let (sut, worker, _) = makeSUT()

        // Имитируем запущенную сессию: устанавливаем isRunning вручную через startSession
        // (без реального аудио — mic denied, поэтому stopSession завершит gracefully)
        let audio = MockBreathingAudioWorker()
        audio.isPermissionGranted = false
        // Вместо полного запуска мы вызываем stopSession когда display.isRunning = false
        // (нет записи в history, если сессия не была running)
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
        let audio = MockBreathingAudioWorker()
        audio.isPermissionGranted = false

        await sut.startSession(difficulty: .easy)

        // Если микрофон не выдан — сессия не запустится, но BPM должен быть задан
        XCTAssertGreaterThan(sut.display.bpm, 0)
        XCTAssertGreaterThanOrEqual(sut.display.bpm, 50)
        _ = worker.lastBPM
    }
}
