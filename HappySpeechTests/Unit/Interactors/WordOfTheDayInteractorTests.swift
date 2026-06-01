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

    // MARK: - RecordingPhase equality

    func test_recordingPhase_equatable() {
        XCTAssertEqual(WordOfTheDayModels.RecordingPhase.scored(3), .scored(3))
        XCTAssertNotEqual(WordOfTheDayModels.RecordingPhase.scored(2), .scored(3))
        XCTAssertNotEqual(WordOfTheDayModels.RecordingPhase.idle, .recording)
    }
}
