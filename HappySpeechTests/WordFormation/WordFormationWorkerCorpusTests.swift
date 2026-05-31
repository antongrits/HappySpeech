@testable import HappySpeech
import XCTest

// MARK: - Worker Subtask Resolution / Session Tests

@MainActor
final class WordFormationWorkerTests: XCTestCase {

    // MARK: Age gate

    func test_isAllowed_diminutiveAndOneMany_fromAge5() {
        XCTAssertTrue(WordFormationWorker.isAllowed(.diminutive, age: 5))
        XCTAssertTrue(WordFormationWorker.isAllowed(.oneMany, age: 5))
    }

    func test_isAllowed_manyOf_notBeforeAge6() {
        XCTAssertFalse(WordFormationWorker.isAllowed(.manyOf, age: 5))
        XCTAssertTrue(WordFormationWorker.isAllowed(.manyOf, age: 6))
    }

    func test_resolveSubtask_nilDefaultsToDiminutive() {
        XCTAssertEqual(WordFormationWorker.resolveSubtask(preferredSubtask: nil, age: 6), .diminutive)
    }

    func test_resolveSubtask_manyOfUnderAge6_fallsBackToDiminutive() {
        XCTAssertEqual(WordFormationWorker.resolveSubtask(preferredSubtask: .manyOf, age: 5), .diminutive)
    }

    func test_resolveSubtask_manyOfAtAge6_isManyOf() {
        XCTAssertEqual(WordFormationWorker.resolveSubtask(preferredSubtask: .manyOf, age: 6), .manyOf)
    }

    // MARK: Session building

    func test_makeRounds_respectsRoundsPerSession() {
        let rounds = WordFormationWorker.makeRounds(preferredSubtask: nil, age: 7)
        XCTAssertEqual(rounds.count, WordFormationCorpus.roundsPerSession)
    }

    func test_makeRounds_retroStart_beginsWithEasyDiminutive() {
        // Ретро-старт: первые 2 раунда — лёгкие (diminutive, difficulty 1), F1-015.
        let rounds = WordFormationWorker.makeRounds(preferredSubtask: nil, age: 7)
        XCTAssertGreaterThanOrEqual(rounds.count, 3)
        XCTAssertEqual(rounds[0].subtask, .diminutive)
        XCTAssertEqual(rounds[0].difficulty, 1)
        XCTAssertEqual(rounds[1].subtask, .diminutive)
        XCTAssertEqual(rounds[1].difficulty, 1)
    }

    func test_makeRounds_ageGate_noManyOfBeforeAge6() {
        let rounds = WordFormationWorker.makeRounds(preferredSubtask: nil, age: 5)
        XCTAssertFalse(rounds.contains { $0.subtask == .manyOf }, "manyOf недоступен до 6 лет")
        for round in rounds {
            XCTAssertLessThanOrEqual(round.minAge, 5, "Только доступные по возрасту раунды")
        }
    }

    func test_makeRounds_eachRoundHasExactlyOneCorrect() {
        let rounds = WordFormationWorker.makeRounds(preferredSubtask: nil, age: 8)
        for round in rounds {
            XCTAssertEqual(round.options.filter(\.isCorrect).count, 1, "Раунд \(round.id) — ровно одна норма")
            XCTAssertGreaterThanOrEqual(round.options.count, 2)
        }
    }

    func test_makeRounds_avoidsConsecutiveSameSubtask() {
        let rounds = WordFormationWorker.makeRounds(preferredSubtask: nil, age: 8)
        // После ретро-старта (2 diminutive) Worker чередует под-типы там, где
        // возможно — проверяем, что не вся сессия — один под-тип.
        let subtasks = Set(rounds.map(\.subtask))
        XCTAssertGreaterThan(subtasks.count, 1, "Сессия не должна быть из одного под-типа")
    }

    func test_makeRounds_noDuplicateBaseInSession() {
        let rounds = WordFormationWorker.makeRounds(preferredSubtask: nil, age: 8)
        let baseIds = rounds.map { $0.id.split(separator: "#").first.map(String.init) ?? $0.id }
        XCTAssertEqual(baseIds.count, Set(baseIds).count, "Один и тот же набор не повторяется в сессии")
    }

    func test_makeRounds_preferredSubtask_prioritised() {
        let rounds = WordFormationWorker.makeRounds(preferredSubtask: .manyOf, age: 8)
        XCTAssertTrue(rounds.contains { $0.subtask == .manyOf }, "Предпочтительный под-тип присутствует")
    }

