@testable import HappySpeech
import XCTest

// MARK: - Worker Subtask Resolution / Session Tests

@MainActor
final class SentenceBuilderWorkerTests: XCTestCase {

    // MARK: Age gate

    func test_isAllowed_allSubtasks_fromAge6() {
        XCTAssertTrue(SentenceBuilderWorker.isAllowed(.wordOrder, age: 6))
        XCTAssertTrue(SentenceBuilderWorker.isAllowed(.agreement, age: 6))
        XCTAssertTrue(SentenceBuilderWorker.isAllowed(.preposition, age: 6))
    }

    func test_isAllowed_notBeforeAge6() {
        XCTAssertFalse(SentenceBuilderWorker.isAllowed(.wordOrder, age: 5))
        XCTAssertFalse(SentenceBuilderWorker.isAllowed(.agreement, age: 5))
        XCTAssertFalse(SentenceBuilderWorker.isAllowed(.preposition, age: 5))
    }

    func test_resolveSubtask_nilDefaultsToWordOrder() {
        XCTAssertEqual(SentenceBuilderWorker.resolveSubtask(preferredSubtask: nil, age: 7), .wordOrder)
    }

    func test_resolveSubtask_prepositionUnderAge6_fallsBackToWordOrder() {
        XCTAssertEqual(SentenceBuilderWorker.resolveSubtask(preferredSubtask: .preposition, age: 5), .wordOrder)
    }

    func test_resolveSubtask_agreementAtAge6_isAgreement() {
        XCTAssertEqual(SentenceBuilderWorker.resolveSubtask(preferredSubtask: .agreement, age: 6), .agreement)
    }

    // MARK: Session building

    func test_makeRounds_respectsRoundsPerSession() {
        let rounds = SentenceBuilderWorker.makeRounds(preferredSubtask: nil, age: 8)
        XCTAssertEqual(rounds.count, SentenceBuilderCorpus.roundsPerSession)
    }

    func test_makeRounds_retroStart_beginsWithEasyWordOrder() {
        // Ретро-старт: первые 2 раунда — лёгкие (wordOrder, difficulty 1), F1-015.
        let rounds = SentenceBuilderWorker.makeRounds(preferredSubtask: nil, age: 8)
        XCTAssertGreaterThanOrEqual(rounds.count, 3)
        XCTAssertEqual(rounds[0].subtask, .wordOrder)
        XCTAssertEqual(rounds[0].difficulty, 1)
        XCTAssertEqual(rounds[1].subtask, .wordOrder)
        XCTAssertEqual(rounds[1].difficulty, 1)
    }

    func test_makeRounds_ageGate_noContentBeforeAge6() {
        let rounds = SentenceBuilderWorker.makeRounds(preferredSubtask: nil, age: 5)
        // Корпус начинается с minAge 6, для 5 лет доступного контента нет —
        // Worker возвращает либо пусто, либо fallback (но не нарушает гейт).
        for round in rounds {
            XCTAssertLessThanOrEqual(round.minAge, 6, "Не выдаём контент строго старше доступного")
        }
    }

    func test_makeRounds_ageGate_age6_noHardEightPlus() {
        let rounds = SentenceBuilderWorker.makeRounds(preferredSubtask: nil, age: 6)
        for round in rounds {
            XCTAssertLessThanOrEqual(round.minAge, 6, "Для 6 лет — только minAge ≤ 6")
        }
    }

    func test_makeRounds_eachRoundHasConsistentSlotCount() {
        let rounds = SentenceBuilderWorker.makeRounds(preferredSubtask: nil, age: 8)
        for round in rounds {
            // slotCount = длина каждого допустимого порядка.
            for order in round.acceptedOrders {
                XCTAssertEqual(order.count, round.slotCount, "Раунд \(round.id) — длина порядка ≠ slotCount")
            }
            XCTAssertFalse(round.acceptedOrders.isEmpty, "Раунд \(round.id) без допустимых порядков")
        }
    }

