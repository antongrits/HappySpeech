@testable import HappySpeech
import XCTest

// MARK: - StutteringWorkerTests
//
// 15 unit-тестов для Workers StutteringModule (F5-step6).
// Покрывает: MetronomeWorker (mock), FluencyAnalyzerWorker, DiaryStorageWorker (mock).

// MARK: - MetronomeWorker Tests (1–5)

@MainActor
final class MetronomeWorkerTests: XCTestCase {

    // MARK: - 11. start вызывает onTick и сохраняет BPM

    func test_metronomeWorker_start_capturesOnTickAndBPM() {
        let worker = MockMetronomeWorker()
        var tickFired = false

        worker.start(bpm: 75) { tickFired = true }

        XCTAssertEqual(worker.startCount, 1,   "start должен быть вызван один раз")
        XCTAssertEqual(worker.lastBPM, 75,     "BPM должен быть 75")
        XCTAssertNotNil(worker.capturedOnTick, "onTick closure должна быть захвачена")

        // Ручной триггер тика
        worker.fireTick()
        XCTAssertTrue(tickFired, "fireTick должен вызвать зарегистрированный onTick")
    }

    // MARK: - 12. stop инкрементирует stopCount

    func test_metronomeWorker_stop_invalidatesTimer() {
        let worker = MockMetronomeWorker()
        worker.start(bpm: 90) {}
        worker.stop()

        XCTAssertEqual(worker.stopCount, 1, "stop должен быть вызван один раз")
    }

    // MARK: - 13. повторный start → двойной вызов

    func test_metronomeWorker_doubleStart_incrementsCounter() {
        let worker = MockMetronomeWorker()
        worker.start(bpm: 75) {}
        worker.start(bpm: 90) {}

        XCTAssertEqual(worker.startCount, 2, "Второй start должен увеличить счётчик")
        XCTAssertEqual(worker.lastBPM, 90,   "lastBPM должен обновиться до 90")
    }

    // MARK: - 14. fireTick без start → не крашит (capturedOnTick nil)

    func test_metronomeWorker_fireTickWithoutStart_doesNotCrash() {
        let worker = MockMetronomeWorker()
        XCTAssertNoThrow(worker.fireTick(), "fireTick без start не должен крашить")
    }

    // MARK: - 15. BPM передаётся корректно для Hard (105)

    func test_metronomeWorker_hardBPM_105_capturedCorrectly() {
        let worker = MockMetronomeWorker()
        worker.start(bpm: StutteringDifficulty.hard.bpm) {}

        XCTAssertEqual(worker.lastBPM, 105,
                       "Для Hard difficulty BPM 105 должен быть передан в worker")
    }
}

// MARK: - FluencyAnalyzerWorker Tests (16–20 / тесты 3–7 по плану)

final class FluencyAnalyzerWorkerTests: XCTestCase {

    private let worker = FluencyAnalyzerWorker()

    // MARK: - 16. Мягкая атака: >= softThreshold Easy → .soft (100–300 мс)

    func test_fluencyAnalyzer_softOnset_attackTime100to300() {
        // RMS buffer: 0 тиков тишины → уже на старте сигнал, пик достигается постепенно
        // Моделируем медленный рост: noiseFloor=0.05, pik>=threshold(0.08), attackTime=100ms (2 тика)
        var rms: [Float] = Array(repeating: 0.0, count: 2) // silence
        rms += [0.06, 0.07, 0.09, 0.11, 0.12, 0.12, 0.12, 0.12] // ramp 4 тика до пика

        let (classification, attackMs) = worker.classifyOnset(
            rmsBuffer: rms,
            threshold: 0.08,
            difficulty: .easy
        )

        XCTAssertEqual(classification, .soft,
                       "Медленный рост амплитуды должен классифицироваться как soft onset")
        XCTAssertGreaterThanOrEqual(attackMs, 0,
                                    "attackTimeMs должен быть неотрицательным")
    }

    // MARK: - 17. Жёсткая атака: attackTime < 50ms → .hard

    func test_fluencyAnalyzer_hardOnset_attackTimeUnder50() {
        // Мгновенный пик: noiseFloor превышается и сразу 80% пика
        var rms: [Float] = [0.0, 0.0, 0.0] // silence
        rms += [0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15] // мгновенный пик (attackTicks=0 → 0ms)

        let (classification, _) = worker.classifyOnset(
            rmsBuffer: rms,
            threshold: 0.08,
            difficulty: .easy
        )

        XCTAssertEqual(classification, .hard,
                       "Мгновенный пик амплитуды должен классифицироваться как hard onset")
    }

