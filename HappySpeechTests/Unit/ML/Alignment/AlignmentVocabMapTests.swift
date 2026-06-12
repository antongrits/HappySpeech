import XCTest
@testable import HappySpeech

// MARK: - AlignmentVocabMapTests

/// Тесты полноты и корректности IPA↔vocab маппинга.
///
/// Ключевая задача этих тестов — гарантировать, что КАЖДЫЙ IPA-символ из
/// ``RussianPhonemeInventory`` (49 фонем) либо маппируется в vocab-id,
/// либо явно помечен как неподдерживаемый.
final class AlignmentVocabMapTests: XCTestCase {

    // MARK: - Тест 30: Полное покрытие RussianPhonemeInventory

    func test_fullCoverage_noUncoveredIPAs() {
        let uncovered = AlignmentVocabMap.uncoveredIPAs()
        XCTAssertTrue(
            uncovered.isEmpty,
            "Следующие IPA из RussianPhonemeInventory не покрыты маппингом: \(uncovered)"
        )
    }

    // MARK: - Тест 31: Базовые согласные маппятся корректно

    func test_basicConsonants_correctVocabIds() {
        let expected: [(String, String)] = [
            ("r",  "р"),
            ("l",  "л"),
            ("s",  "с"),
            ("z",  "з"),
            ("k",  "к"),
            ("g",  "г"),
            ("x",  "х"),
            ("ʂ",  "ш"),
            ("ʐ",  "ж"),
            ("ɕː", "щ"),
            ("tɕ", "ч"),
            ("ts", "ц"),
            ("j",  "й"),
            ("m",  "м"),
            ("n",  "н"),
        ]
        for (ipa, expectedCyrillic) in expected {
            guard let vocabId = AlignmentVocabMap.vocabId(for: ipa) else {
                XCTFail("IPA '\(ipa)' не маппируется в vocab-id")
                continue
            }
            let symbol = Wav2Vec2Vocabulary.symbol(at: vocabId)
            XCTAssertEqual(symbol, expectedCyrillic,
                "IPA '\(ipa)' → vocab[\(vocabId)] = '\(symbol ?? "nil")', ожидалось '\(expectedCyrillic)'")
        }
    }

    // MARK: - Тест 32: Мягкие пары маппятся в базовую кириллицу

    func test_palatalizedConsonants_mapToBaseForm() {
        let pairs: [(String, String)] = [
            ("rʲ", "р"),
            ("lʲ", "л"),
            ("sʲ", "с"),
            ("zʲ", "з"),
            ("kʲ", "к"),
            ("gʲ", "г"),
            ("tʲ", "т"),
            ("dʲ", "д"),
            ("nʲ", "н"),
            ("mʲ", "м"),
        ]
        for (ipa, expectedCyrillic) in pairs {
            guard let vocabId = AlignmentVocabMap.vocabId(for: ipa) else {
                XCTFail("Мягкая пара '\(ipa)' не маппируется в vocab-id")
                continue
            }
            let symbol = Wav2Vec2Vocabulary.symbol(at: vocabId)
            XCTAssertEqual(symbol, expectedCyrillic,
                "Мягкая пара '\(ipa)' → '\(symbol ?? "nil")', ожидалось '\(expectedCyrillic)'")
        }
    }

    // MARK: - Тест 33: Ударные гласные маппятся корректно

    func test_stressedVowels_correctMapping() {
        let expected: [(String, String)] = [
            ("a", "а"),
            ("e", "е"),
            ("i", "и"),
            ("o", "о"),
            ("u", "у"),
            ("ɨ", "ы"),
        ]
        for (ipa, expectedCyrillic) in expected {
            guard let vocabId = AlignmentVocabMap.vocabId(for: ipa) else {
                XCTFail("Гласная '\(ipa)' не маппируется")
                continue
            }
            let symbol = Wav2Vec2Vocabulary.symbol(at: vocabId)
            XCTAssertEqual(symbol, expectedCyrillic,
                "Гласная '\(ipa)' → '\(symbol ?? "nil")', ожидалось '\(expectedCyrillic)'")
        }
    }

    // MARK: - Тест 34: Редуцированные гласные маппятся в ближайший символ

    func test_reducedVowels_haveMapping() {
        let reduced = ["ʌ", "ə", "ɪ", "æ", "ɔ", "ɛ", "ɵ"]
        for ipa in reduced {
            let id = AlignmentVocabMap.vocabId(for: ipa)
            XCTAssertNotNil(id, "Редуцированная гласная '\(ipa)' должна маппироваться")
            if let id = id {
                let symbol = Wav2Vec2Vocabulary.symbol(at: id)
                XCTAssertNotNil(symbol, "vocab-id \(id) для '\(ipa)' не найден в словаре")
            }
        }
    }

    // MARK: - Тест 35: canonicalIPA для конкурентов возвращает IPA

