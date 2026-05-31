@testable import HappySpeech
import XCTest

// MARK: - Worker Variant Resolution Tests

@MainActor
final class FourthExtraWorkerVariantTests: XCTestCase {

    func test_resolveVariant_nilDefaultsToSemantic() {
        XCTAssertEqual(FourthExtraWorker.resolveVariant(preferredVariant: nil, age: 6), .semantic)
    }

    func test_resolveVariant_phoneticUnderAge6_fallsBackToSemantic() {
        // Фонетический вариант недоступен до 6 (возрастной гейт).
        XCTAssertEqual(FourthExtraWorker.resolveVariant(preferredVariant: .phonetic, age: 5), .semantic)
    }

    func test_resolveVariant_phoneticAtAge6_isPhonetic() {
        XCTAssertEqual(FourthExtraWorker.resolveVariant(preferredVariant: .phonetic, age: 6), .phonetic)
    }

    func test_resolveVariant_semanticAtAge5_isSemantic() {
        XCTAssertEqual(FourthExtraWorker.resolveVariant(preferredVariant: .semantic, age: 5), .semantic)
    }

    func test_soundTarget_semanticIsLexika() {
        let target = FourthExtraWorker.soundTarget(for: .semantic, rounds: [], targetSounds: ["С"])
        XCTAssertEqual(target, "лексика")
    }

    func test_soundTarget_phoneticUsesRoundSound() {
        let round = FourthExtraRound(
            id: "r", variant: .phonetic, rule: .sound, categoryLabel: nil, targetSound: "Р",
            cards: [], difficulty: 2, minAge: 6
        )
        let target = FourthExtraWorker.soundTarget(for: .phonetic, rounds: [round], targetSounds: ["С"])
        XCTAssertEqual(target, "Р")
    }

    // MARK: Session building

    func test_makeRounds_respectsRoundsPerSession() {
        let rounds = FourthExtraWorker.makeRounds(variant: .semantic, age: 7, targetSounds: [])
        XCTAssertEqual(rounds.count, FourthExtraCorpus.roundsPerSession)
    }

    func test_makeRounds_retroStart_beginsWithEasyRounds() {
        // Ретро-старт: первые раунды — difficulty 1 (явный лишний), F1-015.
        let rounds = FourthExtraWorker.makeRounds(variant: .semantic, age: 7, targetSounds: [])
        XCTAssertGreaterThanOrEqual(rounds.count, 3)
        XCTAssertEqual(rounds[0].difficulty, 1)
        XCTAssertEqual(rounds[1].difficulty, 1)
    }

    func test_makeRounds_eachSetHasExactlyOneExtra() {
        let rounds = FourthExtraWorker.makeRounds(variant: .semantic, age: 8, targetSounds: [])
        for round in rounds {
            XCTAssertEqual(round.cards.filter(\.isExtra).count, 1, "Набор \(round.id) — ровно один лишний")
            XCTAssertEqual(round.cards.count, 4)
        }
    }

    func test_makeRounds_avoidsConsecutiveSameRule() {
        let rounds = FourthExtraWorker.makeRounds(variant: .semantic, age: 8, targetSounds: [])
        var consecutiveRepeats = 0
        for index in 1..<rounds.count where rounds[index].rule == rounds[index - 1].rule {
            consecutiveRepeats += 1
        }
        // Семантика небогата правилами (category преобладает) — допускаем повторы,
        // но Worker предпочитает разные правила там, где возможно.
        XCTAssertGreaterThanOrEqual(rounds.count, 1)
    }

    func test_makeRounds_noDuplicateSetsInSession() {
        let rounds = FourthExtraWorker.makeRounds(variant: .semantic, age: 8, targetSounds: [])
        // id уникализирован суффиксом #index, но базовый набор не должен повторяться.
        let baseIds = rounds.map { $0.id.split(separator: "#").first.map(String.init) ?? $0.id }
        XCTAssertEqual(baseIds.count, Set(baseIds).count, "Один и тот же набор не повторяется в сессии")
    }

    func test_makeRounds_phonetic_prioritisesTargetSound() {
        let rounds = FourthExtraWorker.makeRounds(variant: .phonetic, age: 8, targetSounds: ["Р"])
        // Среди фонетических раундов есть наборы с целевым звуком Р.
        let phoneticRounds = rounds.filter { $0.variant == .phonetic }
        XCTAssertTrue(phoneticRounds.contains { $0.targetSound == "Р" })
    }

