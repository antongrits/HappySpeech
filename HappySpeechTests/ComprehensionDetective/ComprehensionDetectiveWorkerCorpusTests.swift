@testable import HappySpeech
import XCTest

// MARK: - Worker Tier Resolution Tests (возрастной гейт)

@MainActor
final class ComprehensionDetectiveWorkerTierTests: XCTestCase {

    func test_ageGate_age5_allowsSimpleAndDouble() {
        // minAge: simple=5, double=5, triple=6 → cap для 5 = doubleInstruction.
        XCTAssertEqual(ComprehensionDetectiveWorker.ageAllowedTier(age: 5), .doubleInstruction)
    }

    func test_ageGate_age6_allowsUpToPreposition() {
        // triple=6, preposition=6, logical=7 → cap для 6 = withPreposition.
        XCTAssertEqual(ComprehensionDetectiveWorker.ageAllowedTier(age: 6), .withPreposition)
    }

    func test_ageGate_age7_allowsLogicalGrammatical() {
        XCTAssertEqual(ComprehensionDetectiveWorker.ageAllowedTier(age: 7), .logicalGrammatical)
    }

    func test_ageGate_age8_allowsLogicalGrammatical() {
        XCTAssertEqual(ComprehensionDetectiveWorker.ageAllowedTier(age: 8), .logicalGrammatical)
    }

    func test_resolveTier_capsPreferredAtAgeGate() {
        // 5-летке нельзя логико-грамматику, даже если просят.
        let tier = ComprehensionDetectiveWorker.resolveTier(preferredTier: .logicalGrammatical, age: 5)
        XCTAssertLessThanOrEqual(tier.rawValue, GrammarTier.doubleInstruction.rawValue)
    }

    func test_resolveTier_allowsLowerThanGate() {
        let tier = ComprehensionDetectiveWorker.resolveTier(preferredTier: .simple, age: 8)
        XCTAssertEqual(tier, .simple)
    }

    func test_resolveTier_nilUsesAgeGate() {
        XCTAssertEqual(
            ComprehensionDetectiveWorker.resolveTier(preferredTier: nil, age: 7),
            .logicalGrammatical
        )
    }
}

// MARK: - Worker Session Building Tests

@MainActor
final class ComprehensionDetectiveWorkerSessionTests: XCTestCase {

    private func makeWorker(age: Int, randomSource: @escaping () -> Double = { 0.0 }) -> ComprehensionDetectiveWorker {
        let child = ChildProfileDTO(
            id: "child-1", name: "Тест", age: age, targetSounds: ["Р"], parentId: "p-1"
        )
        return ComprehensionDetectiveWorker(
            childRepository: MockChildRepository(children: [child]),
            randomSource: randomSource
        )
    }

    func test_buildSession_age7_leadTierIsLogical_andRoundsFilled() async {
        let worker = makeWorker(age: 7)
        let response = await worker.buildSession(childId: "child-1", preferredTier: nil)
        XCTAssertEqual(response.leadTier, .logicalGrammatical)
        XCTAssertEqual(response.childAge, 7)
        XCTAssertEqual(response.rounds.count, ComprehensionDetectiveCorpus.roundsPerSession)
    }

    func test_buildSession_age5_capsLeadTier() async {
        let worker = makeWorker(age: 5)
        let response = await worker.buildSession(childId: "child-1", preferredTier: .logicalGrammatical)
        XCTAssertLessThanOrEqual(response.leadTier.rawValue, GrammarTier.doubleInstruction.rawValue)
        // Все раунды не превышают возрастной гейт.
        XCTAssertTrue(response.rounds.allSatisfy { $0.item.minAge <= 5 })
    }

    func test_buildSession_retroStart_beginsWithSimpleRounds() async {
        let worker = makeWorker(age: 7)
        let response = await worker.buildSession(childId: "child-1", preferredTier: .logicalGrammatical)
        XCTAssertGreaterThanOrEqual(response.rounds.count, 3)
        // Ретро-старт: первые 2 раунда — простые (одно поручение).
        XCTAssertEqual(response.rounds[0].item.tier, .simple)
        XCTAssertEqual(response.rounds[1].item.tier, .simple)
        // Дальше присутствуют более сложные уровни.
        XCTAssertTrue(response.rounds.contains { $0.item.tier.rawValue > GrammarTier.simple.rawValue })
    }

