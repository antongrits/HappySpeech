@testable import HappySpeech
import XCTest

// MARK: - SoundCompositionBuilderTests
//
// Проверяет чистую методическую логику генерации эльконинской цветовой схемы
// (`classify` / `colorScheme`) на реальных словах + загрузку пака и сборку
// сессии с антифатиговым чередованием.

@MainActor
final class SoundCompositionBuilderTests: XCTestCase {

    private func makeSUT() -> SoundCompositionBuilder { SoundCompositionBuilder() }

    // MARK: - classify: vowels

    func test_classify_vowels_areVowel() {
        let letters = ["А", "О", "У", "Ы", "Э", "Я", "Ё", "Ю", "Е", "И"]
        for (i, _) in letters.enumerated() {
            XCTAssertEqual(SoundCompositionBuilder.classify(letters: letters, at: i), .vowel)
        }
    }

    // MARK: - classify: always-hard ж/ш/ц

    func test_classify_alwaysHard_zhShTs() {
        // даже перед смягчающим И — остаются твёрдыми (методический инвариант).
        XCTAssertEqual(SoundCompositionBuilder.classify(letters: ["Ж", "И"], at: 0), .hard)
        XCTAssertEqual(SoundCompositionBuilder.classify(letters: ["Ш", "И"], at: 0), .hard)
        XCTAssertEqual(SoundCompositionBuilder.classify(letters: ["Ц", "И"], at: 0), .hard)
    }

    // MARK: - classify: always-soft ч/щ/й

    func test_classify_alwaysSoft_chSchJ() {
        XCTAssertEqual(SoundCompositionBuilder.classify(letters: ["Ч", "А"], at: 0), .soft)
        XCTAssertEqual(SoundCompositionBuilder.classify(letters: ["Щ", "У"], at: 0), .soft)
        XCTAssertEqual(SoundCompositionBuilder.classify(letters: ["Й"], at: 0), .soft)
    }

    // MARK: - classify: paired consonant softness by next letter

    func test_classify_pairedConsonant_softBeforeSofteningVowel() {
        // МИШКА: М перед И → мягкий.
        XCTAssertEqual(SoundCompositionBuilder.classify(letters: ["М", "И", "Ш", "К", "А"], at: 0), .soft)
        // ЛИСА: Л перед И → мягкий.
        XCTAssertEqual(SoundCompositionBuilder.classify(letters: ["Л", "И", "С", "А"], at: 0), .soft)
        // КИТ: К перед И → мягкий.
        XCTAssertEqual(SoundCompositionBuilder.classify(letters: ["К", "И", "Т"], at: 0), .soft)
    }

    func test_classify_pairedConsonant_hardBeforeHardVowel() {
        // МЫШКА: М перед Ы → твёрдый.
        XCTAssertEqual(SoundCompositionBuilder.classify(letters: ["М", "Ы", "Ш", "К", "А"], at: 0), .hard)
        // ЛУНА: Л перед У → твёрдый.
        XCTAssertEqual(SoundCompositionBuilder.classify(letters: ["Л", "У", "Н", "А"], at: 0), .hard)
        // КОТ: К перед О → твёрдый.
        XCTAssertEqual(SoundCompositionBuilder.classify(letters: ["К", "О", "Т"], at: 0), .hard)
    }

    func test_classify_consonantBeforeSoftSign_isSoft() {
        // КОНЬ: Н перед Ь → мягкий.
        XCTAssertEqual(SoundCompositionBuilder.classify(letters: ["К", "О", "Н", "Ь"], at: 2), .soft)
    }

    func test_classify_finalConsonant_isHard() {
        // НОС: С в конце (нет следующего) → твёрдый.
        XCTAssertEqual(SoundCompositionBuilder.classify(letters: ["Н", "О", "С"], at: 2), .hard)
    }

    // MARK: - colorScheme: full words

    func test_colorScheme_mishka() {
        // МИШКА → soft, vowel, hard, hard, vowel.
        let scheme = SoundCompositionBuilder.colorScheme(for: ["М", "И", "Ш", "К", "А"])
        XCTAssertEqual(scheme, [.soft, .vowel, .hard, .hard, .vowel])
    }