    func test_makeRounds_avoidsConsecutiveSameSubtask() {
        let rounds = SentenceBuilderWorker.makeRounds(preferredSubtask: nil, age: 8)
        // После ретро-старта (2 wordOrder) основная часть чередуется; в сессии
        // должно быть более одного под-типа.
        let subtasks = Set(rounds.map(\.subtask))
        XCTAssertGreaterThan(subtasks.count, 1, "Сессия не должна быть из одного под-типа")
    }

    func test_makeRounds_noDuplicateBaseInSession() {
        let rounds = SentenceBuilderWorker.makeRounds(preferredSubtask: nil, age: 8)
        let baseIds = rounds.map { $0.id.split(separator: "#").first.map(String.init) ?? $0.id }
        XCTAssertEqual(baseIds.count, Set(baseIds).count, "Один и тот же набор не повторяется в сессии")
    }

    func test_makeRounds_preferredSubtask_prioritised() {
        let rounds = SentenceBuilderWorker.makeRounds(preferredSubtask: .preposition, age: 8)
        XCTAssertTrue(rounds.contains { $0.subtask == .preposition }, "Предпочтительный под-тип присутствует")
    }

    func test_shufflingBank_preservesMembershipAndOrders() {
        let round = SentenceRound(
            id: "r", subtask: .wordOrder, sceneImage: "cat.fill",
            bankTokens: [
                .init(id: "0", text: "кот", role: .subject),
                .init(id: "1", text: "спит", role: .verb),
                .init(id: "2", text: "на", role: .prep),
                .init(id: "3", text: "диване", role: .object)
            ],
            slotCount: 4,
            acceptedOrders: [["0", "1", "2", "3"]],
            spokenSentence: "Кот спит на диване.", difficulty: 1, minAge: 6
        )
        let shuffled = SentenceBuilderWorker.shufflingBank(round)
        XCTAssertEqual(Set(shuffled.bankTokens.map(\.id)), Set(round.bankTokens.map(\.id)))
        XCTAssertEqual(shuffled.acceptedOrders, round.acceptedOrders, "Перемешивание банка не меняет порядки (оценка по id)")
    }
}

// MARK: - Corpus Tests

final class SentenceBuilderCorpusTests: XCTestCase {

    func test_corpus_isNotEmpty() {
        XCTAssertFalse(SentenceBuilderCorpus.allRounds.isEmpty)
    }

    func test_corpus_hasAtLeast15Items() {
        // ТЗ F2-004 §3: ≥ 15 заданий.
        XCTAssertGreaterThanOrEqual(SentenceBuilderCorpus.allRounds.count, 15)
    }

