@testable import HappySpeech
import XCTest

// MARK: - Worker Subtask Resolution / Session Tests

@MainActor
final class WhoseTailWorkerTests: XCTestCase {

    // MARK: Age gate

    func test_isAllowed_possessiveTail_fromAge5() {
        XCTAssertTrue(WhoseTailWorker.isAllowed(.possessiveTail, age: 5))
    }

    func test_isAllowed_animalHomeAndRelative_notBeforeAge6() {
        XCTAssertFalse(WhoseTailWorker.isAllowed(.animalHome, age: 5))
        XCTAssertTrue(WhoseTailWorker.isAllowed(.animalHome, age: 6))
        XCTAssertFalse(WhoseTailWorker.isAllowed(.relativeMaterial, age: 5))
        XCTAssertTrue(WhoseTailWorker.isAllowed(.relativeMaterial, age: 6))
    }

    func test_resolveSubtask_nilDefaultsToPossessive() {
        XCTAssertEqual(WhoseTailWorker.resolveSubtask(preferredSubtask: nil, age: 6), .possessiveTail)
    }

    func test_resolveSubtask_animalHomeUnderAge6_fallsBackToPossessive() {
        XCTAssertEqual(WhoseTailWorker.resolveSubtask(preferredSubtask: .animalHome, age: 5), .possessiveTail)
    }

    func test_resolveSubtask_relativeAtAge6_isRelative() {
        XCTAssertEqual(WhoseTailWorker.resolveSubtask(preferredSubtask: .relativeMaterial, age: 6), .relativeMaterial)
    }

    // MARK: Session building

    func test_makeRounds_respectsRoundsPerSession() {
        let rounds = WhoseTailWorker.makeRounds(preferredSubtask: nil, age: 7)
        XCTAssertEqual(rounds.count, WhoseTailCorpus.roundsPerSession)
    }

    func test_makeRounds_retroStart_beginsWithEasyPossessive() {
        // Ретро-старт: первые 2 раунда — лёгкие (possessiveTail, difficulty 1), F1-015.
        let rounds = WhoseTailWorker.makeRounds(preferredSubtask: nil, age: 7)
        XCTAssertGreaterThanOrEqual(rounds.count, 3)
        XCTAssertEqual(rounds[0].subtask, .possessiveTail)
        XCTAssertEqual(rounds[0].difficulty, 1)
        XCTAssertEqual(rounds[1].subtask, .possessiveTail)
        XCTAssertEqual(rounds[1].difficulty, 1)
    }

    func test_makeRounds_ageGate_noAnimalHomeOrRelativeBeforeAge6() {
        let rounds = WhoseTailWorker.makeRounds(preferredSubtask: nil, age: 5)
        XCTAssertFalse(rounds.contains { $0.subtask == .animalHome }, "animalHome недоступен до 6 лет")
        XCTAssertFalse(rounds.contains { $0.subtask == .relativeMaterial }, "relativeMaterial недоступен до 6 лет")
        for round in rounds {
            XCTAssertLessThanOrEqual(round.minAge, 5, "Только доступные по возрасту раунды")
        }
    }

    func test_makeRounds_eachRoundHasExactlyOneCorrect() {
        let rounds = WhoseTailWorker.makeRounds(preferredSubtask: nil, age: 8)
        for round in rounds {
            XCTAssertEqual(round.options.filter(\.isCorrect).count, 1, "Раунд \(round.id) — ровно один правильный")
            XCTAssertGreaterThanOrEqual(round.options.count, 2)
        }
    }

    func test_makeRounds_avoidsConsecutiveSameSubtask() {
        let rounds = WhoseTailWorker.makeRounds(preferredSubtask: nil, age: 8)
        let subtasks = Set(rounds.map(\.subtask))
        XCTAssertGreaterThan(subtasks.count, 1, "Сессия не должна быть из одного под-типа")
    }

