@testable import HappySpeech
import XCTest

// MARK: - CoPlayWorkerTests
//
// Фаза E, Волна 7. CoPlayWorker всегда отдаёт сценарий совместной игры из
// локального корпуса — даже если чтение профиля ребёнка упало (graceful).

@MainActor
final class CoPlayWorkerTests: XCTestCase {

    private func makeChild(id: String = "c-1") -> ChildProfileDTO {
        ChildProfileDTO(id: id, name: "Тест", age: 6, targetSounds: ["Р"], parentId: "p-1")
    }

    func test_pickActivity_returnsActivityFromCorpus() async {
        let repo = MockChildRepository(children: [makeChild()])
        let sut = CoPlayWorker(childRepository: repo)

        let response = await sut.pickActivity(childId: "c-1")

        let ids = Set(CoPlayCorpus.activities.map(\.id))
        XCTAssertTrue(ids.contains(response.activity.id),
                      "Сценарий должен принадлежать корпусу")
    }

    func test_pickActivity_repositoryFailure_stillServesActivity() async {
        // Несуществующий ребёнок → fetch бросает → сценарий всё равно выдаётся.
        let repo = MockChildRepository(children: [])
        let sut = CoPlayWorker(childRepository: repo)

        let response = await sut.pickActivity(childId: "missing")

        XCTAssertFalse(response.activity.turns.isEmpty)
        XCTAssertFalse(response.activity.title.isEmpty)
    }

    func test_pickActivity_activityHasAlternatingTurns() async {
        let repo = MockChildRepository(children: [makeChild()])
        let sut = CoPlayWorker(childRepository: repo)

        let response = await sut.pickActivity(childId: "c-1")

        // Каждый сценарий — чередование ходов взрослый/ребёнок, минимум 2 хода.
        XCTAssertGreaterThanOrEqual(response.activity.turns.count, 2)
        let roles = Set(response.activity.turns.map(\.role))
        XCTAssertTrue(roles.contains(.adult))
        XCTAssertTrue(roles.contains(.child))
    }

    func test_corpus_activityById_returnsMatch() {
        XCTAssertEqual(CoPlayCorpus.activity(id: "echo-animals")?.id, "echo-animals")
    }

    func test_corpus_activityByUnknownId_returnsNil() {
        XCTAssertNil(CoPlayCorpus.activity(id: "nope"))
    }

    func test_corpus_allActivitiesHaveBriefingAndUniqueIds() {
        let activities = CoPlayCorpus.activities
        XCTAssertFalse(activities.isEmpty)
        for activity in activities {
            XCTAssertFalse(activity.adultBriefing.isEmpty, "У \(activity.id) пустой briefing")
        }
        let ids = activities.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "ID сценариев должны быть уникальны")
    }
}
