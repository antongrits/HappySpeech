@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubStorytellingWorker: StorytellingWorkerProtocol {
    var topicsResponse: StorytellingModels.LoadTopics.Response
    var topicResponse: StorytellingModels.StartTopic.Response?
    private(set) var loadCount = 0

    init(
        topicsResponse: StorytellingModels.LoadTopics.Response,
        topicResponse: StorytellingModels.StartTopic.Response?
    ) {
        self.topicsResponse = topicsResponse
        self.topicResponse = topicResponse
    }

    func loadTopics(childId: String) async -> StorytellingModels.LoadTopics.Response {
        loadCount += 1
        return topicsResponse
    }
    func topic(id: String) -> StorytellingModels.StartTopic.Response? {
        topicResponse
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyStorytellingPresenter: StorytellingPresentationLogic, @unchecked Sendable {
    var topicsCount = 0
    var startCount = 0
    var toggleCount = 0
    var finishCount = 0
    var lastToggle: StorytellingModels.ToggleStep.Response?
    var lastFinish: StorytellingModels.Finish.Response?

    func presentTopics(response: StorytellingModels.LoadTopics.Response) async {
        topicsCount += 1
    }
    func presentTopicStart(response: StorytellingModels.StartTopic.Response) async {
        startCount += 1
    }
    func presentToggle(response: StorytellingModels.ToggleStep.Response) async {
        toggleCount += 1
        lastToggle = response
    }
    func presentFinish(response: StorytellingModels.Finish.Response) async {
        finishCount += 1
        lastFinish = response
    }
}

// MARK: - Interactor Tests

@MainActor
final class StorytellingInteractorTests: XCTestCase {

    private func makeSUT() -> (StorytellingInteractor, SpyStorytellingPresenter, StubStorytellingWorker) {
        let topics = StorytellingModels.LoadTopics.Response(
            topics: StorytellingCorpus.topics
        )
        let topic = StorytellingModels.StartTopic.Response(
            topic: StorytellingCorpus.topics[0]
        )
        let worker = StubStorytellingWorker(topicsResponse: topics, topicResponse: topic)
        let haptic = SpyHapticService()
        let sut = StorytellingInteractor(
            childId: "child-1", worker: worker, hapticService: haptic
        )
        let spy = SpyStorytellingPresenter()
        sut.presenter = spy
        return (sut, spy, worker)
    }

    func test_loadTopics_presents() async {
        let (sut, spy, worker) = makeSUT()
        await sut.loadTopics(request: .init(childId: "child-1"))
        XCTAssertEqual(worker.loadCount, 1)
        XCTAssertEqual(spy.topicsCount, 1)
    }

    func test_startTopic_setsActiveTopic() async {
        let (sut, spy, _) = makeSUT()
        await sut.startTopic(request: .init(topicId: "zoo-trip"))
        XCTAssertNotNil(sut.activeTopic)
        XCTAssertTrue(sut.completedStepIds.isEmpty)
        XCTAssertEqual(spy.startCount, 1)
    }

    func test_toggleStep_addsAndRemoves() async {
        let (sut, spy, _) = makeSUT()
        await sut.startTopic(request: .init(topicId: "zoo-trip"))
        guard let stepId = sut.activeTopic?.plan.first?.id else {
            return XCTFail("no plan step")
        }
        await sut.toggleStep(request: .init(stepId: stepId))
        XCTAssertTrue(sut.completedStepIds.contains(stepId))
        XCTAssertEqual(spy.lastToggle?.completedStepIds.count, 1)
        await sut.toggleStep(request: .init(stepId: stepId))
        XCTAssertFalse(sut.completedStepIds.contains(stepId))
    }

    func test_finish_reportsCompletedCount() async {
        let (sut, spy, _) = makeSUT()
        await sut.startTopic(request: .init(topicId: "zoo-trip"))
        guard let plan = sut.activeTopic?.plan else { return XCTFail("no plan") }
        for step in plan {
            await sut.toggleStep(request: .init(stepId: step.id))
        }
        await sut.finish(request: .init(voiceRecorded: true))
        XCTAssertEqual(spy.lastFinish?.completedCount, plan.count)
        XCTAssertEqual(spy.lastFinish?.totalSteps, plan.count)
    }
}

// MARK: - Corpus Tests

final class StorytellingCorpusTests: XCTestCase {

    func test_corpus_isNotEmpty() {
        XCTAssertFalse(StorytellingCorpus.topics.isEmpty)
    }

    func test_topicIdsAreUnique() {
        let ids = StorytellingCorpus.topics.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_everyTopicHasFourPlanSteps() {
        for topic in StorytellingCorpus.topics {
            XCTAssertEqual(topic.plan.count, 4)
            for step in topic.plan {
                XCTAssertFalse(step.question.isEmpty)
            }
        }
    }

    func test_topicById_returnsCorrectTopic() {
        XCTAssertEqual(StorytellingCorpus.topic(id: "zoo-trip")?.id, "zoo-trip")
    }
}