    func test_canonicalIPA_forKnownVocabIds() {
        let knownPairs: [(Int, String?)] = [
            (Wav2Vec2Vocabulary.index(of: "р")!, "r"),
            (Wav2Vec2Vocabulary.index(of: "л")!, "l"),
            (Wav2Vec2Vocabulary.index(of: "с")!, "s"),
            (Wav2Vec2Vocabulary.index(of: "ш")!, "ʂ"),
            (Wav2Vec2Vocabulary.index(of: "к")!, "k"),
            (Wav2Vec2Vocabulary.index(of: "г")!, "g"),
            (Wav2Vec2Vocabulary.index(of: "х")!, "x"),
            (Wav2Vec2Vocabulary.index(of: "ж")!, "ʐ"),
            (Wav2Vec2Vocabulary.index(of: "щ")!, "ɕː"),
            (Wav2Vec2Vocabulary.index(of: "ч")!, "tɕ"),
            (Wav2Vec2Vocabulary.index(of: "ц")!, "ts"),
        ]
        for (vocabId, expectedIPA) in knownPairs {
            let ipa = AlignmentVocabMap.canonicalIPA(forVocabId: vocabId)
            XCTAssertEqual(ipa, expectedIPA,
                "canonicalIPA(forVocabId: \(vocabId)) = '\(ipa ?? "nil")', ожидалось '\(expectedIPA ?? "nil")'")
        }
    }

    // MARK: - Тест 36: vocabIds(for:) фильтрует неподдерживаемые фонемы

    func test_vocabIds_filtersUnsupported() {
        // Берём набор из поддерживаемых + заведомо несуществующей фонемы
        let input = ["r", "a", "NONEXISTENT_IPA_SYMBOL"]
        let ids = AlignmentVocabMap.vocabIds(for: input)
        // Должно быть 2 id (r и a), не 3 (несуществующая отфильтрована)
        XCTAssertEqual(ids.count, 2)
    }

    // MARK: - Тест 37: Blank (index 0) НЕ является vocab-id ни одной реальной фонемы

    func test_noRealPhonemeMapsToBlankorSpecial() {
        let specialIds = Set([
            Wav2Vec2Vocabulary.blankIndex,  // 0: <pad>
            1,  // <s>
            2,  // </s>
            3   // <unk>
        ])
        for ipa in RussianPhonemeInventory.all {
            if let id = AlignmentVocabMap.vocabId(for: ipa) {
                XCTAssertFalse(specialIds.contains(id),
                    "IPA '\(ipa)' маппируется в специальный токен (id=\(id)): \(Wav2Vec2Vocabulary.symbol(at: id) ?? "?")")
            }
        }
    }

    // MARK: - Тест 38: Все vocab-id в допустимом диапазоне [0, 36]

    func test_allVocabIds_inValidRange() {
        for ipa in RussianPhonemeInventory.all {
            if let id = AlignmentVocabMap.vocabId(for: ipa) {
                XCTAssertGreaterThanOrEqual(id, 0, "vocab-id для '\(ipa)' < 0")
                XCTAssertLessThan(id, Wav2Vec2Vocabulary.size,
                    "vocab-id \(id) для '\(ipa)' >= размера словаря \(Wav2Vec2Vocabulary.size)")
            }
        }
    }

    // MARK: - Тест 39: G2P → vocabIds для простого слова

    func test_g2p_to_vocabIds_simpleWord() {
        let g2p = RussianG2P()
        let phonemes = g2p.transcribe("рак")  // → ["r", "a", "k"]
        let ids = AlignmentVocabMap.vocabIds(for: phonemes)
        XCTAssertEqual(ids.count, 3)
        XCTAssertEqual(Wav2Vec2Vocabulary.symbol(at: ids[0]), "р")
        XCTAssertEqual(Wav2Vec2Vocabulary.symbol(at: ids[1]), "а")
        XCTAssertEqual(Wav2Vec2Vocabulary.symbol(at: ids[2]), "к")
    }

    // MARK: - Тест 40: G2P + vocabIds для слова с мягким согласным

    func test_g2p_to_vocabIds_palatalizedWord() {
        let g2p = RussianG2P()
        let phonemes = g2p.transcribe("лён")   // → ["lʲ", "o", "n"]
        let ids = AlignmentVocabMap.vocabIds(for: phonemes)
        // Все 3 фонемы должны маппироваться
        XCTAssertEqual(ids.count, 3)
        // lʲ → л (base form)
        XCTAssertEqual(Wav2Vec2Vocabulary.symbol(at: ids[0]), "л")
    }

    // MARK: - Тест 41: Шипящие аффрикаты и сложные символы маппируются

    func test_complexPhonemes_allMapped() {
        let complex = ["ts", "tɕ", "ɕː", "ʂ", "ʐ"]
        for ipa in complex {
            XCTAssertNotNil(
                AlignmentVocabMap.vocabId(for: ipa),
                "Сложный IPA '\(ipa)' не маппируется"
            )
        }
    }

    // MARK: - Тест 42: canonicalIPA для blank возвращает nil

    func test_canonicalIPA_forBlank_returnsNil() {
        let result = AlignmentVocabMap.canonicalIPA(forVocabId: Wav2Vec2Vocabulary.blankIndex)
        XCTAssertNil(result, "canonicalIPA для blank (0) должен быть nil")
    }
}