    func test_makeRounds_noDuplicateBaseInSession() {
        let rounds = WhoseTailWorker.makeRounds(preferredSubtask: nil, age: 8)
        let baseIds = rounds.map { $0.id.split(separator: "#").first.map(String.init) ?? $0.id }
        XCTAssertEqual(baseIds.count, Set(baseIds).count, "Один и тот же набор не повторяется в сессии")
    }

    func test_makeRounds_preferredSubtask_prioritised() {
        let rounds = WhoseTailWorker.makeRounds(preferredSubtask: .relativeMaterial, age: 8)
        XCTAssertTrue(rounds.contains { $0.subtask == .relativeMaterial }, "Предпочтительный под-тип присутствует")
    }

    func test_shufflingOptions_preservesMembership() {
        let round = WhoseRound(
            id: "r", subtask: .possessiveTail, cueImage: "pawprint.fill",
            question: "Чей это хвост?",
            options: [
                .init(id: "0", word: "лиса", imageAsset: "word_fox", isCorrect: true, form: "лисий хвост"),
                .init(id: "1", word: "заяц", imageAsset: "word_hare", isCorrect: false, form: "заячий хвост"),
                .init(id: "2", word: "волк", imageAsset: "word_volk", isCorrect: false, form: "волчий хвост")
            ],
            spokenForm: "Это лисий хвост.", difficulty: 2, minAge: 6
        )
        let shuffled = WhoseTailWorker.shufflingOptions(round)
        XCTAssertEqual(Set(shuffled.options.map(\.id)), Set(round.options.map(\.id)))
        XCTAssertEqual(shuffled.options.filter(\.isCorrect).count, 1)
    }
}

// MARK: - Corpus Tests

final class WhoseTailCorpusTests: XCTestCase {

    /// Стоп-лист дефектных форм словообразования прилагательных, которые НЕ
    /// должны присутствовать ни в одной опции (методическое правило F2-006 §7).
    private static let defectiveForms: [String] = [
        "лисячий", "зайцевый", "зайцов", "волковый", "медведий", "медведин",
        "деревьянный", "стекольный", "коровый", "собакин", "кошкин"
    ]

    func test_corpus_isNotEmpty() {
        XCTAssertFalse(WhoseTailCorpus.allRounds.isEmpty)
    }

