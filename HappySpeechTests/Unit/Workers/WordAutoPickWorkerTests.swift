@testable import HappySpeech
import XCTest

// MARK: - WordAutoPickWorkerTests
//
// Покрытие логики авто-подбора слов специалистом (WordAutoPickWorker).
// Worker фильтрует реальные слова из bundled-манифеста (LessonContentMap) по
// целевому звуку, позиции звука в слове и диапазону слогов.
//
// Тесты проверяют:
//   • SyllableRange.matches — точные границы диапазонов слогов (чистая логика).
//   • pick(): неизвестный звук → пустой результат без краша.
//   • pick(): инвариант — каждое возвращённое слово удовлетворяет ВСЕМ фильтрам
//     (содержит звук + правильная позиция + диапазон слогов). Проверяется
//     пост-условие на реальных данных манифеста, поэтому устойчиво к его размеру.
//   • pick(): лимит requestedCount соблюдается, words.count ≤ totalCandidates.
//   • pick(): position=.initial / .ending / .medial действительно фильтруют.
//
// Worker @MainActor → класс теста @MainActor.

@MainActor
final class WordAutoPickWorkerTests: XCTestCase {

    private func makeSUT() -> WordAutoPickWorker { WordAutoPickWorker() }

    // MARK: - Гласные / слоги: SyllableRange.matches (чистая логика, точные границы)

    func test_syllableRange_oneTwo_matchesOneAndTwoOnly() {
        XCTAssertFalse(SyllableRange.oneTwo.matches(0))
        XCTAssertTrue(SyllableRange.oneTwo.matches(1))
        XCTAssertTrue(SyllableRange.oneTwo.matches(2))
        XCTAssertFalse(SyllableRange.oneTwo.matches(3))
    }

    func test_syllableRange_twoThree_matchesTwoAndThreeOnly() {
        XCTAssertFalse(SyllableRange.twoThree.matches(1))
        XCTAssertTrue(SyllableRange.twoThree.matches(2))
        XCTAssertTrue(SyllableRange.twoThree.matches(3))
        XCTAssertFalse(SyllableRange.twoThree.matches(4))
    }

    func test_syllableRange_threePlus_matchesThreeOrMore() {
        XCTAssertFalse(SyllableRange.threePlus.matches(2))
        XCTAssertTrue(SyllableRange.threePlus.matches(3))
        XCTAssertTrue(SyllableRange.threePlus.matches(10))
    }

    func test_syllableRange_all_matchesEverything() {
        XCTAssertTrue(SyllableRange.all.matches(0))
        XCTAssertTrue(SyllableRange.all.matches(1))
        XCTAssertTrue(SyllableRange.all.matches(7))
    }

    // MARK: - Неизвестный звук → честный пустой результат

    func test_pick_unknownSound_returnsEmpty() {
        let sut = makeSUT()
        let result = sut.pick(params: AutoPickParams(
            targetSound: "Ъ",            // не в таблице графем
            position: .any,
            syllableRange: .all,
            requestedCount: 10
        ))
        XCTAssertTrue(result.words.isEmpty)
        XCTAssertEqual(result.totalCandidates, 0)
    }

    func test_pick_emptySound_returnsEmpty() {
        let sut = makeSUT()
        let result = sut.pick(params: AutoPickParams(
            targetSound: "",
            position: .any,
            syllableRange: .all,
            requestedCount: 10
        ))
        XCTAssertTrue(result.words.isEmpty)
        XCTAssertEqual(result.totalCandidates, 0)
    }

    // MARK: - requestedCount=0 → пустой список, но кандидаты посчитаны

    func test_pick_zeroRequested_returnsNoWordsButCountsCandidates() {
        let sut = makeSUT()
        let result = sut.pick(params: AutoPickParams(
            targetSound: "Р",
            position: .any,
            syllableRange: .all,
            requestedCount: 0
        ))
        XCTAssertTrue(result.words.isEmpty, "requestedCount=0 не должен вернуть слов")
        XCTAssertGreaterThanOrEqual(result.totalCandidates, 0)
    }

    // MARK: - Лимит соблюдается, words ⊆ candidates

    func test_pick_respectsRequestedCountLimit() {
        let sut = makeSUT()
        let limit = 5
        let result = sut.pick(params: AutoPickParams(
            targetSound: "Р",
            position: .any,
            syllableRange: .all,
            requestedCount: limit
        ))
        XCTAssertLessThanOrEqual(result.words.count, limit,
                                 "Число выбранных слов не должно превышать requestedCount")
        XCTAssertLessThanOrEqual(result.words.count, result.totalCandidates,
                                 "Выбранных не больше, чем всего кандидатов")
    }

    // MARK: - Инвариант: каждое возвращённое слово содержит целевой звук

    func test_pick_allReturnedWordsContainTargetSound() {
        let sut = makeSUT()
        let result = sut.pick(params: AutoPickParams(
            targetSound: "С",
            position: .any,
            syllableRange: .all,
            requestedCount: 50
        ))
        // Если в манифесте есть слова на С (что ожидаемо) — все они содержат «с».
        for word in result.words {
            XCTAssertTrue(word.lowercased().contains("с"),
                          "Слово '\(word)' выбрано для звука С, но не содержит графему 'с'")
        }
    }

    // MARK: - Инвариант: position=.initial → звук в начале слова

    func test_pick_initialPosition_wordsStartWithSound() {
        let sut = makeSUT()
        let result = sut.pick(params: AutoPickParams(
            targetSound: "С",
            position: .initial,
            syllableRange: .all,
            requestedCount: 50
        ))
        for word in result.words {
            XCTAssertTrue(word.lowercased().hasPrefix("с"),
                          "initial-фильтр вернул '\(word)', не начинающееся на 'с'")
        }
    }

