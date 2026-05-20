@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubBedtimeWorker: BedtimeModeWorkerProtocol {

    var stories: [BedtimeStory]
    private(set) var narrateCount = 0
    private(set) var stopCount = 0

    init(stories: [BedtimeStory]) {
        self.stories = stories
    }

    func pickStory(excluding excludeId: String?) -> BedtimeStory? {
        let remaining = stories.filter { $0.id != excludeId }
        return remaining.first ?? stories.first
    }

    var libraryCount: Int { stories.count }

    func breathingCycle() -> BedtimeBreathingCycle {
        BedtimeBreathingCycle(inhaleSeconds: 4, holdSeconds: 4, exhaleSeconds: 6, totalCycles: 3)
    }

    func narrate(_ text: String) async {
        narrateCount += 1
    }

    func stopNarration() {
        stopCount += 1
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyBedtimePresenter:
    BedtimeModePresentationLogic, @unchecked Sendable {
    var startCount = 0
    var advanceCount = 0
    var newStoryCount = 0
    var lastStage: BedtimeStage?

    func presentStart(response: BedtimeModeModels.Start.Response) async {
        startCount += 1
    }
    func presentAdvance(stage: BedtimeStage) async {
        advanceCount += 1
        lastStage = stage
    }
    func presentNewStory(response: BedtimeModeModels.Start.Response) async {
        newStoryCount += 1
    }
}

// MARK: - Fixtures

private func makeStory(_ id: String) -> BedtimeStory {
    BedtimeStory(id: id, title: "Title \(id)", text: "Text \(id)")
}

// MARK: - Interactor Tests

@MainActor
final class BedtimeModeInteractorTests: XCTestCase {

    private func makeSUT(
        stories: [BedtimeStory] = [makeStory("s1"), makeStory("s2"), makeStory("s3")]
    ) -> (BedtimeModeInteractor, SpyBedtimePresenter, StubBedtimeWorker, SpyHapticService) {
        let worker = StubBedtimeWorker(stories: stories)
        let haptic = SpyHapticService()
        let interactor = BedtimeModeInteractor(
            childId: "child-1",
            worker: worker,
            hapticService: haptic
        )
        let spy = SpyBedtimePresenter()
        interactor.presenter = spy
        return (interactor, spy, worker, haptic)
    }

    func test_start_picksFirstStory_andSetsIntroStage() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.start(request: .init(childId: "child-1"))
        XCTAssertEqual(spy.startCount, 1)
        XCTAssertEqual(sut.currentStage, .intro)
        XCTAssertEqual(sut.currentStory?.id, "s1")
    }

    func test_advance_progressesIntroToBreathing() async {
        let (sut, spy, _, haptic) = makeSUT()
        await sut.start(request: .init(childId: "child-1"))
        await sut.advance(request: .init(currentStage: .intro))
        XCTAssertEqual(spy.lastStage, .breathing)
        XCTAssertEqual(sut.currentStage, .breathing)
        XCTAssertGreaterThan(haptic.impactCount, 0)
    }

    func test_advance_breathingToStory() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.start(request: .init(childId: "child-1"))
        await sut.advance(request: .init(currentStage: .breathing))
        XCTAssertEqual(spy.lastStage, .story)
    }

    func test_advance_storyToFarewell() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.start(request: .init(childId: "child-1"))
        await sut.advance(request: .init(currentStage: .story))
        XCTAssertEqual(spy.lastStage, .farewell)
    }

    func test_advance_farewell_staysAtFarewell() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.start(request: .init(childId: "child-1"))
        await sut.advance(request: .init(currentStage: .farewell))
        XCTAssertEqual(spy.lastStage, .farewell)
    }

    func test_pickNewStory_excludesCurrent() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.start(request: .init(childId: "child-1"))
        let initialStoryId = sut.currentStory?.id
        await sut.pickNewStory(request: .init(excludeId: nil))
        XCTAssertEqual(spy.newStoryCount, 1)
        XCTAssertNotEqual(sut.currentStory?.id, initialStoryId)
    }

    func test_narrate_invokesWorker() async {
        let (sut, _, worker, _) = makeSUT()
        await sut.start(request: .init(childId: "child-1"))
        await sut.narrateStory()
        XCTAssertEqual(worker.narrateCount, 1)
    }

    func test_stopNarration_invokesWorker() async {
        let (sut, _, worker, _) = makeSUT()
        await sut.start(request: .init(childId: "child-1"))
        sut.stopNarration()
        XCTAssertEqual(worker.stopCount, 1)
    }
}

// MARK: - Corpus Tests

final class BedtimeModeCorpusTests: XCTestCase {

    func test_corpus_loadsStories() {
        XCTAssertGreaterThanOrEqual(BedtimeModeCorpus.allStories.count, 10,
                                    "Корпус должен содержать ≥10 историй")
    }

    func test_storyIds_areUnique() {
        let ids = BedtimeModeCorpus.allStories.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_everyStory_hasNonEmptyText() {
        for story in BedtimeModeCorpus.allStories {
            XCTAssertFalse(story.text.isEmpty)
            XCTAssertFalse(story.title.isEmpty)
        }
    }

    func test_randomStory_excludesGivenId() {
        guard let first = BedtimeModeCorpus.allStories.first else {
            XCTFail("empty corpus"); return
        }
        let other = BedtimeModeCorpus.randomStory(excluding: first.id)
        // either nil (single story corpus — но у нас 10+), либо != first
        if BedtimeModeCorpus.allStories.count > 1 {
            XCTAssertNotEqual(other?.id, first.id)
        }
    }
}