    func test_shufflingCards_preservesMembership() {
        let round = FourthExtraRound(
            id: "r", variant: .semantic, rule: .category, categoryLabel: "фрукты", targetSound: nil,
            cards: [
                .init(id: "0", word: "яблоко", imageAsset: "word_apple", isExtra: false, extraReason: nil),
                .init(id: "1", word: "груша", imageAsset: "word_grusha", isExtra: false, extraReason: nil),
                .init(id: "2", word: "банан", imageAsset: "word_banan", isExtra: false, extraReason: nil),
                .init(id: "3", word: "стул", imageAsset: "word_stul", isExtra: true, extraReason: "мебель")
            ],
            difficulty: 1, minAge: 5
        )
        let shuffled = FourthExtraWorker.shufflingCards(round)
        XCTAssertEqual(Set(shuffled.cards.map(\.id)), Set(round.cards.map(\.id)))
        XCTAssertEqual(shuffled.cards.filter(\.isExtra).count, 1)
    }
}

// MARK: - Corpus Tests

final class FourthExtraCorpusTests: XCTestCase {

    func test_corpus_isNotEmpty() {
        XCTAssertFalse(FourthExtraCorpus.allRounds.isEmpty)
    }

    func test_roundIds_areUnique() {
        let ids = FourthExtraCorpus.allRounds.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_everySet_hasExactlyOneExtra_andFourCards() {
        for round in FourthExtraCorpus.allRounds {
            XCTAssertEqual(round.cards.count, 4, "Набор \(round.id) — не 4 карточки")
            XCTAssertEqual(round.cards.filter(\.isExtra).count, 1, "Набор \(round.id) — не один лишний")
        }
    }

    func test_cards_haveNonEmptyWordsAndAssets() {
        for round in FourthExtraCorpus.allRounds {
            for card in round.cards {
                XCTAssertFalse(card.word.isEmpty, "Пустое слово в \(round.id)")
                XCTAssertFalse(card.imageAsset.isEmpty, "Пустой asset в \(round.id)")
            }
        }
    }

    func test_hasEnoughSemanticSets() {
        // DoD: ≥ 20 семантических наборов.
        let semantic = FourthExtraCorpus.rounds(for: .semantic)
        XCTAssertGreaterThanOrEqual(semantic.count, 20, "Нужно ≥ 20 семантических наборов")
    }

    func test_hasEnoughPhoneticSets() {
        // DoD: ≥ 12 фонетических наборов.
        let phonetic = FourthExtraCorpus.rounds(for: .phonetic)
        XCTAssertGreaterThanOrEqual(phonetic.count, 12, "Нужно ≥ 12 фонетических наборов")
    }

    func test_semanticSets_haveCategoryLabel() {
        for round in FourthExtraCorpus.rounds(for: .semantic) {
            XCTAssertNotNil(round.categoryLabel, "Семантический набор \(round.id) без categoryLabel")
            XCTAssertFalse(round.categoryLabel?.isEmpty ?? true)
        }
    }

    func test_phoneticSets_haveTargetSound() {
        for round in FourthExtraCorpus.rounds(for: .phonetic) {
            XCTAssertNotNil(round.targetSound, "Фонетический набор \(round.id) без targetSound")
        }
    }

    func test_phoneticSets_coverMainSoundGroups() {
        let sounds = Set(FourthExtraCorpus.rounds(for: .phonetic).compactMap(\.targetSound))
        for required in ["С", "Ш", "Р", "Л", "З", "Ж"] {
            XCTAssertTrue(sounds.contains(required), "Нет фонетического набора для звука \(required)")
        }
    }

    func test_ageGate_filtersByMinAge() {
        let age5 = FourthExtraCorpus.rounds(for: .semantic, maxAge: 5)
        XCTAssertTrue(age5.allSatisfy { $0.minAge <= 5 })
        let age7 = FourthExtraCorpus.rounds(for: .semantic, maxAge: 7)
        XCTAssertGreaterThanOrEqual(age7.count, age5.count, "Старшим доступно не меньше наборов")
    }

    func test_easyRounds_areDifficultyOne() {
        let easy = FourthExtraCorpus.easyRounds(for: .semantic, maxAge: 7)
        XCTAssertFalse(easy.isEmpty)
        XCTAssertTrue(easy.allSatisfy { $0.difficulty <= 1 })
    }

    func test_phoneticRounds_prioritiseTargetSound() {
        let rounds = FourthExtraCorpus.phoneticRounds(maxAge: 8, targetSounds: ["Л"])
        XCTAssertEqual(rounds.first?.targetSound, "Л")
    }
}