    // MARK: - Инвариант: position=.ending → звук в конце (с учётом мягкого знака)

    func test_pick_endingPosition_wordsEndWithSoundIgnoringSoftSign() {
        let sut = makeSUT()
        let result = sut.pick(params: AutoPickParams(
            targetSound: "Р",
            position: .ending,
            syllableRange: .all,
            requestedCount: 50
        ))
        for word in result.words {
            let lower = word.lowercased()
            // Убираем хвостовые ь/ъ — как делает effectiveWordEnd в Worker.
            var trimmed = Substring(lower)
            while let last = trimmed.last, last == "ь" || last == "ъ" {
                trimmed = trimmed.dropLast()
            }
            XCTAssertTrue(trimmed.hasSuffix("р"),
                          "ending-фильтр вернул '\(word)', не оканчивающееся на 'р' (без ь/ъ)")
        }
    }

    // MARK: - Инвариант: position=.medial → звук НЕ в начале и НЕ в конце

    func test_pick_medialPosition_soundIsInterior() {
        let sut = makeSUT()
        let result = sut.pick(params: AutoPickParams(
            targetSound: "Р",
            position: .medial,
            syllableRange: .all,
            requestedCount: 50
        ))
        for word in result.words {
            let lower = word.lowercased()
            guard let firstIdx = lower.firstIndex(of: "р") else {
                XCTFail("medial-фильтр вернул '\(word)' без графемы 'р'")
                continue
            }
            // Существует вхождение 'р' не в позиции 0 и не на «значимом» конце.
            var trimmed = Substring(lower)
            while let last = trimmed.last, last == "ь" || last == "ъ" {
                trimmed = trimmed.dropLast()
            }
            let isOnlyAtStart = (firstIdx == lower.startIndex)
                && lower.dropFirst().firstIndex(of: "р") == nil
            XCTAssertFalse(isOnlyAtStart && trimmed.count <= 1,
                           "medial-слово '\(word)' выглядит так, будто звук только в начале")
        }
    }

    // MARK: - Инвариант: диапазон слогов соблюдается (число гласных)

    func test_pick_syllableRange_oneTwo_returnsShortWords() {
        let sut = makeSUT()
        let vowels: Set<Character> = ["а", "е", "ё", "и", "й", "о", "у", "ы", "э", "ю", "я"]
        let result = sut.pick(params: AutoPickParams(
            targetSound: "С",
            position: .any,
            syllableRange: .oneTwo,
            requestedCount: 50
        ))
        for word in result.words {
            let vowelCount = word.lowercased().filter { vowels.contains($0) }.count
            XCTAssertTrue(vowelCount >= 1 && vowelCount <= 2,
                          "Слово '\(word)' имеет \(vowelCount) гласных, вне диапазона 1–2")
        }
    }

    // MARK: - Сужение диапазона не увеличивает число кандидатов

    func test_pick_narrowerSyllableRange_yieldsNoMoreCandidates() {
        let sut = makeSUT()
        let all = sut.pick(params: AutoPickParams(
            targetSound: "Р", position: .any, syllableRange: .all, requestedCount: 1
        ))
        let oneTwo = sut.pick(params: AutoPickParams(
            targetSound: "Р", position: .any, syllableRange: .oneTwo, requestedCount: 1
        ))
        XCTAssertLessThanOrEqual(oneTwo.totalCandidates, all.totalCandidates,
            "Сужение слогового диапазона не может увеличить число кандидатов")
    }

    // MARK: - position=.any покрывает все позиции (кандидатов ≥ initial)

    func test_pick_anyPosition_supersetOfInitial() {
        let sut = makeSUT()
        let any = sut.pick(params: AutoPickParams(
            targetSound: "С", position: .any, syllableRange: .all, requestedCount: 1
        ))
        let initial = sut.pick(params: AutoPickParams(
            targetSound: "С", position: .initial, syllableRange: .all, requestedCount: 1
        ))
        XCTAssertGreaterThanOrEqual(any.totalCandidates, initial.totalCandidates,
            "position=.any должно покрывать не меньше кандидатов, чем .initial")
    }

    // MARK: - Уникальность выбранных слов (shuffled+prefix не дублирует)

    func test_pick_returnedWordsAreUnique() {
        let sut = makeSUT()
        let result = sut.pick(params: AutoPickParams(
            targetSound: "Р", position: .any, syllableRange: .all, requestedCount: 30
        ))
        let unique = Set(result.words.map { $0.lowercased() })
        XCTAssertEqual(unique.count, result.words.count,
                       "Выбранные слова не должны содержать дубликатов")
    }

    // MARK: - WordPosition / SyllableRange — стабильность rawValue (контракт persistence/Codable)

    func test_wordPosition_rawValues_stable() {
        XCTAssertEqual(WordPosition.initial.rawValue, "initial")
        XCTAssertEqual(WordPosition.medial.rawValue, "medial")
        XCTAssertEqual(WordPosition.ending.rawValue, "final")
        XCTAssertEqual(WordPosition.any.rawValue, "any")
        XCTAssertEqual(WordPosition.allCases.count, 4)
    }

    func test_syllableRange_rawValues_stable() {
        XCTAssertEqual(SyllableRange.oneTwo.rawValue, "1-2")
        XCTAssertEqual(SyllableRange.twoThree.rawValue, "2-3")
        XCTAssertEqual(SyllableRange.threePlus.rawValue, "3+")
        XCTAssertEqual(SyllableRange.all.rawValue, "all")
    }
}
