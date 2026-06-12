@testable import HappySpeech
import XCTest

// MARK: - SoundTrafficLightLevelTests
//
// v29 Фаза 8, Функция 5 «Звуковой светофор» — прогрессия дифференциации.
//
// Покрывает модель уровней (`DifferentiationLevel`, `DifferentiationPair`,
// `TrafficLightPhrase`, `TrafficLightText`), критерии перехода
// (`SoundTrafficLightCriteria`) и непересекающийся подсчёт both-слов в текстах
// загруженного пака `pack_differentiation.json`.

final class DifferentiationLevelTests: XCTestCase {

    func test_levelOrder_isSyllableWordPhraseText() {
        XCTAssertEqual(
            DifferentiationLevel.allCases,
            [.syllable, .word, .phrase, .text]
        )
    }

    func test_next_followsLadder() {
        XCTAssertEqual(DifferentiationLevel.syllable.next, .word)
        XCTAssertEqual(DifferentiationLevel.word.next, .phrase)
        XCTAssertEqual(DifferentiationLevel.phrase.next, .text)
        XCTAssertNil(DifferentiationLevel.text.next)
    }

    func test_previous_followsLadder() {
        XCTAssertNil(DifferentiationLevel.syllable.previous)
        XCTAssertEqual(DifferentiationLevel.word.previous, .syllable)
        XCTAssertEqual(DifferentiationLevel.text.previous, .phrase)
    }
}

// MARK: - DifferentiationPair availableLevels

final class DifferentiationPairLevelTests: XCTestCase {

    func test_fullPair_hasAllLevels() {
        let pair = DifferentiationPair(
            id: "x", soundA: "С", soundB: "Ш",
            syllablesA: ["са"], syllablesB: ["ша"],
            wordsA: ["сок"], wordsB: ["шар"],
            phrases: [.init(id: "p0", text: "Сок и шар.", dominant: .both, wordsA: ["Сок"], wordsB: ["шар"])],
            texts: [.init(id: "t0", title: "T", lines: ["Сок."], countA: 1, countB: 0, source: "test")]
        )
        XCTAssertEqual(pair.availableLevels, [.syllable, .word, .phrase, .text])
    }

    func test_legacyWordOnlyPair_exposesOnlyWordLevel() {
        // Обратная совместимость: старый пак без слогов/фраз/текстов.
        let pair = DifferentiationPair(
            id: "legacy", soundA: "П", soundB: "Б",
            wordsA: ["парк"], wordsB: ["бант"]
        )
        XCTAssertEqual(pair.availableLevels, [.word])
    }
}

// MARK: - SoundTrafficLightCriteria

final class SoundTrafficLightCriteriaTests: XCTestCase {

    private let allLevels: [DifferentiationLevel] = [.syllable, .word, .phrase, .text]

    func test_passThreshold_phraseIs85_othersAre90() {
        XCTAssertEqual(SoundTrafficLightCriteria.passThreshold(for: .syllable), 0.90, accuracy: 0.0001)
        XCTAssertEqual(SoundTrafficLightCriteria.passThreshold(for: .word), 0.90, accuracy: 0.0001)
        XCTAssertEqual(SoundTrafficLightCriteria.passThreshold(for: .phrase), 0.85, accuracy: 0.0001)
        XCTAssertEqual(SoundTrafficLightCriteria.passThreshold(for: .text), 0.90, accuracy: 0.0001)
    }

    func test_requiredSessions_textNeeds3_othersNeed2() {
        XCTAssertEqual(SoundTrafficLightCriteria.requiredSessions(toAdvanceFrom: .syllable), 2)
        XCTAssertEqual(SoundTrafficLightCriteria.requiredSessions(toAdvanceFrom: .word), 2)
        XCTAssertEqual(SoundTrafficLightCriteria.requiredSessions(toAdvanceFrom: .phrase), 2)
        XCTAssertEqual(SoundTrafficLightCriteria.requiredSessions(toAdvanceFrom: .text), 3)
    }

    func test_advance_belowThreshold_resetsCounter_keepsLevel() {
        let current = DifferentiationProgress(level: .syllable, consecutiveQualifyingSessions: 1)
        let result = SoundTrafficLightCriteria.advance(current, accuracy: 0.5, availableLevels: allLevels)
        XCTAssertEqual(result.level, .syllable, "Уровень не откатывается без штрафа")
        XCTAssertEqual(result.consecutiveQualifyingSessions, 0, "Серия успешных сбрасывается")
    }

    func test_advance_oneQualifyingSession_incrementsButStays() {
        let current = DifferentiationProgress(level: .syllable, consecutiveQualifyingSessions: 0)
        let result = SoundTrafficLightCriteria.advance(current, accuracy: 0.95, availableLevels: allLevels)
        XCTAssertEqual(result.level, .syllable, "Одной сессии мало для перехода (нужно 2)")
        XCTAssertEqual(result.consecutiveQualifyingSessions, 1)
    }

    func test_advance_twoQualifyingSessions_promotesToNextLevel() {
        var progress = DifferentiationProgress(level: .syllable)
        progress = SoundTrafficLightCriteria.advance(progress, accuracy: 0.95, availableLevels: allLevels)
        progress = SoundTrafficLightCriteria.advance(progress, accuracy: 1.0, availableLevels: allLevels)
        XCTAssertEqual(progress.level, .word, "После 2 успешных сессий слог → слово")
        XCTAssertEqual(progress.consecutiveQualifyingSessions, 0, "Счётчик сброшен после перехода")
    }

