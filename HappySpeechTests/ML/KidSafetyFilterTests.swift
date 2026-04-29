@testable import HappySpeech
import XCTest

// MARK: - KidSafetyFilterTests
// ==================================================================================
// Тесты KidSafetyFilter — actor для sanitization LLM output в kid circuit.
// Все тесты используют async/await (actor-isolated методы).
// ==================================================================================

final class KidSafetyFilterTests: XCTestCase {

    private var filter: KidSafetyFilter!

    override func setUp() {
        super.setUp()
        filter = KidSafetyFilter()
    }

    // MARK: - H7-01: Чистый безопасный текст проходит без изменений.

    func testSafeText_passesThrough() async {
        let text = "Ляля идёт в поход. Всё хорошо!"
        let result = await filter.sanitize(text)
        if case .safe(let out) = result {
            XCTAssertEqual(out, text)
        } else {
            XCTFail("Expected .safe, got \(result)")
        }
    }

    // MARK: - H7-02: Негативные эмоции — banned word "страшно".

    func testBannedWord_negativeEmotion_returnsUnsafe() async {
        let text = "Это очень страшно и опасно для детей."
        let result = await filter.sanitize(text)
        if case .unsafe(let reason) = result {
            XCTAssertTrue(reason.contains("banned_word"))
        } else {
            XCTFail("Expected .unsafe for scary content, got \(result)")
        }
    }

    // MARK: - H7-03: Тема насилия — banned word "убить".

    func testBannedWord_violence_returnsUnsafe() async {
        let text = "Дракон хотел убить рыцаря."
        let result = await filter.sanitize(text)
        if case .unsafe = result {
            // pass
        } else {
            XCTFail("Expected .unsafe for violent content")
        }
    }

    // MARK: - H7-04: Коммерческие темы — banned word "купить".

    func testBannedWord_commercial_returnsUnsafe() async {
        let text = "Нужно купить новые игрушки за деньги."
        let result = await filter.sanitize(text)
        if case .unsafe = result {
            // pass
        } else {
            XCTFail("Expected .unsafe for commercial content")
        }
    }

    // MARK: - H7-05: Технический сленг — banned word "баг".

    func testBannedWord_technicalSlang_returnsUnsafe() async {
        let text = "В игре есть баг, фейл юзера."
        let result = await filter.sanitize(text)
        if case .unsafe = result {
            // pass
        } else {
            XCTFail("Expected .unsafe for technical slang")
        }
    }

    // MARK: - H7-06: Банальное слово в середине строки — обнаруживается.

    func testBannedWord_inMiddleOfSentence_detected() async {
        let text = "Ляля говорит, что это плохо для всех."
        let result = await filter.sanitize(text)
        if case .unsafe = result {
            // pass
        } else {
            XCTFail("Expected .unsafe when banned word is embedded in sentence")
        }
    }

    // MARK: - H7-07: Лимит слов — длинный текст требует усечения.

    func testMaxWordsLimit_triggersNeedsTruncation() async {
        let longText = Array(repeating: "слово", count: 35).joined(separator: " ")
        let result = await filter.sanitize(longText)
        if case .needsTruncation(let count) = result {
            XCTAssertGreaterThan(count, 30)
        } else {
            XCTFail("Expected .needsTruncation for \(longText.split(separator: " ").count) words, got \(result)")
        }
    }

    // MARK: - H7-08: Усечение сохраняет правильное количество слов.

    func testTruncate_producesCorrectWordCount() async {
        let longText = Array(repeating: "хорошее", count: 40).joined(separator: " ")
        let truncated = await filter.truncate(longText)
        let wordCount = truncated.split(separator: " ").count
        XCTAssertLessThanOrEqual(wordCount, 30, "Truncated text must be ≤30 words")
    }

    // MARK: - H7-09: Пустая строка — unsafe.

    func testEmptyString_returnsUnsafe() async {
        let result = await filter.sanitize("")
        if case .unsafe(let reason) = result {
            XCTAssertEqual(reason, "empty_text")
        } else {
            XCTFail("Expected .unsafe(empty_text) for empty string")
        }
    }

    // MARK: - H7-10: Только пробелы — unsafe.

    func testWhitespaceOnly_returnsUnsafe() async {
        let result = await filter.sanitize("   \n\t  ")
        if case .unsafe = result {
            // pass
        } else {
            XCTFail("Expected .unsafe for whitespace-only string")
        }
    }

    // MARK: - H7-11: Лимит предложений.

    func testMaxSentencesLimit_triggersNeedsTruncation() async {
        let manySentences = "Ляля пошла в лес. Она нашла гриб. Гриб был большой. Ляля обрадовалась."
        let result = await filter.sanitize(manySentences)
        switch result {
        case .needsTruncation:
            // pass — 4 предложения > maxSentences (3)
            break
        case .safe:
            // Тест проверяет границу — убеждаемся что предложений не более 3.
            let sentences = manySentences
                .components(separatedBy: CharacterSet(charactersIn: ".!?"))
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            XCTAssertLessThanOrEqual(sentences.count, 3, "Should not be .safe with >3 sentences")
        case .unsafe:
            // unsafe допустимо только если есть banned words — этот текст безопасен.
            XCTFail("Expected .needsTruncation or .safe, not .unsafe for this text")
        }
    }
}