    func test_colorScheme_lisa() {
        // ЛИСА → soft, vowel, hard, vowel.
        let scheme = SoundCompositionBuilder.colorScheme(for: ["Л", "И", "С", "А"])
        XCTAssertEqual(scheme, [.soft, .vowel, .hard, .vowel])
    }

    func test_colorScheme_chai() {
        // ЧАЙ → soft, vowel, soft.
        let scheme = SoundCompositionBuilder.colorScheme(for: ["Ч", "А", "Й"])
        XCTAssertEqual(scheme, [.soft, .vowel, .soft])
    }

    // MARK: - loadWords (pack or fallback)

    func test_loadWords_returnsNonEmpty() {
        let words = makeSUT().loadWords()
        XCTAssertFalse(words.isEmpty, "loadWords должен вернуть слова (пак или fallback)")
        // Каждое слово имеет звуки и непустой ассет.
        for w in words {
            XCTAssertFalse(w.sounds.isEmpty, "\(w.text) без звуков")
            XCTAssertTrue(w.imageAsset.hasPrefix("word_"), "\(w.text) ассет не word_*: \(w.imageAsset)")
            XCTAssertTrue((1...w.sounds.count).contains(w.stressIndex), "\(w.text) stress вне диапазона")
            XCTAssertEqual(w.sounds[w.stressIndex - 1].type, .vowel, "\(w.text) ударение не на гласном")
        }
    }

    func test_loadWords_typesMatchRuleForEveryWord() {
        // Каждый звук пака должен совпадать с правилом классификации
        // (защита от ручных ошибок разметки в JSON).
        let words = makeSUT().loadWords()
        for w in words {
            let letters = w.sounds.map { $0.letter }
            for (i, s) in w.sounds.enumerated() {
                let expected = SoundCompositionBuilder.classify(letters: letters, at: i)
                XCTAssertEqual(s.type, expected,
                               "\(w.text) звук \(i) '\(s.letter)': pack=\(s.type) rule=\(expected)")
            }
        }
    }

    func test_loadWords_includesChainWordWithBonus() {
        let words = makeSUT().loadWords()
        XCTAssertTrue(words.contains { $0.chain != nil },
                      "Должно быть хотя бы одно слово с бонус-цепочкой")
        if let chained = words.first(where: { $0.chain != nil }) {
            XCTAssertFalse(chained.chain?.variants.isEmpty ?? true)
        }
    }

    // MARK: - buildSession

    func test_buildSession_respectsAgeSoundLimit() {
        let words = makeSUT().loadWords()
        // 6 лет → не более 4 звуков.
        let session6 = makeSUT().buildSession(from: words, age: 6, count: 6)
        XCTAssertFalse(session6.isEmpty)
        XCTAssertTrue(session6.allSatisfy { $0.soundCount <= 4 },
                      "Для 6 лет слова должны быть ≤4 звуков")
        // 8 лет → допускаются 5 звуков.
        let session8 = makeSUT().buildSession(from: words, age: 8, count: 6)
        XCTAssertTrue(session8.allSatisfy { $0.soundCount <= 5 })
    }

    func test_buildSession_count() {
        let words = makeSUT().loadWords()
        let session = makeSUT().buildSession(from: words, age: 7, count: 5)
        XCTAssertLessThanOrEqual(session.count, 5)
        XCTAssertGreaterThan(session.count, 0)
    }

    func test_buildSession_endsWithChainWord_forBonus() {
        let words = makeSUT().loadWords()
        let session = makeSUT().buildSession(from: words, age: 8, count: 6)
        XCTAssertNotNil(session.last?.chain,
                        "Последнее слово сессии должно иметь бонус-цепочку")
    }

    func test_buildSession_emptyInput_returnsEmpty() {
        let session = makeSUT().buildSession(from: [], age: 7, count: 6)
        XCTAssertTrue(session.isEmpty)
    }
}
