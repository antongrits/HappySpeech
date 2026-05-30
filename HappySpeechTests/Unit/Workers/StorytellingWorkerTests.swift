@testable import HappySpeech
import XCTest

// MARK: - StorytellingWorkerTests
//
// Фаза E, Волна 8. Покрывает StorytellingWorker: loadTopics отдаёт темы корпуса
// (чтение профиля не блокирует выдачу), topic(id:) находит тему или возвращает
// nil для неизвестного id. Также — инварианты корпуса (непустые планы, уникальные
// id) и модель StoryTopic.

@MainActor
final class StorytellingWorkerTests: XCTestCase {

    private func child(id: String = "c-1") -> ChildProfileDTO {
        ChildProfileDTO(id: id, name: "Тест", age: 8, targetSounds: ["Р"], parentId: "p-1")
    }

    private func makeSUT(children: [ChildProfileDTO]) -> StorytellingWorker {
        StorytellingWorker(childRepository: MockChildRepository(children: children))
    }

    // MARK: - loadTopics

    func test_loadTopics_returnsNonEmptyTopics() async {
        let sut = makeSUT(children: [child()])
        let response = await sut.loadTopics(childId: "c-1")
        XCTAssertFalse(response.topics.isEmpty)
    }

    func test_loadTopics_servedEvenWhenChildMissing() async {
        let sut = makeSUT(children: [])
        let response = await sut.loadTopics(childId: "missing")
        XCTAssertFalse(response.topics.isEmpty,
                       "Сбой профиля не блокирует выдачу тем")
    }

    func test_loadTopics_everyTopicHasPlan() async {
        let sut = makeSUT(children: [child()])
        let response = await sut.loadTopics(childId: "c-1")
        XCTAssertTrue(response.topics.allSatisfy { !$0.plan.isEmpty },
                      "У каждой темы есть план-схема")
    }

    func test_loadTopics_topicsMatchCorpus() async {
        let sut = makeSUT(children: [child()])
        let response = await sut.loadTopics(childId: "c-1")
        XCTAssertEqual(response.topics.map(\.id), StorytellingCorpus.topics.map(\.id))
    }

    // MARK: - topic(id:)

    func test_topic_unknownIdReturnsNil() {
        let sut = makeSUT(children: [child()])
        XCTAssertNil(sut.topic(id: "no-such-topic"))
    }

    func test_topic_knownIdReturnsTopic() {
        let sut = makeSUT(children: [child()])
        guard let any = StorytellingCorpus.topics.first else {
            return XCTFail("Корпус тем пуст")
        }
        let response = sut.topic(id: any.id)
        XCTAssertEqual(response?.topic.id, any.id)
    }

    // MARK: - StorytellingCorpus invariants

    func test_corpus_topicIdsAreUnique() {
        let ids = StorytellingCorpus.topics.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_corpus_planStepIdsArePrefixedWithTopicId() {
        // Загрузчик строит id шага как "<topicId>-<stepId>".
        for topic in StorytellingCorpus.topics {
            XCTAssertTrue(topic.plan.allSatisfy { $0.id.hasPrefix(topic.id) },
                          "Шаги плана темы \(topic.id) должны быть уникализированы по теме")
        }
    }

    func test_corpus_topic_roundTrips() {
        guard let any = StorytellingCorpus.topics.first else {
            return XCTFail("Корпус тем пуст")
        }
        XCTAssertEqual(StorytellingCorpus.topic(id: any.id)?.id, any.id)
        XCTAssertNil(StorytellingCorpus.topic(id: "zzz-unknown"))
    }
}
