@testable import HappySpeech
import XCTest

// MARK: - ChildSafetyValidatorTests
//
// Phase 2.4 v25 — покрытие ChildSafetyValidator (синхронный статический валидатор).
// Целевой класс: ML/LLM/ChildSafetyValidator.swift
// Тестируется: validate(), truncateToLimit()

final class ChildSafetyValidatorTests: XCTestCase {

    // MARK: - validate: позитивный путь

    func test_validate_safeText_returnsTrue() {
        let text = "Ляля идёт гулять. Всё хорошо!"
        XCTAssertTrue(ChildSafetyValidator.validate(text))
    }

    func test_validate_shortSafeWord_returnsTrue() {
        XCTAssertTrue(ChildSafetyValidator.validate("Привет"))
    }

    func test_validate_exactLimitLength_returnsTrue() {
        let text = String(repeating: "а", count: 256)
        XCTAssertTrue(ChildSafetyValidator.validate(text))
    }

    // MARK: - validate: пустые/пробельные строки

    func test_validate_emptyString_returnsFalse() {
        XCTAssertFalse(ChildSafetyValidator.validate(""))
    }

    func test_validate_whitespaceOnly_returnsFalse() {
        XCTAssertFalse(ChildSafetyValidator.validate("   \n\t  "))
    }

    // MARK: - validate: длина

    func test_validate_tooLong_returnsFalse() {
        let text = String(repeating: "б", count: 257)
        XCTAssertFalse(ChildSafetyValidator.validate(text))
    }

    func test_validate_slightlyOverLimit_returnsFalse() {
        let text = String(repeating: "в", count: 260)
        XCTAssertFalse(ChildSafetyValidator.validate(text))
    }

    // MARK: - validate: banned words (насилие/страх)

    func test_validate_bannedWord_smert_returnsFalse() {
        XCTAssertFalse(ChildSafetyValidator.validate("Это смерть всего."))
    }

    func test_validate_bannedWord_krov_returnsFalse() {
        XCTAssertFalse(ChildSafetyValidator.validate("Видна кровь."))
    }

    func test_validate_bannedWord_voyna_returnsFalse() {
        XCTAssertFalse(ChildSafetyValidator.validate("Идёт война."))
    }

    func test_validate_bannedWord_udarit_returnsFalse() {
        XCTAssertFalse(ChildSafetyValidator.validate("Нужно ударить."))
    }

    // MARK: - validate: banned words (взрослые темы)

    func test_validate_bannedWord_alkohol_returnsFalse() {
        XCTAssertFalse(ChildSafetyValidator.validate("Алкоголь вреден."))
    }

    func test_validate_bannedWord_reklama_returnsFalse() {
        XCTAssertFalse(ChildSafetyValidator.validate("Реклама продукта."))
    }

    // MARK: - validate: banned words (техмусор)

    func test_validate_bannedWord_assistantPrefix_returnsFalse() {
        XCTAssertFalse(ChildSafetyValidator.validate("assistant: привет"))
    }

    func test_validate_bannedWord_humanPrefix_returnsFalse() {
        XCTAssertFalse(ChildSafetyValidator.validate("human: вопрос"))
    }

    func test_validate_bannedWord_imStart_returnsFalse() {
        XCTAssertFalse(ChildSafetyValidator.validate("<|im_start|>система"))
    }

    func test_validate_bannedWord_token_returnsFalse() {
        XCTAssertFalse(ChildSafetyValidator.validate("Токен обработан"))
    }

    // MARK: - validate: регистронезависимость

    func test_validate_bannedWord_uppercase_returnsFalse() {
        XCTAssertFalse(ChildSafetyValidator.validate("СМЕРТЬ это темно."))
    }

    func test_validate_bannedWord_mixed_case_returnsFalse() {
        XCTAssertFalse(ChildSafetyValidator.validate("Война идёт."))
    }

    // MARK: - validate: banned word среди безопасного текста

    func test_validate_bannedWordEmbedded_returnsFalse() {
        // "глупый" — в списке banned
        XCTAssertFalse(ChildSafetyValidator.validate("Он не глупый, но всё равно не справился."))
    }

    // MARK: - validate: негативная самооценка

    func test_validate_bannedWord_tupoy_returnsFalse() {
        XCTAssertFalse(ChildSafetyValidator.validate("Ты тупой."))
    }

    func test_validate_bannedWord_neudacha_returnsFalse() {
        XCTAssertFalse(ChildSafetyValidator.validate("Это неудача."))
    }

    // MARK: - truncateToLimit: базовые случаи

    func test_truncate_shortText_unchanged() {
        let text = "Короткий текст."
        XCTAssertEqual(ChildSafetyValidator.truncateToLimit(text), text)
    }

    func test_truncate_exactLimit_unchanged() {
        let text = String(repeating: "я", count: 256)
        XCTAssertEqual(ChildSafetyValidator.truncateToLimit(text), text)
    }

    func test_truncate_longText_fits256() {
        let text = String(repeating: "а", count: 300)
        let result = ChildSafetyValidator.truncateToLimit(text)
        XCTAssertLessThanOrEqual(result.count, 257, "Усечённый текст должен быть ≤257 символов (256 + точка)")
    }

    func test_truncate_endsPunctuationOrDot() {
        let text = "Длинный текст " + String(repeating: "слово ", count: 50)
        let result = ChildSafetyValidator.truncateToLimit(text)
        let lastChar = result.last
        XCTAssertTrue(
            lastChar == "." || lastChar == "!" || lastChar == "?",
            "Усечённый текст должен заканчиваться знаком препинания, получено: \(lastChar.map(String.init) ?? "nil")"
        )
    }

    func test_truncate_longWordOnly_appendsDot() {
        // Нет пробелов — обрезается по hard limit + точка
        let text = String(repeating: "б", count: 300)
        let result = ChildSafetyValidator.truncateToLimit(text)
        XCTAssertTrue(result.hasSuffix("."))
    }

    func test_truncate_leadingWhitespace_stripped() {
        let text = "   Нормальный текст"
        let result = ChildSafetyValidator.truncateToLimit(text)
        XCTAssertFalse(result.hasPrefix(" "), "Пробелы в начале должны быть убраны")
    }

    func test_truncate_trailingWhitespace_stripped() {
        let text = "Текст   "
        let result = ChildSafetyValidator.truncateToLimit(text)
        XCTAssertFalse(result.hasSuffix(" "), "Пробелы в конце должны быть убраны")
    }
}
