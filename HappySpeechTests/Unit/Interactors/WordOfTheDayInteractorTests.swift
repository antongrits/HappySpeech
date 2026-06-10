@testable import HappySpeech
import XCTest

// MARK: - WordOfTheDayInteractorTests
//
// WordOfTheDayInteractor is a thin VIP MVP variant (@Observable). It exposes a
// deterministic word-of-the-day card (rotated by day-of-year) and a real
// recording flow. Without injected audio/scorer services (as in these tests)
// it must NOT fabricate stars — it lands on a neutral `.tryAgain`. Tests cover
// the rotator, the recording phase transitions and reset.

@MainActor
final class WordOfTheDayInteractorTests: XCTestCase {

    /// Скорер с управляемым исходом — для проверки FSRS-фида (F1-016).
    private final class StubScorer: PronunciationScorerService, @unchecked Sendable {
        let isModelLoaded = true
        let fixedValue: Double
        init(value: Double) { self.fixedValue = value }
        func score(audioURL: URL, targetSound: String) async throws -> PronunciationScore {
            PronunciationScore(rawValue: fixedValue)
        }
        func loadModel() async throws {}
    }

    private func makeSUT(childId: String = "child-1") -> WordOfTheDayInteractor {
        WordOfTheDayInteractor(childId: childId)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    // MARK: - Initial state

    func test_init_storesChildId() {
        let sut = makeSUT(childId: "kid-21")
        XCTAssertEqual(sut.childId, "kid-21")
    }

    func test_init_phaseIsIdle() {
        let sut = makeSUT()
        XCTAssertEqual(sut.phase, .idle)
    }

    func test_init_cardIsTodaysWord() {
        let sut = makeSUT()
        XCTAssertEqual(sut.card, WordOfTheDayModels.wordForToday())
    }

    func test_init_cardFieldsNonEmpty() {
        let sut = makeSUT()
        XCTAssertFalse(sut.card.word.isEmpty)
        XCTAssertFalse(sut.card.targetSound.isEmpty)
        XCTAssertFalse(sut.card.hint.isEmpty)
        XCTAssertFalse(sut.card.illustrationSymbol.isEmpty)
    }

    // MARK: - wordForToday rotator

    func test_wordForToday_isDeterministicForSameDate() {
        let d = date(2026, 5, 30)
        XCTAssertEqual(WordOfTheDayModels.wordForToday(now: d), WordOfTheDayModels.wordForToday(now: d))
    }

    func test_wordForToday_jan1_isFirstAfterRotation() {
        // ordinality(day=1) % 7 == 1 → pool index 1 ("лиса").
        let card = WordOfTheDayModels.wordForToday(now: date(2026, 1, 1))
        XCTAssertEqual(card.word, "лиса")
    }

    func test_wordForToday_consecutiveDaysCycleThroughPool() {
        var words: [String] = []
        for day in 1...7 {
            words.append(WordOfTheDayModels.wordForToday(now: date(2026, 1, day)).word)
        }
        // Seven consecutive days hit the 7-card pool in seven distinct slots.
        XCTAssertEqual(Set(words).count, 7)
    }

    func test_wordForToday_alwaysFromKnownPool() {
        let knownWords: Set<String> = ["сова", "лиса", "роза", "шар", "жук", "часы", "щётка"]
        for day in 1...20 {
            let card = WordOfTheDayModels.wordForToday(now: date(2026, 3, day))
            XCTAssertTrue(knownWords.contains(card.word), "Unexpected word: \(card.word)")
        }
    }

    // MARK: - startRecording

    func test_startRecording_immediatelyEntersRecording() {
        let sut = makeSUT()
        sut.startRecording()
        XCTAssertEqual(sut.phase, .recording)
    }

    func test_startRecording_withoutServices_landsOnTryAgain_noFabricatedStars() async {
        // Без инжектированных audio/scorer сервисов интерактор НЕ должен
        // фабриковать звёзды — целостность данных произношения требует
        // нейтрального исхода `.tryAgain` при отсутствии реального ввода.
        let sut = makeSUT()
        sut.startRecording()
        try? await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(sut.phase, .tryAgain)
        if case .scored = sut.phase {
            XCTFail("Звёзды не должны начисляться без реального ввода")
        }
    }

    // MARK: - reset

    func test_reset_returnsToIdle() {
        let sut = makeSUT()
        sut.startRecording()
        sut.reset()
        XCTAssertEqual(sut.phase, .idle)
    }

    // MARK: - F1-016 FSRS feed

    func test_highScore_feedsScheduler_withCorrectTrue() async {
        // ★3 (0.9 ≥ 0.85) — реальный исход скорера → recordItemOutcome(correct: true).
        let planner = MockAdaptivePlannerService()
        let sut = WordOfTheDayInteractor(
            childId: "kid-fsrs",
            audioService: MockAudioService(),
            scorer: StubScorer(value: 0.9),
            adaptivePlanner: planner
        )
        let card = sut.card

        sut.startRecording()
        try? await Task.sleep(for: .milliseconds(2400))

        XCTAssertEqual(planner.recordedItemOutcomes.count, 1)
        let recorded = planner.recordedItemOutcomes.first
        XCTAssertEqual(recorded?.childId, "kid-fsrs")
        XCTAssertEqual(recorded?.itemId, card.word)
        XCTAssertEqual(recorded?.sound, card.targetSound)
        XCTAssertEqual(recorded?.correct, true)
    }

    func test_lowScore_feedsScheduler_withCorrectFalse() async {
        // ★1 (0.5 → 1 звезда < порога ★2) → recordItemOutcome(correct: false):
        // слово вернётся на повтор завтра, без наказания.
        let planner = MockAdaptivePlannerService()
        let sut = WordOfTheDayInteractor(
            childId: "kid-low",
            audioService: MockAudioService(),
            scorer: StubScorer(value: 0.5),
            adaptivePlanner: planner
        )

        sut.startRecording()
        try? await Task.sleep(for: .milliseconds(2400))

        XCTAssertEqual(planner.recordedItemOutcomes.count, 1)
        XCTAssertEqual(planner.recordedItemOutcomes.first?.correct, false)
    }

    func test_withoutPlanner_doesNotCrash_andStillScores() async {
        // Планировщик опционален: при nil FSRS не фиксируется, но скоринг работает.
        let sut = WordOfTheDayInteractor(
            childId: "kid-noplanner",
            audioService: MockAudioService(),
            scorer: StubScorer(value: 0.9)
        )
        sut.startRecording()
        try? await Task.sleep(for: .milliseconds(2400))
        if case .scored(let stars) = sut.phase {
            XCTAssertEqual(stars, 3)
        } else {
            XCTFail("Ожидался .scored при валидном вводе")
        }
    }

    // MARK: - RecordingPhase equality

    func test_recordingPhase_equatable() {
        XCTAssertEqual(WordOfTheDayModels.RecordingPhase.scored(3), .scored(3))
        XCTAssertNotEqual(WordOfTheDayModels.RecordingPhase.scored(2), .scored(3))
        XCTAssertNotEqual(WordOfTheDayModels.RecordingPhase.idle, .recording)
    }
}
