@testable import HappySpeech
import XCTest

// MARK: - SoundTrafficLightWorkerTests
//
// Фаза E, Волна 8. Покрывает buildSession: подбор релевантной пары по целевым
// звукам ребёнка (recommendedPair), сбор сбалансированного перемешанного набора
// раундов (makeRounds: половина из A, половина из B, корректная разметка
// belongsToA, уникальные id, верхняя граница roundsPerSession), fallback при
// сбое профиля. Плюс чистая логика корпуса recommendedPair.

@MainActor
final class SoundTrafficLightWorkerTests: XCTestCase {

    /// Стор, фиксирующий уровень СЛОВО — эти тесты проверяют именно сборку
    /// словесных раундов (balance / belongsToA / id-схема).
    private final class FixedWordLevelStore: DifferentiationProgressStoring {
        func progress(childId: String, pairId: String) -> DifferentiationProgress {
            DifferentiationProgress(level: .word)
        }
        func save(_ progress: DifferentiationProgress, childId: String, pairId: String) {}
        func clear(childId: String) {}
    }

    private func child(id: String = "c-1", sounds: [String]) -> ChildProfileDTO {
        ChildProfileDTO(id: id, name: "Тест", age: 7, targetSounds: sounds, parentId: "p-1")
    }

    private func makeSUT(children: [ChildProfileDTO]) -> SoundTrafficLightWorker {
        SoundTrafficLightWorker(
            childRepository: MockChildRepository(children: children),
            progressStore: FixedWordLevelStore()
        )
    }

    // MARK: - buildSession: непустота и баланс

    func test_buildSession_producesRounds() async {
        let sut = makeSUT(children: [child(sounds: ["С"])])
        let response = await sut.buildSession(childId: "c-1")
        XCTAssertFalse(response.rounds.isEmpty)
    }

    func test_buildSession_roundCountWithinSessionLimit() async {
        let sut = makeSUT(children: [child(sounds: ["С"])])
        let response = await sut.buildSession(childId: "c-1")
        // makeRounds берёт по half = roundsPerSession/2 из каждой половины.
        XCTAssertLessThanOrEqual(response.rounds.count,
                                 SoundTrafficLightCorpus.roundsPerSession)
    }

    func test_buildSession_roundIdsAreUnique() async {
        let sut = makeSUT(children: [child(sounds: ["С"])])
        let response = await sut.buildSession(childId: "c-1")
        let ids = response.rounds.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_buildSession_roundIdEncodesGarageSide() async {
        let sut = makeSUT(children: [child(sounds: ["С"])])
        let response = await sut.buildSession(childId: "c-1")
        for round in response.rounds {
            // id-схема: "a-<word>" для A, "b-<word>" для B.
            if round.belongsToA {
                XCTAssertTrue(round.id.hasPrefix("a-"), "Слово A → id с префиксом a-")
            } else {
                XCTAssertTrue(round.id.hasPrefix("b-"), "Слово B → id с префиксом b-")
            }
        }
    }

    func test_buildSession_roundWordsBelongToTheirGarage() async {
        let sut = makeSUT(children: [child(sounds: ["С"])])
        let response = await sut.buildSession(childId: "c-1")
        let pair = response.pair
        for round in response.rounds {
            if round.belongsToA {
                XCTAssertTrue(pair.wordsA.contains(round.word),
                              "Слово «\(round.word)» помечено как A, но его нет в wordsA")
            } else {
                XCTAssertTrue(pair.wordsB.contains(round.word),
                              "Слово «\(round.word)» помечено как B, но его нет в wordsB")
            }
        }
    }

    func test_buildSession_roundsAreBalancedAcrossGarages() async throws {
        // Если в каждой половине достаточно слов, набор сбалансирован (|A|-|B| ≤ 1).
        let sut = makeSUT(children: [child(sounds: ["С"])])
        let response = await sut.buildSession(childId: "c-1")
        let pair = response.pair
        let half = SoundTrafficLightCorpus.roundsPerSession / 2
        guard pair.wordsA.count >= half, pair.wordsB.count >= half else {
            throw XCTSkip("Недостаточно слов в паре для проверки строгого баланса")
        }
        let aCount = response.rounds.filter(\.belongsToA).count
        let bCount = response.rounds.count - aCount
        XCTAssertEqual(aCount, bCount, "Набор сбалансирован по гаражам")
    }

    // MARK: - Pair selection

    func test_buildSession_picksPairMatchingChildSound() async {
        // Если у пары есть совпадение по soundA/soundB — она и выбирается.
        let sut = makeSUT(children: [child(sounds: ["С"])])
        let response = await sut.buildSession(childId: "c-1")
        let pair = response.pair
        XCTAssertTrue(pair.soundA == "С" || pair.soundB == "С"
                      || pair.id == SoundTrafficLightCorpus.pairs.first?.id,
                      "Выбрана релевантная либо базовая пара")
    }

    func test_buildSession_missingChild_usesDefaultPair() async {
        // Сбой профиля → targetSounds = [] → recommendedPair = первая пара.
        let sut = makeSUT(children: [])
        let response = await sut.buildSession(childId: "missing")
        XCTAssertFalse(response.rounds.isEmpty)
        XCTAssertEqual(response.pair.id, SoundTrafficLightCorpus.pairs.first?.id)
    }

    // MARK: - SoundTrafficLightCorpus.recommendedPair (pure)

    func test_corpus_recommendedPair_emptyTargets_returnsFirstPair() {
        let pair = SoundTrafficLightCorpus.recommendedPair(for: [])
        XCTAssertEqual(pair.id, SoundTrafficLightCorpus.pairs.first?.id)
    }

    func test_corpus_recommendedPair_unknownSound_returnsFirstPair() {
        let pair = SoundTrafficLightCorpus.recommendedPair(for: ["Я"])
        XCTAssertEqual(pair.id, SoundTrafficLightCorpus.pairs.first?.id)
    }

    func test_corpus_recommendedPair_matchesContainedSound() {
        // Берём звук из реально существующей пары и проверяем, что выбор содержит его.
        guard let target = SoundTrafficLightCorpus.pairs.first?.soundB else {
            return XCTFail("Корпус пар пуст")
        }
        let pair = SoundTrafficLightCorpus.recommendedPair(for: [target])
        XCTAssertTrue(pair.soundA == target || pair.soundB == target)
    }

    func test_corpus_pair_byId_roundTrips() {
        guard let any = SoundTrafficLightCorpus.pairs.first else {
            return XCTFail("Корпус пар пуст")
        }
        XCTAssertEqual(SoundTrafficLightCorpus.pair(forId: any.id)?.id, any.id)
        XCTAssertNil(SoundTrafficLightCorpus.pair(forId: "no-such-pair"))
    }
}
