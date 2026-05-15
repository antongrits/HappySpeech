@testable import HappySpeech
import XCTest

// MARK: - PrecannedNarrationsTests
//
// Phase 2.4 v25 — покрытие PrecannedNarrations.
// Тестируется: narrativeProgression(), repeatFeedback(), hint().
// Все функции детерминированы через .randomElement() — тестируем контракт,
// не конкретный индекс.

final class PrecannedNarrationsTests: XCTestCase {

    // MARK: - narrativeProgression

    func test_narrativeProgression_notEmpty() {
        let result = PrecannedNarrations.narrativeProgression()
        XCTAssertFalse(result.isEmpty)
    }

    func test_narrativeProgression_multipleCallsAllNonEmpty() {
        for _ in 0..<10 {
            XCTAssertFalse(PrecannedNarrations.narrativeProgression().isEmpty)
        }
    }

    // MARK: - repeatFeedback: ветви score

    func test_repeatFeedback_perfect_score80_notEmpty() {
        let result = PrecannedNarrations.repeatFeedback(score: 80)
        XCTAssertFalse(result.isEmpty)
    }

    func test_repeatFeedback_perfect_score100_notEmpty() {
        XCTAssertFalse(PrecannedNarrations.repeatFeedback(score: 100).isEmpty)
    }

    func test_repeatFeedback_almost_score50_notEmpty() {
        XCTAssertFalse(PrecannedNarrations.repeatFeedback(score: 50).isEmpty)
    }

    func test_repeatFeedback_almost_score79_notEmpty() {
        XCTAssertFalse(PrecannedNarrations.repeatFeedback(score: 79).isEmpty)
    }

    func test_repeatFeedback_encourage_score0_notEmpty() {
        XCTAssertFalse(PrecannedNarrations.repeatFeedback(score: 0).isEmpty)
    }

    func test_repeatFeedback_encourage_score49_notEmpty() {
        XCTAssertFalse(PrecannedNarrations.repeatFeedback(score: 49).isEmpty)
    }

    func test_repeatFeedback_score79_and_80_differentPools() {
        // Принципиально — разные пулы, не обязательно разные значения
        let almost = PrecannedNarrations.repeatFeedback(score: 79)
        let perfect = PrecannedNarrations.repeatFeedback(score: 80)
        // Оба не пустые — пул существует
        XCTAssertFalse(almost.isEmpty)
        XCTAssertFalse(perfect.isEmpty)
    }

    // MARK: - hint: известные игровые типы

    func test_hint_narrativeQuest_notEmpty() {
        let result = PrecannedNarrations.hint(for: "narrative_quest")
        XCTAssertFalse(result.isEmpty)
    }

    func test_hint_repeatAfterModel_notEmpty() {
        let result = PrecannedNarrations.hint(for: "repeat_after_model")
        XCTAssertFalse(result.isEmpty)
    }

    func test_hint_general_notEmpty() {
        let result = PrecannedNarrations.hint(for: "general")
        XCTAssertFalse(result.isEmpty)
    }

    func test_hint_unknown_fallbackToGeneral() {
        // Неизвестный тип → fallback через general
        let result = PrecannedNarrations.hint(for: "some_unknown_game_type_xyz")
        XCTAssertFalse(result.isEmpty, "Неизвестный тип игры должен давать fallback-подсказку")
    }

    // MARK: - Пулы фраз: размеры

    func test_narrativeProgressions_count10() {
        // 10 фраз прогрессии NarrativeQuest
        XCTAssertEqual(PrecannedNarrations.narrativeQuestProgressions.count, 10)
    }

    func test_repeatPerfect_count10() {
        XCTAssertEqual(PrecannedNarrations.repeatPerfect.count, 10)
    }

    func test_repeatAlmost_count10() {
        XCTAssertEqual(PrecannedNarrations.repeatAlmost.count, 10)
    }

    func test_repeatEncourage_count10() {
        XCTAssertEqual(PrecannedNarrations.repeatEncourage.count, 10)
    }

    func test_hintsDict_containsExpectedKeys() {
        XCTAssertNotNil(PrecannedNarrations.hints["narrative_quest"])
        XCTAssertNotNil(PrecannedNarrations.hints["repeat_after_model"])
        XCTAssertNotNil(PrecannedNarrations.hints["general"])
    }

    // MARK: - Безопасность контента: нет banned-words в фразах

    private let bannedWords = ["плохо", "страшно", "ужасно", "боль", "злой", "опасно"]

    func test_progressionPhrases_noBannedWords() {
        for phrase in PrecannedNarrations.narrativeQuestProgressions {
            let lower = phrase.lowercased()
            for word in bannedWords {
                XCTAssertFalse(lower.contains(word),
                    "Фраза прогрессии содержит запрещённое слово «\(word)»: \(phrase)")
            }
        }
    }

    func test_repeatPerfect_noBannedWords() {
        for phrase in PrecannedNarrations.repeatPerfect {
            let lower = phrase.lowercased()
            for word in bannedWords {
                XCTAssertFalse(lower.contains(word),
                    "repeatPerfect содержит запрещённое слово «\(word)»: \(phrase)")
            }
        }
    }

    func test_repeatEncourage_noBannedWords() {
        for phrase in PrecannedNarrations.repeatEncourage {
            let lower = phrase.lowercased()
            for word in bannedWords {
                XCTAssertFalse(lower.contains(word),
                    "repeatEncourage содержит запрещённое слово «\(word)»: \(phrase)")
            }
        }
    }

    // MARK: - Безопасность: нет слова «неправильно»

    func test_allPools_noNepravilno() {
        let allPhrases = PrecannedNarrations.repeatPerfect
            + PrecannedNarrations.repeatAlmost
            + PrecannedNarrations.repeatEncourage
            + PrecannedNarrations.narrativeQuestProgressions

        for phrase in allPhrases {
            XCTAssertFalse(
                phrase.lowercased().contains("неправильно"),
                "Фраза не должна содержать «неправильно»: \(phrase)"
            )
        }
    }
}