    func test_buildSession_simpleLead_staysWithinAgeGate() async {
        // Для лёгкого ведущего уровня ретро-старт не нужен, но для антифатигового
        // чередования основная часть может подмешивать соседний уровень — всё в
        // пределах возрастного гейта (для 5 лет: simple + doubleInstruction).
        let worker = makeWorker(age: 5)
        let response = await worker.buildSession(childId: "child-1", preferredTier: .simple)
        XCTAssertEqual(response.leadTier, .simple)
        XCTAssertTrue(response.rounds.allSatisfy { $0.item.minAge <= 5 })
        let allowed: Set<GrammarTier> = [.simple, .doubleInstruction]
        XCTAssertTrue(response.rounds.allSatisfy { allowed.contains($0.item.tier) })
    }

    func test_buildSession_avoidsConsecutiveSameTier() async {
        let worker = makeWorker(age: 7)
        let response = await worker.buildSession(childId: "child-1", preferredTier: .logicalGrammatical)
        var consecutive = 0
        for index in 1..<response.rounds.count
        where response.rounds[index].item.tier == response.rounds[index - 1].item.tier {
            consecutive += 1
        }
        // Антифатиговое чередование уровней (допускаем редкие повторы при бедном пуле).
        XCTAssertLessThanOrEqual(consecutive, 4)
    }

    func test_buildSession_noDuplicateItemsInSession() async {
        let worker = makeWorker(age: 7)
        let response = await worker.buildSession(childId: "child-1", preferredTier: .logicalGrammatical)
        let baseIds = response.rounds.map { $0.id.split(separator: "#").first.map(String.init) ?? $0.id }
        XCTAssertEqual(baseIds.count, Set(baseIds).count, "Один пункт не повторяется в сессии")
    }

    func test_buildSession_everyRoundHasFourPictures() async {
        let worker = makeWorker(age: 8)
        let response = await worker.buildSession(childId: "child-1", preferredTier: nil)
        for round in response.rounds {
            XCTAssertEqual(round.shuffledPictures.count, 4)
            // Правильная картинка остаётся среди перемешанных.
            XCTAssertTrue(round.shuffledPictures.contains { $0.id == round.item.correctPictureId })
        }
    }

    func test_buildSession_unknownChild_usesDefaultsAndStaysPlayable() async {
        let worker = ComprehensionDetectiveWorker(
            childRepository: MockChildRepository(children: []),
            randomSource: { 0.0 }
        )
        let response = await worker.buildSession(childId: "ghost", preferredTier: nil)
        XCTAssertFalse(response.rounds.isEmpty, "Сессия остаётся рабочей при отказе репозитория")
    }

    func test_shuffle_preservesMembership() {
        let worker = makeWorker(age: 6, randomSource: { 0.5 })
        let pictures = [
            DetectivePicture(id: "p1", symbolName: "a", label: "a"),
            DetectivePicture(id: "p2", symbolName: "b", label: "b"),
            DetectivePicture(id: "p3", symbolName: "c", label: "c"),
            DetectivePicture(id: "p4", symbolName: "d", label: "d")
        ]
        let shuffled = worker.shuffle(pictures)
        XCTAssertEqual(shuffled.count, 4)
        XCTAssertEqual(Set(shuffled.map(\.id)), Set(pictures.map(\.id)))
    }
}

// MARK: - Corpus Tests

final class ComprehensionDetectiveCorpusTests: XCTestCase {

    func test_corpus_loadsAtLeast120Items() {
        XCTAssertGreaterThanOrEqual(ComprehensionDetectiveCorpus.allItems.count, 120,
                                    "Корпус должен содержать ≥120 пунктов (F2-014)")
    }

    func test_corpus_loadsFullExpandedSet() {
        // После методического расширения (gap #2): 304 инструкции на 5 уровней.
        XCTAssertEqual(ComprehensionDetectiveCorpus.allItems.count, 304,
                       "Расширенный корпус должен содержать 304 инструкции")
    }