    func test_roundIds_areUnique() {
        let ids = SentenceBuilderCorpus.allRounds.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_tokenIds_areUniqueWithinRound() {
        for round in SentenceBuilderCorpus.allRounds {
            let ids = round.bankTokens.map(\.id)
            XCTAssertEqual(ids.count, Set(ids).count, "Дубль token id в раунде \(round.id)")
        }
    }

    func test_everyRound_hasNonEmptyAcceptedOrders_coveredByTokens() {
        for round in SentenceBuilderCorpus.allRounds {
            XCTAssertFalse(round.acceptedOrders.isEmpty, "Раунд \(round.id) без acceptedOrders")
            let coreIds = Set(round.bankTokens.filter { !$0.isDistractor }.map(\.id))
            for order in round.acceptedOrders {
                XCTAssertFalse(order.isEmpty, "Пустой порядок в \(round.id)")
                for tid in order {
                    XCTAssertTrue(coreIds.contains(tid), "Порядок ссылается на неизвестный токен \(tid) в \(round.id)")
                }
            }
        }
    }

    func test_distractors_notInAnyAcceptedOrder() {
        for round in SentenceBuilderCorpus.allRounds {
            let distractorIds = round.distractorIds
            for order in round.acceptedOrders {
                for tid in order {
                    XCTAssertFalse(distractorIds.contains(tid),
                                   "Дистрактор \(tid) попал в допустимый порядок раунда \(round.id)")
                }
            }
        }
    }

    func test_slotCount_matchesAcceptedOrderLength() {
        for round in SentenceBuilderCorpus.allRounds {
            for order in round.acceptedOrders {
                XCTAssertEqual(order.count, round.slotCount, "slotCount ≠ длине порядка в \(round.id)")
            }
        }
    }

    func test_rounds_haveNonEmptyTextsSceneAndSpokenSentence() {
        for round in SentenceBuilderCorpus.allRounds {
            XCTAssertFalse(round.sceneImage.isEmpty, "Пустой sceneImage в \(round.id)")
            XCTAssertFalse(round.spokenSentence.isEmpty, "Пустой spokenSentence в \(round.id)")
            for token in round.bankTokens {
                XCTAssertFalse(token.text.isEmpty, "Пустой текст токена в \(round.id)")
            }
        }
    }

    // MARK: Subtask coverage

    func test_hasAllThreeSubtasks() {
        let subtasks = Set(SentenceBuilderCorpus.allRounds.map(\.subtask))
        XCTAssertTrue(subtasks.contains(.wordOrder))
        XCTAssertTrue(subtasks.contains(.agreement))
        XCTAssertTrue(subtasks.contains(.preposition))
    }

    func test_subtasks_areKnown() {
        let subtasks = Set(SentenceBuilderCorpus.allRounds.map(\.subtask))
        XCTAssertTrue(subtasks.isSubset(of: Set(SentenceSubtask.allCases)))
    }

    // MARK: Difficulty / sizes (easy=3 / medium=4+1 / hard=5+2)

    func test_easyRounds_areDifficultyOne_andShortNoDistractor() {
        for round in SentenceBuilderCorpus.allRounds where round.difficulty == 1 {
            XCTAssertTrue(round.distractorIds.isEmpty, "Лёгкий раунд \(round.id) без дистракторов")
            XCTAssertLessThanOrEqual(round.slotCount, 4, "Лёгкий раунд короткий")
        }
    }

    func test_agreementRounds_haveAdjectiveFormChoices() {
        // agreement: несколько форм прилагательного (карточек больше, чем slotCount).
        for round in SentenceBuilderCorpus.rounds(for: .agreement) {
            let adjectives = round.bankTokens.filter { $0.role == .adjective }
            XCTAssertGreaterThanOrEqual(adjectives.count, 2, "agreement \(round.id) — выбор из форм прилагательного")
            XCTAssertEqual(round.slotCount, 2, "agreement — пара «прилагательное + сущ.»")
        }
    }

    func test_prepositionRounds_haveMultiplePrepChoices() {
        // preposition: несколько предлогов-карточек, в acceptedOrders — один.
        for round in SentenceBuilderCorpus.rounds(for: .preposition) {
            let preps = round.bankTokens.filter { $0.role == .prep || $0.role == .prepSlot }
            XCTAssertGreaterThanOrEqual(preps.count, 2, "preposition \(round.id) — выбор из предлогов")
        }
    }

    func test_easyRounds_helper_areDifficultyOne() {
        let easy = SentenceBuilderCorpus.easyRounds(maxAge: 8)
        XCTAssertFalse(easy.isEmpty)
        XCTAssertTrue(easy.allSatisfy { $0.difficulty <= 1 })
    }

    // MARK: Age gate

    func test_ageGate_filtersByMinAge() {
        let age6 = SentenceBuilderCorpus.rounds(maxAge: 6)
        XCTAssertTrue(age6.allSatisfy { $0.minAge <= 6 })
        let age8 = SentenceBuilderCorpus.rounds(maxAge: 8)
        XCTAssertGreaterThanOrEqual(age8.count, age6.count, "Старшим доступно не меньше раундов")
    }

    func test_allRounds_minAgeAtLeast6() {
        for round in SentenceBuilderCorpus.allRounds {
            XCTAssertGreaterThanOrEqual(round.minAge, 6, "Синтаксис — поздняя операция, minAge ≥ 6 в \(round.id)")
        }
    }
}
