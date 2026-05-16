@testable import HappySpeech
import XCTest

// MARK: - GrammarContentLoaderWorkerTests
//
// Покрывает статические вспомогательные методы GrammarContentLoaderWorker
// (extractNoun, pluralDistractors, instrumentalDistractors,
//  dativeCharacters, genitiveContainers, fallbackRounds).
// Методы, зависящие от Bundle.main.url (fetchItems / loadRounds), не тестируются —
// pack_grammar.json отсутствует в test-target bundle.

@MainActor
final class GrammarContentLoaderWorkerTests: XCTestCase {

    // MARK: - extractNoun

    func test_extractNoun_stopWordOne_returnsNoun() {
        let result = GrammarContentLoaderWorker.extractNoun(from: "один кот")
        XCTAssertEqual(result, "кот", "Стоп-слово «один» должно быть удалено")
    }

    func test_extractNoun_stopWordMnogo_returnsNoun() {
        let result = GrammarContentLoaderWorker.extractNoun(from: "много котов")
        XCTAssertEqual(result, "котов")
    }

    func test_extractNoun_noStopWord_returnsFirstWord() {
        let result = GrammarContentLoaderWorker.extractNoun(from: "мяч")
        XCTAssertEqual(result, "мяч")
    }

    func test_extractNoun_emptyString_returnsEmpty() {
        let result = GrammarContentLoaderWorker.extractNoun(from: "")
        XCTAssertEqual(result, "", "Пустая строка должна вернуть пустую строку")
    }

    func test_extractNoun_allStopWords_returnsOriginal() {
        let result = GrammarContentLoaderWorker.extractNoun(from: "один")
        // Единственное слово — стоп-слово: first(where:) вернёт nil → оригинал
        XCTAssertEqual(result, "один")
    }

    // MARK: - pluralDistractors

    func test_pluralDistractors_count_matchesRequested() {
        let distractors = GrammarContentLoaderWorker.pluralDistractors(
            for: "кот",
            correct: "коты",
            count: 3
        )
        XCTAssertEqual(distractors.count, 3, "Дистракторов должно быть ровно 3")
    }

    func test_pluralDistractors_notContainCorrect() {
        let correct = "коты"
        let distractors = GrammarContentLoaderWorker.pluralDistractors(
            for: "кот",
            correct: correct,
            count: 3
        )
        XCTAssertFalse(distractors.contains(correct),
                       "Список дистракторов не должен содержать правильный ответ")
    }

    func test_pluralDistractors_noDuplicates() {
        let distractors = GrammarContentLoaderWorker.pluralDistractors(
            for: "дом",
            correct: "дома",
            count: 3
        )
        let unique = Set(distractors)
        XCTAssertEqual(unique.count, distractors.count, "Дистракторы не должны дублироваться")
    }

    func test_pluralDistractors_zeroCount_isEmpty() {
        let distractors = GrammarContentLoaderWorker.pluralDistractors(
            for: "рыба",
            correct: "рыбы",
            count: 0
        )
        XCTAssertTrue(distractors.isEmpty, "При count=0 должен вернуться пустой массив")
    }

    // MARK: - instrumentalDistractors

    func test_instrumentalDistractors_countMatchesRequest() {
        let result = GrammarContentLoaderWorker.instrumentalDistractors(for: "с Машей", count: 3)
        XCTAssertEqual(result.count, 3)
    }

    func test_instrumentalDistractors_notContainCorrect() {
        let correct = "с Машей"
        let result = GrammarContentLoaderWorker.instrumentalDistractors(for: correct, count: 4)
        XCTAssertFalse(result.contains(correct),
                       "Дистракторы не должны содержать правильный вариант")
    }

    // MARK: - dativeCharacters

    func test_dativeCharacters_returnsNonEmpty() {
        let chars = GrammarContentLoaderWorker.dativeCharacters()
        XCTAssertFalse(chars.isEmpty, "Каталог персонажей не должен быть пустым")
    }

    func test_dativeCharacters_allHaveNonEmptyIds() {
        let chars = GrammarContentLoaderWorker.dativeCharacters()
        for ch in chars {
            XCTAssertFalse(ch.id.isEmpty, "id персонажа не должен быть пустым")
            XCTAssertFalse(ch.dativeName.isEmpty, "dativeName не должен быть пустым")
        }
    }

    // MARK: - genitiveContainers

    func test_genitiveContainers_returnsNonEmpty() {
        let containers = GrammarContentLoaderWorker.genitiveContainers()
        XCTAssertFalse(containers.isEmpty)
    }

    func test_genitiveContainers_allHaveGenitiveName() {
        let containers = GrammarContentLoaderWorker.genitiveContainers()
        for container in containers {
            XCTAssertFalse(container.genitiveName.isEmpty)
        }
    }

    // MARK: - fallbackRounds

    func test_fallbackRounds_easyDifficulty_returnsExpectedCount() {
        let rounds = GrammarContentLoaderWorker.fallbackRounds(mode: .oneMany, difficulty: .easy)
        XCTAssertFalse(rounds.isEmpty, "Fallback раунды не должны быть пустыми")
        XCTAssertLessThanOrEqual(rounds.count, GrammarDifficulty.easy.totalRounds)
    }

    func test_fallbackRounds_modeIsOneMany() {
        let rounds = GrammarContentLoaderWorker.fallbackRounds(mode: .oneMany, difficulty: .medium)
        for round in rounds {
            XCTAssertEqual(round.mode, .oneMany)
        }
    }

    func test_fallbackRounds_correctAnswerNotEmpty() {
        let rounds = GrammarContentLoaderWorker.fallbackRounds(mode: .oneMany, difficulty: .easy)
        for round in rounds {
            XCTAssertFalse(round.correctAnswer.isEmpty, "correctAnswer не должен быть пустым")
        }
    }

    func test_fallbackRounds_choicesContainCorrectAnswer() {
        let rounds = GrammarContentLoaderWorker.fallbackRounds(mode: .oneMany, difficulty: .easy)
        for round in rounds {
            let hasCorrect = round.choices.contains(where: { $0.text == round.correctAnswer })
            XCTAssertTrue(hasCorrect, "Список вариантов должен содержать правильный ответ")
        }
    }

    func test_fallbackRounds_hardDifficulty_atLeastOneRound() {
        let rounds = GrammarContentLoaderWorker.fallbackRounds(mode: .oneMany, difficulty: .hard)
        XCTAssertFalse(rounds.isEmpty)
    }
}
