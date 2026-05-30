@testable import HappySpeech
import XCTest

// MARK: - PhonemicListeningWorkerTests
//
// Фаза E, Волна 7. Покрывает сборку сессии фонематического анализа:
// сбалансированность по трём операциям (позиция/количество/синтез),
// методический порядок раундов, приоритет целевых звуков, fallback при сбое
// чтения профиля. Корпус — локальный (offline).

@MainActor
final class PhonemicListeningWorkerTests: XCTestCase {

    private func child(id: String = "c-1", sounds: [String]) -> ChildProfileDTO {
        ChildProfileDTO(id: id, name: "Тест", age: 7, targetSounds: sounds, parentId: "p-1")
    }

    // MARK: - Session structure

    func test_buildSession_producesNonEmptyRounds() async {
        let repo = MockChildRepository(children: [child(sounds: ["С"])])
        let sut = PhonemicListeningWorker(childRepository: repo)

        let response = await sut.buildSession(childId: "c-1")

        XCTAssertFalse(response.rounds.isEmpty)
    }

    func test_buildSession_operationsAreInMethodicalOrder() async {
        // Порядок: все position → все count → все synthesis.
        let repo = MockChildRepository(children: [child(sounds: [])])
        let sut = PhonemicListeningWorker(childRepository: repo)

        let response = await sut.buildSession(childId: "c-1")

        let order: [PhonemeOperation] = [.position, .count, .synthesis]
        var lastRank = -1
        for round in response.rounds {
            let rank = order.firstIndex(of: round.operation) ?? Int.max
            XCTAssertGreaterThanOrEqual(rank, lastRank,
                "Операции должны идти position → count → synthesis")
            lastRank = rank
        }
    }

    func test_buildSession_balancedAcrossOperations() async {
        let repo = MockChildRepository(children: [child(sounds: [])])
        let sut = PhonemicListeningWorker(childRepository: repo)

        let response = await sut.buildSession(childId: "c-1")

        let perOperation = PhonemicListeningCorpus.roundsPerSession / 3
        for op in PhonemeOperation.allCases {
            let count = response.rounds.filter { $0.operation == op }.count
            XCTAssertLessThanOrEqual(count, perOperation,
                "Каждой операции не больше perOperation раундов")
        }
    }

    func test_buildSession_roundIdsAreUnique() async {
        let repo = MockChildRepository(children: [child(sounds: ["Р"])])
        let sut = PhonemicListeningWorker(childRepository: repo)

        let response = await sut.buildSession(childId: "c-1")

        let ids = response.rounds.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "ID раундов должны быть уникальны")
    }

    func test_buildSession_roundIdEncodesOperationAndWord() async {
        let repo = MockChildRepository(children: [child(sounds: [])])
        let sut = PhonemicListeningWorker(childRepository: repo)

        let response = await sut.buildSession(childId: "c-1")

        for round in response.rounds {
            XCTAssertTrue(round.id.hasPrefix(round.operation.rawValue),
                "ID должен начинаться с rawValue операции")
            XCTAssertTrue(round.id.contains(round.word.id))
        }
    }

    // MARK: - Fallback

    func test_buildSession_repositoryFailure_stillBuildsFromFullCorpus() async {
        let repo = MockChildRepository(children: [])
        let sut = PhonemicListeningWorker(childRepository: repo)

        let response = await sut.buildSession(childId: "missing")

        XCTAssertFalse(response.rounds.isEmpty,
            "При сбое профиля используется полный корпус")
    }

    // MARK: - Corpus word selection logic

    func test_corpus_words_emptyTargetSounds_returnsFullPool() {
        let pool = PhonemicListeningCorpus.words(for: .position, targetSounds: [])
        XCTAssertEqual(pool.count, PhonemicListeningCorpus.positionWords.count)
    }

    func test_corpus_words_caseInsensitivePreferredFirst() {
        // Если есть достаточно слов целевого звука — они идут первыми.
        let target = "с"
        let pool = PhonemicListeningCorpus.words(for: .position, targetSounds: [target])
        let preferredCount = PhonemicListeningCorpus.positionWords
            .filter { $0.targetSound.uppercased() == "С" }.count
        let threshold = PhonemicListeningCorpus.roundsPerSession / 3
        if preferredCount >= threshold, let first = pool.first {
            XCTAssertEqual(first.targetSound.uppercased(), "С",
                "Слова целевого звука должны идти первыми при достаточном объёме")
        }
        // В любом случае пул не должен быть пустым.
        XCTAssertFalse(pool.isEmpty)
    }
}