    func test_shufflingOptions_preservesMembership() {
        let round = FormationRound(
            id: "r", subtask: .manyOf, baseWord: "стул", baseImage: "word_stul",
            prompt: "Чего много?",
            options: [
                .init(id: "0", text: "много стульев", isCorrect: true),
                .init(id: "1", text: "много стулов", isCorrect: false, isNearMiss: true),
                .init(id: "2", text: "много стулья", isCorrect: false)
            ],
            spokenForm: "Много стульев.", difficulty: 3, minAge: 6
        )
        let shuffled = WordFormationWorker.shufflingOptions(round)
        XCTAssertEqual(Set(shuffled.options.map(\.id)), Set(round.options.map(\.id)))
        XCTAssertEqual(shuffled.options.filter(\.isCorrect).count, 1)
    }
}

// MARK: - Corpus Tests

final class WordFormationCorpusTests: XCTestCase {

    func test_corpus_isNotEmpty() {
        XCTAssertFalse(WordFormationCorpus.allRounds.isEmpty)
    }

    func test_roundIds_areUnique() {
        let ids = WordFormationCorpus.allRounds.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_optionIds_areUnique() {
        let ids = WordFormationCorpus.allRounds.flatMap { $0.options.map(\.id) }
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_everyRound_hasExactlyOneCorrect_and2to4Options() {
        for round in WordFormationCorpus.allRounds {
            XCTAssertTrue((2...4).contains(round.options.count), "Раунд \(round.id) — не 2–4 варианта")
            XCTAssertEqual(round.options.filter(\.isCorrect).count, 1, "Раунд \(round.id) — не одна норма")
        }
    }

    func test_rounds_haveNonEmptyTextsBaseAndSpokenForm() {
        for round in WordFormationCorpus.allRounds {
            XCTAssertFalse(round.baseWord.isEmpty, "Пустая основа в \(round.id)")
            XCTAssertFalse(round.baseImage.isEmpty, "Пустой baseImage в \(round.id)")
            XCTAssertFalse(round.spokenForm.isEmpty, "Пустой spokenForm в \(round.id)")
            for option in round.options {
                XCTAssertFalse(option.text.isEmpty, "Пустой текст варианта в \(round.id)")
            }
        }
    }

    func test_baseImage_followsWordAssetConvention() {
        for round in WordFormationCorpus.allRounds {
            XCTAssertTrue(round.baseImage.hasPrefix("word_"), "baseImage \(round.baseImage) — не word_*")
        }
    }

    // MARK: Subtask coverage (DoD ≥ 20 на под-тип)

    func test_hasEnoughDiminutiveRounds() {
        XCTAssertGreaterThanOrEqual(WordFormationCorpus.rounds(for: .diminutive).count, 20)
    }

    func test_hasEnoughOneManyRounds() {
        XCTAssertGreaterThanOrEqual(WordFormationCorpus.rounds(for: .oneMany).count, 20)
    }

    func test_hasEnoughManyOfRounds() {
        XCTAssertGreaterThanOrEqual(WordFormationCorpus.rounds(for: .manyOf).count, 20)
    }

    // MARK: Age gate

    func test_ageGate_filtersByMinAge() {
        let age5 = WordFormationCorpus.rounds(maxAge: 5)
        XCTAssertTrue(age5.allSatisfy { $0.minAge <= 5 })
        let age7 = WordFormationCorpus.rounds(maxAge: 7)
        XCTAssertGreaterThanOrEqual(age7.count, age5.count, "Старшим доступно не меньше раундов")
    }

    func test_manyOf_minAgeAtLeast6() {
        for round in WordFormationCorpus.rounds(for: .manyOf) {
            XCTAssertGreaterThanOrEqual(round.minAge, 6, "manyOf \(round.id) — minAge ≥ 6")
        }
    }

    func test_easyRounds_areDifficultyOne() {
        let easy = WordFormationCorpus.easyRounds(maxAge: 7)
        XCTAssertFalse(easy.isEmpty)
        XCTAssertTrue(easy.allSatisfy { $0.difficulty <= 1 })
    }

    // MARK: Methodical content checks

    func test_distractors_areNotMarkedCorrect() {
        // Ровно один правильный; остальные — намеренные ошибки (дистракторы).
        for round in WordFormationCorpus.allRounds {
            let distractors = round.options.filter { !$0.isCorrect }
            XCTAssertGreaterThanOrEqual(distractors.count, 1, "Раунд \(round.id) без дистракторов")
        }
    }

    func test_subtasks_areKnown() {
        let subtasks = Set(WordFormationCorpus.allRounds.map(\.subtask))
        XCTAssertTrue(subtasks.isSubset(of: Set(FormationSubtask.allCases)))
    }
}