    func test_advance_phraseUses85Threshold() {
        var progress = DifferentiationProgress(level: .phrase)
        // 0.87 проходит порог фразы (0.85), но НЕ прошёл бы порог слова (0.90).
        progress = SoundTrafficLightCriteria.advance(progress, accuracy: 0.87, availableLevels: allLevels)
        XCTAssertEqual(progress.consecutiveQualifyingSessions, 1, "0.87 ≥ 0.85 — сессия квалифицирующая")
    }

    func test_advance_textThreeSessions_completesPair() {
        var progress = DifferentiationProgress(level: .text)
        for _ in 0 ..< 3 {
            progress = SoundTrafficLightCriteria.advance(progress, accuracy: 1.0, availableLevels: allLevels)
        }
        XCTAssertTrue(progress.isPairCompleted, "90% × 3 сессии на тексте завершают пару")
        XCTAssertEqual(progress.level, .text, "Текст остаётся последним уровнем")
    }

    func test_resolveStartLevel_legacyPair_fallsBackToWord() {
        // Сохранён уровень слог, но у пары нет слогов → стартуем со слова.
        let resolved = SoundTrafficLightCriteria.resolveStartLevel(
            stored: .syllable,
            availableLevels: [.word]
        )
        XCTAssertEqual(resolved, .word)
    }

    func test_resolveStartLevel_availableStored_isPreserved() {
        let resolved = SoundTrafficLightCriteria.resolveStartLevel(
            stored: .phrase,
            availableLevels: allLevels
        )
        XCTAssertEqual(resolved, .phrase)
    }
}

// MARK: - Pack content / both-word counting

final class SoundTrafficLightContentTests: XCTestCase {

    private func pair(_ id: String) -> DifferentiationPair? {
        SoundTrafficLightCorpus.pair(forId: id)
    }

    func test_pack_loadsNewPairLJ() {
        let lj = pair("pair-l-j")
        XCTAssertNotNil(lj, "Новая пара Л–Й должна быть в загруженном паке")
        XCTAssertEqual(lj?.soundA, "Л")
        XCTAssertEqual(lj?.soundB, "Й")
        XCTAssertGreaterThanOrEqual(lj?.wordsA.count ?? 0, 12)
        XCTAssertGreaterThanOrEqual(lj?.wordsB.count ?? 0, 12)
    }

    func test_pack_eightSpecPairs_haveSyllablesPhrasesTexts() {
        let specIds = ["pair-s-sh", "pair-z-zh", "pair-r-l", "pair-s-z",
                       "pair-sh-zh", "pair-c-ch", "pair-ch-shch", "pair-l-j"]
        for id in specIds {
            guard let pair = pair(id) else {
                return XCTFail("Пара \(id) отсутствует в паке")
            }
            XCTAssertEqual(pair.syllablesA.count, 6, "\(id): 6 слогов A")
            XCTAssertEqual(pair.syllablesB.count, 6, "\(id): 6 слогов B")
            XCTAssertEqual(pair.phrases.count, 8, "\(id): 8 фраз")
            XCTAssertEqual(pair.texts.count, 2, "\(id): 2 текста")
            XCTAssertEqual(pair.availableLevels, [.syllable, .word, .phrase, .text])
        }
    }

    func test_pack_totalContentMatchesSpec() {
        var syllables = 0
        var phrases = 0
        var texts = 0
        for pair in SoundTrafficLightCorpus.pairs {
            syllables += pair.syllablesA.count + pair.syllablesB.count
            phrases += pair.phrases.count
            texts += pair.texts.count
        }
        XCTAssertEqual(syllables, 96, "Спека: 96 слогов")
        XCTAssertEqual(phrases, 64, "Спека: 64 фразы")
        XCTAssertEqual(texts, 16, "Спека: 16 текстов")
    }

    func test_phrase_markedWordsAreSubstringsOfPhrase() {
        for pair in SoundTrafficLightCorpus.pairs {
            for phrase in pair.phrases {
                for word in phrase.wordsA + phrase.wordsB {
                    XCTAssertTrue(
                        phrase.text.lowercased().contains(word.lowercased()),
                        "Слово «\(word)» помечено, но отсутствует во фразе «\(phrase.text)»"
                    )
                }
            }
        }
    }

    func test_text_countsAreNonOverlapping_andPositive() {
        // Правило подсчёта спеки: countA + countB — это число помеченных слов
        // (both-слова отнесены к доминанте). Суммы не пересекаются и > 0.
        for pair in SoundTrafficLightCorpus.pairs where !pair.texts.isEmpty {
            for text in pair.texts {
                XCTAssertGreaterThan(text.countA + text.countB, 0,
                                     "Текст «\(text.title)» должен иметь помеченные слова")
                XCTAssertGreaterThanOrEqual(text.countA, 0)
                XCTAssertGreaterThanOrEqual(text.countB, 0)
                XCTAssertFalse(text.lines.isEmpty, "Текст «\(text.title)» без строк")
            }
        }
    }

    func test_text_countsDoNotExceedTotalWords() {
        // Непересекающийся подсчёт: сумма помеченных слов не больше всех слов текста.
        for pair in SoundTrafficLightCorpus.pairs where !pair.texts.isEmpty {
            for text in pair.texts {
                let totalWords = text.lines
                    .flatMap { $0.split(separator: " ") }
                    .count
                XCTAssertLessThanOrEqual(
                    text.countA + text.countB, totalWords,
                    "Текст «\(text.title)»: помеченных слов больше, чем слов в тексте"
                )
            }
        }
    }

    func test_phraseDominant_decodedFromJSON() {
        // Все фразы спеки помечены доминантой "both".
        for pair in SoundTrafficLightCorpus.pairs {
            for phrase in pair.phrases {
                XCTAssertEqual(phrase.dominant, .both,
                               "Фраза «\(phrase.text)» ожидается с доминантой both")
            }
        }
    }
}