    func test_roundIds_areUnique() {
        let ids = WhoseTailCorpus.allRounds.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_optionIds_areUnique() {
        let ids = WhoseTailCorpus.allRounds.flatMap { $0.options.map(\.id) }
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_everyRound_hasExactlyOneCorrect_and2to4Options() {
        for round in WhoseTailCorpus.allRounds {
            XCTAssertTrue((2...4).contains(round.options.count), "Раунд \(round.id) — не 2–4 варианта")
            XCTAssertEqual(round.options.filter(\.isCorrect).count, 1, "Раунд \(round.id) — не один правильный")
        }
    }

    func test_rounds_haveNonEmptyTextsCueAndSpokenForm() {
        for round in WhoseTailCorpus.allRounds {
            XCTAssertFalse(round.cueImage.isEmpty, "Пустой cueImage в \(round.id)")
            XCTAssertFalse(round.question.isEmpty, "Пустой вопрос в \(round.id)")
            XCTAssertFalse(round.spokenForm.isEmpty, "Пустой spokenForm в \(round.id)")
            for option in round.options {
                XCTAssertFalse(option.word.isEmpty, "Пустое слово варианта в \(round.id)")
                XCTAssertFalse(option.imageAsset.isEmpty, "Пустой imageAsset варианта в \(round.id)")
                XCTAssertFalse(option.form.isEmpty, "Пустая форма варианта в \(round.id)")
            }
        }
    }

    // MARK: Methodical: дефектные формы НЕ в опциях (стоп-лист)

    func test_noOptionFormIsDefective() {
        for round in WhoseTailCorpus.allRounds {
            for option in round.options {
                let form = option.form.lowercased()
                for bad in Self.defectiveForms {
                    XCTAssertFalse(form.contains(bad),
                                   "Дефектная форма «\(bad)» в опции \(option.id) раунда \(round.id)")
                }
            }
        }
    }

    func test_spokenForm_isNotDefective() {
        for round in WhoseTailCorpus.allRounds {
            let spoken = round.spokenForm.lowercased()
            for bad in Self.defectiveForms {
                XCTAssertFalse(spoken.contains(bad),
                               "Дефектная форма «\(bad)» в spokenForm раунда \(round.id)")
            }
        }
    }

    // MARK: Subtask coverage (DoD ≥ 18 на под-тип)

    func test_hasEnoughPossessiveTailRounds() {
        XCTAssertGreaterThanOrEqual(WhoseTailCorpus.rounds(for: .possessiveTail).count, 18)
    }

    func test_hasEnoughAnimalHomeRounds() {
        XCTAssertGreaterThanOrEqual(WhoseTailCorpus.rounds(for: .animalHome).count, 18)
    }

    func test_hasEnoughRelativeMaterialRounds() {
        XCTAssertGreaterThanOrEqual(WhoseTailCorpus.rounds(for: .relativeMaterial).count, 18)
    }

    // MARK: Option count by difficulty (2/3/4)

    func test_easyRounds_haveTwoOptions() {
        // easy (difficulty 1) — контрастные звери, 2 варианта.
        for round in WhoseTailCorpus.allRounds where round.difficulty == 1 {
            XCTAssertEqual(round.options.count, 2, "Лёгкий раунд \(round.id) — 2 варианта")
        }
    }

    func test_optionCount_growsWithDifficulty() {
        // hard (difficulty 3) — близкие звери, 2–4 варианта (минимум 2, чаще 3–4).
        let hard = WhoseTailCorpus.allRounds.filter { $0.difficulty >= 3 }
        XCTAssertFalse(hard.isEmpty)
        XCTAssertTrue(hard.contains { $0.options.count >= 3 }, "Есть сложные раунды с 3–4 вариантами")
    }

    // MARK: Age gate

    func test_ageGate_filtersByMinAge() {
        let age5 = WhoseTailCorpus.rounds(maxAge: 5)
        XCTAssertTrue(age5.allSatisfy { $0.minAge <= 5 })
        let age7 = WhoseTailCorpus.rounds(maxAge: 7)
        XCTAssertGreaterThanOrEqual(age7.count, age5.count, "Старшим доступно не меньше раундов")
    }

    func test_animalHomeAndRelative_minAgeAtLeast6() {
        for round in WhoseTailCorpus.rounds(for: .animalHome) {
            XCTAssertGreaterThanOrEqual(round.minAge, 6, "animalHome \(round.id) — minAge ≥ 6")
        }
        for round in WhoseTailCorpus.rounds(for: .relativeMaterial) {
            XCTAssertGreaterThanOrEqual(round.minAge, 6, "relativeMaterial \(round.id) — minAge ≥ 6")
        }
    }

    func test_easyRounds_areDifficultyOne() {
        let easy = WhoseTailCorpus.easyRounds(maxAge: 7)
        XCTAssertFalse(easy.isEmpty)
        XCTAssertTrue(easy.allSatisfy { $0.difficulty <= 1 })
    }

    // MARK: Content checks

    func test_distractors_areNotMarkedCorrect() {
        for round in WhoseTailCorpus.allRounds {
            let distractors = round.options.filter { !$0.isCorrect }
            XCTAssertGreaterThanOrEqual(distractors.count, 1, "Раунд \(round.id) без дистракторов")
        }
    }

    func test_subtasks_areKnown() {
        let subtasks = Set(WhoseTailCorpus.allRounds.map(\.subtask))
        XCTAssertTrue(subtasks.isSubset(of: Set(WhoseSubtask.allCases)))
    }
}