    func test_corpus_everyTierWellPopulated() {
        // Каждый уровень получил методическое наполнение (минимум 40 пунктов).
        for tier in GrammarTier.allCases {
            let count = ComprehensionDetectiveCorpus.items(for: tier).count
            XCTAssertGreaterThanOrEqual(count, 40,
                                        "Уровень \(tier) должен содержать ≥40 пунктов, найдено \(count)")
        }
    }

    func test_corpus_hasAllFiveTiers() {
        let tiers = Set(ComprehensionDetectiveCorpus.allItems.map(\.tier))
        XCTAssertEqual(tiers, Set(GrammarTier.allCases),
                       "Должны быть все 5 уровней грамматической сложности")
    }

    func test_everyItem_hasFourUniquePictures() {
        for item in ComprehensionDetectiveCorpus.allItems {
            XCTAssertEqual(item.pictures.count, 4, "Пункт \(item.id): не 4 картинки")
            let symbols = Set(item.pictures.map(\.symbolName))
            XCTAssertEqual(symbols.count, 4, "Пункт \(item.id): символы не уникальны")
        }
    }

    func test_correctPictureId_belongsToItemPictures() {
        for item in ComprehensionDetectiveCorpus.allItems {
            let ids = Set(item.pictures.map(\.id))
            XCTAssertTrue(ids.contains(item.correctPictureId),
                          "Пункт \(item.id): правильный id вне списка картинок")
        }
    }

    func test_idsAreUnique() {
        let ids = ComprehensionDetectiveCorpus.allItems.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_instructionsAndLabels_nonEmpty() {
        for item in ComprehensionDetectiveCorpus.allItems {
            XCTAssertFalse(item.instruction.isEmpty, "Пункт \(item.id) без инструкции")
            for picture in item.pictures {
                XCTAssertFalse(picture.label.isEmpty, "Пункт \(item.id): пустая подпись картинки")
            }
        }
    }

    func test_minAge_isValid() {
        for item in ComprehensionDetectiveCorpus.allItems {
            XCTAssertTrue((5...8).contains(item.minAge), "Пункт \(item.id): minAge=\(item.minAge) вне 5–8")
        }
    }

    func test_prepositionTier_hasSpatialInstructions() {
        // Уровень предлогов покрывает пространственные отношения.
        let items = ComprehensionDetectiveCorpus.items(for: .withPreposition)
        XCTAssertGreaterThanOrEqual(items.count, 15, "Нужно достаточно пунктов с предлогами")
        let joined = items.map(\.instruction).joined(separator: " ").lowercased()
        for preposition in ["на", "под", "над", "в ", "за ", "перед", "между", "около"] {
            XCTAssertTrue(joined.contains(preposition),
                          "Уровень предлогов должен покрывать «\(preposition.trimmingCharacters(in: .whitespaces))»")
        }
    }

    func test_logicalGrammaticalTier_hasInversions() {
        // Уровень логико-грамматики содержит инверсии («мама дочки» vs «дочку мамы»).
        let items = ComprehensionDetectiveCorpus.items(for: .logicalGrammatical)
        XCTAssertGreaterThanOrEqual(items.count, 15)
        let ids = Set(items.map(\.id))
        XCTAssertTrue(ids.contains("t5-mama-docha"), "Должна быть конструкция «маму дочки»")
        XCTAssertTrue(ids.contains("t5-docha-mamy"), "Должна быть инверсия «дочку мамы»")
    }

    func test_ageGate_filtersByMinAge() {
        let age5 = ComprehensionDetectiveCorpus.items(for: .simple, maxAge: 5)
        XCTAssertTrue(age5.allSatisfy { $0.minAge <= 5 })
        let allLevelsAge5 = ComprehensionDetectiveCorpus.availableTiers(maxAge: 5)
        // 5-летке логико-грамматика (minAge 7) недоступна.
        XCTAssertFalse(allLevelsAge5.contains(.logicalGrammatical))
        let allLevelsAge7 = ComprehensionDetectiveCorpus.availableTiers(maxAge: 7)
        XCTAssertTrue(allLevelsAge7.contains(.logicalGrammatical))
    }

    func test_roundsPerSession_isReasonable() {
        XCTAssertGreaterThanOrEqual(ComprehensionDetectiveCorpus.roundsPerSession, 6)
        XCTAssertLessThanOrEqual(ComprehensionDetectiveCorpus.roundsPerSession, 12)
    }
}