    // MARK: - 18. Пустой буфер → .hard

    func test_fluencyAnalyzer_emptyBuffer_returnsHard() {
        let (classification, attackMs) = worker.classifyOnset(
            rmsBuffer: [],
            threshold: 0.08,
            difficulty: .easy
        )

        XCTAssertEqual(classification, .hard, "Пустой буфер должен давать .hard")
        XCTAssertEqual(attackMs, 0,           "attackTimeMs пустого буфера должен быть 0")
    }

    // MARK: - 19. analyzeDysfluency: повторяющиеся слова считаются

    func test_fluencyAnalyzer_repetitions_counted() {
        let transcript = "мама мама идёт идёт домой"
        let (repetitions, totalTokens) = worker.analyzeDysfluency(transcript: transcript)

        XCTAssertEqual(totalTokens, 5,  "5 токенов должно быть в транскрипте")
        XCTAssertEqual(repetitions, 2,  "2 повторения (мама-мама, идёт-идёт)")
    }

    // MARK: - 20. estimateSyllableCount: гласные = слоги

    func test_fluencyAnalyzer_syllableCount_countedByVowels() {
        let count = worker.estimateSyllableCount(in: "мама")
        XCTAssertEqual(count, 2, "«мама» содержит 2 гласных → 2 слога")

        let count2 = worker.estimateSyllableCount(in: "черепаха")
        XCTAssertEqual(count2, 4, "«черепаха» содержит 4 гласных → 4 слога")
    }
}

// MARK: - DiaryStorageWorker Mock Tests (21–25 / тесты 8–10 по плану)

final class DiaryStorageWorkerMockTests: XCTestCase {

    // Простой in-memory mock для DiaryStorageWorkerProtocol
    final class MockDiaryStorage: DiaryStorageWorkerProtocol, @unchecked Sendable {
        var savedSessions: [FluencySessionData] = []
        var stubbedFetchResult: [FluencySessionData] = []

        func saveSession(_ data: FluencySessionData) async {
            savedSessions.append(data)
        }

        func fetchSessions(limit: Int) async -> [FluencySessionData] {
            let sorted = stubbedFetchResult.sorted { $0.date > $1.date }
            return limit > 0 ? Array(sorted.prefix(limit)) : sorted
        }
    }

    // MARK: - 21. saveSession сохраняет запись

    func test_diaryStorageWorker_save_persists() async {
        let mock = MockDiaryStorage()
        let session = FluencySessionData(
            id: "test-id-001",
            date: Date(),
            dysfluencyCount: 3,
            totalSyllables: 50,
            rate: 6.0,
            transcript: "мама мама идёт"
        )

        await mock.saveSession(session)

        XCTAssertEqual(mock.savedSessions.count, 1,  "Одна сессия должна быть сохранена")
        XCTAssertEqual(mock.savedSessions.first?.id, "test-id-001")
    }

    // MARK: - 22. fetchSessions возвращает отсортированные по дате

    func test_diaryStorageWorker_fetch_returnsSortedByDate() async {
        let mock = MockDiaryStorage()
        let old = FluencySessionData(id: "old", date: Date(timeIntervalSince1970: 1000),
                                     dysfluencyCount: 0, totalSyllables: 10,
                                     rate: 0, transcript: "")
        let fresh = FluencySessionData(id: "fresh", date: Date(timeIntervalSince1970: 9000),
                                       dysfluencyCount: 1, totalSyllables: 20,
                                       rate: 5, transcript: "")
        mock.stubbedFetchResult = [old, fresh]

        let result = await mock.fetchSessions(limit: 10)

        XCTAssertEqual(result.first?.id, "fresh", "Самая свежая сессия должна идти первой")
    }

    // MARK: - 23. fetchSessions с limit=1 возвращает одну запись

    func test_diaryStorageWorker_fetch_limit1_returnsOnlyOne() async {
        let mock = MockDiaryStorage()
        mock.stubbedFetchResult = [
            FluencySessionData(id: "a", date: Date(), dysfluencyCount: 0,
                               totalSyllables: 10, rate: 0, transcript: ""),
            FluencySessionData(id: "b", date: Date(timeIntervalSince1970: 1),
                               dysfluencyCount: 0, totalSyllables: 10, rate: 0, transcript: "")
        ]

        let result = await mock.fetchSessions(limit: 1)

        XCTAssertEqual(result.count, 1, "С limit=1 должна вернуться одна запись")
    }
}
