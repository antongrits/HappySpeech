@testable import HappySpeech
import XCTest

// MARK: - StoryRetellingProInteractorTests
//
// StoryRetellingProInteractor drives a REAL retelling activity: load() restores
// per-story completion from saved retellings (worker → Realm), record/score runs
// ASR + key-fact coverage scoring and persists. `.initial` is neutral (every
// story not completed, 0% coverage) — no hardcoded "✓ done". Tests use a mock
// worker; the worker's pure coverage scoring is tested directly too.

@MainActor
final class StoryRetellingProInteractorTests: XCTestCase {

    // MARK: - Mock worker

    private final class MockRetellingWorker: StoryRetellingProWorkerProtocol {
        var completion: [String: Double] = [:]
        var nextScoring = StoryRetellingScoring(coverage: 0, matched: [], missed: [])
        private(set) var startCalled = false
        private(set) var stopCalled = false

        func startRecording() async throws { startCalled = true }

        func stopRecordAndScore(
            story: StoryRetellingProModels.Story,
            childId: String,
            startedAt: Date
        ) async -> (scoring: StoryRetellingScoring, transcript: String) {
            stopCalled = true
            return (nextScoring, "транскрипт")
        }

        func loadCompletion(
            childId: String,
            stories: [StoryRetellingProModels.Story]
        ) async -> [String: Double] {
            completion
        }

        func score(transcript: String, keyFacts: [String]) -> StoryRetellingScoring {
            nextScoring
        }
    }

    private func makeSUT(
        worker: MockRetellingWorker,
        childId: String = "child-1"
    ) -> StoryRetellingProInteractor {
        StoryRetellingProInteractor(childId: childId, worker: worker)
    }

    // MARK: - Initial state (no fabrication)

    func test_init_storesChildId() {
        let sut = StoryRetellingProInteractor(childId: "kid-retell")
        XCTAssertEqual(sut.childId, "kid-retell")
    }

    func test_initialState_noStoryCompleted_noFabrication() {
        let sut = StoryRetellingProInteractor(childId: "kid")
        XCTAssertFalse(sut.state.stories.isEmpty)
        XCTAssertTrue(sut.state.stories.allSatisfy { !$0.isCompleted })
        XCTAssertTrue(sut.state.stories.allSatisfy { $0.bestCoverage == 0 })
        XCTAssertNil(sut.state.selectedStoryId)
    }

    func test_catalog_isWellFormed() {
        let sut = StoryRetellingProInteractor(childId: "kid")
        XCTAssertEqual(Set(sut.state.stories.map(\.id)).count, sut.state.stories.count)
        for story in sut.state.stories {
            XCTAssertFalse(story.title.isEmpty)
            XCTAssertGreaterThan(story.keyFactsCount, 0)
        }
    }

    // MARK: - load (real completion)

    func test_load_marksStoryCompleted_whenCoverageAboveThreshold() async {
        let worker = MockRetellingWorker()
        worker.completion = ["repka": 0.8]
        let sut = makeSUT(worker: worker)
        await sut.load()
        let repka = sut.state.stories.first { $0.id == "repka" }
        XCTAssertEqual(repka?.isCompleted, true)
        XCTAssertEqual(repka?.bestCoverage ?? 0, 0.8, accuracy: 0.001)
        XCTAssertFalse(sut.state.isLoading)
    }

    func test_load_doesNotComplete_belowThreshold() async {
        let worker = MockRetellingWorker()
        worker.completion = ["repka": 0.3]
        let sut = makeSUT(worker: worker)
        await sut.load()
        let repka = sut.state.stories.first { $0.id == "repka" }
        XCTAssertEqual(repka?.isCompleted, false)
    }

    // MARK: - record + score

    func test_stopAndScore_updatesCompletionFromRealResult() async {
        let worker = MockRetellingWorker()
        let sut = makeSUT(worker: worker)
        await sut.load()
        let id = sut.state.stories[0].id
        sut.select(id)
        worker.nextScoring = StoryRetellingScoring(coverage: 0.75, matched: ["дед"], missed: [])
        await sut.startRecording()
        XCTAssertTrue(worker.startCalled)
        await sut.stopAndScore()
        XCTAssertTrue(worker.stopCalled)
        let story = sut.state.stories.first { $0.id == id }
        XCTAssertEqual(story?.isCompleted, true)
        if case let .result(coverage, _, _) = sut.state.phase {
            XCTAssertEqual(coverage, 0.75, accuracy: 0.001)
        } else {
            XCTFail("Expected result phase")
        }
    }

    func test_select_setsBrowsingPhase() {
        let sut = makeSUT(worker: MockRetellingWorker())
        sut.select("repka")
        XCTAssertEqual(sut.state.selectedStoryId, "repka")
        XCTAssertEqual(sut.state.phase, .browsing)
    }
}

// MARK: - StoryRetellingProWorker coverage scoring (pure)

@MainActor
final class StoryRetellingProWorkerScoringTests: XCTestCase {

    private func makeWorker() -> StoryRetellingProWorker {
        StoryRetellingProWorker(
            audioService: MockAudioService(),
            asrService: MockASRService(),
            realmActor: RealmActor()
        )
    }

    func test_score_fullCoverage() {
        let worker = makeWorker()
        let scoring = worker.score(
            transcript: "дед бил яичко баба тоже мышка прибежала разбилось",
            keyFacts: ["дед", "баба", "яичко", "мышка", "разбилось"]
        )
        XCTAssertEqual(scoring.coverage, 1.0, accuracy: 0.001)
        XCTAssertTrue(scoring.missed.isEmpty)
    }

    func test_score_partialCoverage() {
        let worker = makeWorker()
        let scoring = worker.score(
            transcript: "жил дед и репка выросла большая",
            keyFacts: ["дед", "репка", "бабка", "внучка"]
        )
        XCTAssertEqual(scoring.coverage, 0.5, accuracy: 0.001)
        XCTAssertEqual(Set(scoring.matched), Set(["дед", "репка"]))
    }

    func test_score_handlesRussianInflection() {
        let worker = makeWorker()
        // "мышку" should stem-match "мышка".
        let scoring = worker.score(
            transcript: "позвали мышку и колобка",
            keyFacts: ["мышка", "колобок"]
        )
        XCTAssertEqual(scoring.coverage, 1.0, accuracy: 0.001)
    }

    func test_score_emptyTranscript_zero() {
        let worker = makeWorker()
        let scoring = worker.score(transcript: "", keyFacts: ["дед", "баба"])
        XCTAssertEqual(scoring.coverage, 0.0)
        XCTAssertEqual(scoring.missed.count, 2)
    }
}
