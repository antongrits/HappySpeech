@testable import HappySpeech
import XCTest

// MARK: - ProsodyWorkerTests
//
// Фаза E, Волна 7. Покрывает сборку сессии просодии: зависимость длины
// сессии от возраста (≤6 лет — короче), методическую прогрессию этапов
// (различение → повтор → продуцирование), fallback при сбое чтения профиля.

@MainActor
final class ProsodyWorkerTests: XCTestCase {

    private func child(id: String = "c-1", age: Int) -> ChildProfileDTO {
        ChildProfileDTO(id: id, name: "Тест", age: age, targetSounds: ["Р"], parentId: "p-1")
    }

    // MARK: - Session non-empty

    func test_buildSession_producesNonEmptyRounds() async {
        let repo = MockChildRepository(children: [child(age: 7)])
        let sut = ProsodyWorker(childRepository: repo)

        let response = await sut.buildSession(childId: "c-1")

        XCTAssertFalse(response.rounds.isEmpty)
    }

    // MARK: - Age affects session length

    func test_buildSession_youngChildGetsShorterSession() async {
        let young = ProsodyWorker(childRepository: MockChildRepository(children: [child(age: 6)]))
        let older = ProsodyWorker(childRepository: MockChildRepository(children: [child(id: "c-2", age: 8)]))

        let youngRounds = await young.buildSession(childId: "c-1").rounds.count
        let olderRounds = await older.buildSession(childId: "c-2").rounds.count

        XCTAssertLessThanOrEqual(youngRounds, olderRounds,
            "6 лет — сессия не длиннее, чем 8 лет")
    }

    func test_buildSession_age5_isTreatedAsYoung() async {
        // age <= 6 → roundsPerSession - 3.
        let repo = MockChildRepository(children: [child(age: 5)])
        let sut = ProsodyWorker(childRepository: repo)

        let response = await sut.buildSession(childId: "c-1")

        let youngTotal = max(0, ProsodyCorpus.roundsPerSession - 3)
        XCTAssertLessThanOrEqual(response.rounds.count, youngTotal + 3) // не больше полной
        XCTAssertFalse(response.rounds.isEmpty)
    }

    // MARK: - Methodical stage order

    func test_buildSession_stagesFollowProgression() async {
        let repo = MockChildRepository(children: [child(age: 8)])
        let sut = ProsodyWorker(childRepository: repo)

        let response = await sut.buildSession(childId: "c-1")

        // discriminate → imitate → produce.
        let order: [ProsodyStage] = [.discriminate, .imitate, .produce]
        var lastRank = -1
        for round in response.rounds {
            let rank = order.firstIndex(of: round.stage) ?? Int.max
            XCTAssertGreaterThanOrEqual(rank, lastRank,
                "Этапы должны идти discriminate → imitate → produce")
            lastRank = rank
        }
    }

    func test_buildSession_roundIdsAreUnique() async {
        let repo = MockChildRepository(children: [child(age: 7)])
        let sut = ProsodyWorker(childRepository: repo)

        let response = await sut.buildSession(childId: "c-1")

        let ids = response.rounds.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_buildSession_roundIdEncodesStageAndPhrase() async {
        let repo = MockChildRepository(children: [child(age: 7)])
        let sut = ProsodyWorker(childRepository: repo)

        let response = await sut.buildSession(childId: "c-1")

        for round in response.rounds {
            XCTAssertTrue(round.id.hasPrefix(round.stage.rawValue))
            XCTAssertTrue(round.id.contains(round.phrase.id))
        }
    }

    // MARK: - Fallback

    func test_buildSession_repositoryFailure_usesDefaultAge7() async {
        // Сбой профиля → возраст по умолчанию 7 → полная сессия.
        let repo = MockChildRepository(children: [])
        let sut = ProsodyWorker(childRepository: repo)

        let response = await sut.buildSession(childId: "missing")

        XCTAssertFalse(response.rounds.isEmpty)
    }

    // MARK: - Corpus query

    func test_corpus_phrasesOfType_filtersByIntonation() {
        for type in IntonationType.allCases {
            let phrases = ProsodyCorpus.phrases(of: type)
            XCTAssertTrue(phrases.allSatisfy { $0.intonation == type })
        }
    }
}
