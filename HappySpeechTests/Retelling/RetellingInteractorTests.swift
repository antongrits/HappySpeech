@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubRetellingWorker: RetellingWorkerProtocol {
    var response: RetellingModels.Start.Response
    private(set) var pickCallCount = 0

    init(response: RetellingModels.Start.Response) {
        self.response = response
    }

    func pickStory(childId: String) async -> RetellingModels.Start.Response {
        pickCallCount += 1
        return response
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyRetellingPresenter: RetellingPresentationLogic, @unchecked Sendable {
    var startCount = 0
    var toggleCount = 0
    var finishCount = 0
    var lastToggle: RetellingModels.ToggleLink.Response?
    var lastFinish: RetellingModels.Finish.Response?

    func presentStart(response: RetellingModels.Start.Response) async {
        startCount += 1
    }
    func presentToggle(response: RetellingModels.ToggleLink.Response) async {
        toggleCount += 1
        lastToggle = response
    }
    func presentFinish(response: RetellingModels.Finish.Response) async {
        finishCount += 1
        lastFinish = response
    }
}

// MARK: - Helpers

@MainActor
private func makeStory() -> RetellingStory {
    .init(id: "s1", title: "Тест", frames: [
        .init(id: "f1", sentence: "Жил кот.", link: .hero, symbolName: "cat.fill"),
        .init(id: "f2", sentence: "В саду.", link: .place, symbolName: "tree.fill"),
        .init(id: "f3", sentence: "Потерялся.", link: .problem, symbolName: "x.circle"),
        .init(id: "f4", sentence: "Нашёлся.", link: .solution, symbolName: "checkmark")
    ])
}

// MARK: - Interactor Tests

@MainActor
final class RetellingInteractorTests: XCTestCase {

    private func makeSUT() -> (RetellingInteractor, SpyRetellingPresenter, StubRetellingWorker) {
        let worker = StubRetellingWorker(response: .init(story: makeStory()))
        let haptic = SpyHapticService()
        let sut = RetellingInteractor(childId: "child-1", worker: worker, hapticService: haptic)
        let spy = SpyRetellingPresenter()
        sut.presenter = spy
        return (sut, spy, worker)
    }

    func test_start_picksStoryAndPresents() async {
        let (sut, spy, worker) = makeSUT()
        await sut.start(request: .init(childId: "child-1"))
        XCTAssertEqual(worker.pickCallCount, 1)
        XCTAssertEqual(spy.startCount, 1)
        XCTAssertEqual(sut.story?.frames.count, 4)
        XCTAssertTrue(sut.coveredFrameIds.isEmpty)
    }

    func test_toggleLink_addsAndRemoves() async {
        let (sut, spy, _) = makeSUT()
        await sut.start(request: .init(childId: "child-1"))
        await sut.toggleLink(request: .init(frameId: "f1"))
        XCTAssertTrue(sut.coveredFrameIds.contains("f1"))
        XCTAssertEqual(spy.lastToggle?.coveredFrameIds.count, 1)
        await sut.toggleLink(request: .init(frameId: "f1"))
        XCTAssertFalse(sut.coveredFrameIds.contains("f1"))
    }

    func test_finish_reportsCoverageAndMissedLinks() async {
        let (sut, spy, _) = makeSUT()
        await sut.start(request: .init(childId: "child-1"))
        await sut.toggleLink(request: .init(frameId: "f1"))
        await sut.toggleLink(request: .init(frameId: "f2"))
        await sut.finish(request: .init(voiceRecorded: true))
        XCTAssertEqual(spy.lastFinish?.coveredCount, 2)
        XCTAssertEqual(spy.lastFinish?.totalFrames, 4)
        XCTAssertEqual(spy.lastFinish?.missedLinks.count, 2)
        XCTAssertTrue(spy.lastFinish?.missedLinks.contains(.problem) ?? false)
    }

    func test_finish_allCovered_noMissedLinks() async {
        let (sut, spy, _) = makeSUT()
        await sut.start(request: .init(childId: "child-1"))
        for fid in ["f1", "f2", "f3", "f4"] {
            await sut.toggleLink(request: .init(frameId: fid))
        }
        await sut.finish(request: .init(voiceRecorded: true))
        XCTAssertEqual(spy.lastFinish?.coveredCount, 4)
        XCTAssertTrue(spy.lastFinish?.missedLinks.isEmpty ?? false)
    }
}

// MARK: - Corpus Tests

final class RetellingCorpusTests: XCTestCase {

    func test_corpus_isNotEmpty() {
        XCTAssertFalse(RetellingCorpus.stories.isEmpty)
    }

    func test_everyStory_hasFramesAndUniqueIds() {
        for story in RetellingCorpus.stories {
            XCTAssertGreaterThanOrEqual(story.frames.count, 4)
            let ids = story.frames.map(\.id)
            XCTAssertEqual(ids.count, Set(ids).count)
        }
    }

    func test_everyStory_coversAllSemanticLinks() {
        for story in RetellingCorpus.stories {
            let links = Set(story.frames.map(\.link))
            XCTAssertEqual(links, Set(SemanticLinkKind.allCases))
        }
    }

    func test_storyById_returnsCorrectStory() {
        let story = RetellingCorpus.story(id: "cat-and-bird")
        XCTAssertEqual(story?.id, "cat-and-bird")
    }
}
