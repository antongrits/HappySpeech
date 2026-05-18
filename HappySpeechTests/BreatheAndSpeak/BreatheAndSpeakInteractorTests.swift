@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubBreatheWorker: BreatheAndSpeakWorkerProtocol {
    var response: BreatheAndSpeakModels.Start.Response
    private(set) var buildCallCount = 0

    init(response: BreatheAndSpeakModels.Start.Response) {
        self.response = response
    }

    func buildComplex(childId: String) async -> BreatheAndSpeakModels.Start.Response {
        buildCallCount += 1
        return response
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyBreathePresenter: BreatheAndSpeakPresentationLogic, @unchecked Sendable {
    var startCount = 0
    var advanceCount = 0
    var lastAdvance: BreatheAndSpeakModels.Advance.Response?

    func presentStart(response: BreatheAndSpeakModels.Start.Response) async {
        startCount += 1
    }
    func presentAdvance(response: BreatheAndSpeakModels.Advance.Response) async {
        advanceCount += 1
        lastAdvance = response
    }
}

// MARK: - Helpers

private func makeExercise(_ id: String, _ kind: ExerciseKind = .articulation) -> ComplexExercise {
    .init(id: id, kind: kind, name: "Поза \(id)",
          instruction: "Сделай позу", symbolName: "tongue", holdSeconds: 4)
}

private func makeComplex(steps: Int) -> ArticulationComplex {
    .init(id: "cx", soundGroup: "Р", title: "Комплекс",
          exercises: (0..<steps).map { makeExercise("e\($0)") })
}

// MARK: - Interactor Tests

@MainActor
final class BreatheAndSpeakInteractorTests: XCTestCase {

    private func makeSUT(
        steps: Int = 3
    ) -> (BreatheAndSpeakInteractor, SpyBreathePresenter, StubBreatheWorker, SpyHapticService) {
        let worker = StubBreatheWorker(response: .init(complex: makeComplex(steps: steps)))
        let haptic = SpyHapticService()
        let sut = BreatheAndSpeakInteractor(childId: "child-1", worker: worker, hapticService: haptic)
        let spy = SpyBreathePresenter()
        sut.presenter = spy
        return (sut, spy, worker, haptic)
    }

    func test_start_buildsComplexAndPresents() async {
        let (sut, spy, worker, _) = makeSUT(steps: 3)
        await sut.start(request: .init(childId: "child-1"))
        XCTAssertEqual(worker.buildCallCount, 1)
        XCTAssertEqual(spy.startCount, 1)
        XCTAssertEqual(sut.complex?.exercises.count, 3)
        XCTAssertEqual(sut.currentIndex, 0)
    }

    func test_advance_movesToNextStep() async {
        let (sut, spy, _, haptic) = makeSUT(steps: 3)
        await sut.start(request: .init(childId: "child-1"))
        await sut.advance(request: .init())
        XCTAssertEqual(sut.currentIndex, 1)
        XCTAssertEqual(spy.lastAdvance?.isFinished, false)
        XCTAssertNotNil(spy.lastAdvance?.nextStep)
        XCTAssertEqual(spy.lastAdvance?.nextStepIndex, 1)
        XCTAssertEqual(haptic.notificationCount, 1)
    }

    func test_advance_lastStep_marksFinished() async {
        let (sut, spy, _, _) = makeSUT(steps: 2)
        await sut.start(request: .init(childId: "child-1"))
        await sut.advance(request: .init())
        await sut.advance(request: .init())
        XCTAssertEqual(spy.lastAdvance?.isFinished, true)
        XCTAssertNil(spy.lastAdvance?.nextStep)
        XCTAssertEqual(spy.lastAdvance?.completedSteps, 2)
        XCTAssertEqual(spy.lastAdvance?.totalSteps, 2)
    }

    func test_advance_afterFinish_isIgnored() async {
        let (sut, spy, _, _) = makeSUT(steps: 2)
        await sut.start(request: .init(childId: "child-1"))
        await sut.advance(request: .init())
        await sut.advance(request: .init())
        let afterFinish = spy.advanceCount
        await sut.advance(request: .init())
        XCTAssertEqual(spy.advanceCount, afterFinish)
    }

    func test_advance_beforeStart_isIgnored() async {
        let (sut, spy, _, _) = makeSUT(steps: 2)
        await sut.advance(request: .init())
        XCTAssertEqual(spy.advanceCount, 0)
    }

    func test_start_resetsProgress() async {
        let (sut, _, _, _) = makeSUT(steps: 3)
        await sut.start(request: .init(childId: "child-1"))
        await sut.advance(request: .init())
        await sut.start(request: .init(childId: "child-1"))
        XCTAssertEqual(sut.currentIndex, 0)
    }
}

// MARK: - Corpus Tests

final class BreatheAndSpeakCorpusTests: XCTestCase {

    func test_corpus_hasComplexes() {
        XCTAssertGreaterThanOrEqual(BreatheAndSpeakCorpus.complexes.count, 4)
    }

    func test_everyComplex_endsWithBreathingExercise() {
        for complex in BreatheAndSpeakCorpus.complexes {
            XCTAssertEqual(complex.exercises.last?.kind, .breathing,
                           "Комплекс \(complex.id) должен завершаться дыхательным упражнением")
        }
    }

    func test_everyComplex_hasAtLeastFourSteps() {
        for complex in BreatheAndSpeakCorpus.complexes {
            XCTAssertGreaterThanOrEqual(complex.exercises.count, 4)
        }
    }

    func test_recommendedComplex_matchesTargetSound() {
        let complex = BreatheAndSpeakCorpus.recommendedComplex(for: ["Р"])
        XCTAssertEqual(complex.soundGroup, "Р")
    }

    func test_recommendedComplex_unknownSound_returnsDefault() {
        let complex = BreatheAndSpeakCorpus.recommendedComplex(for: ["Я"])
        XCTAssertEqual(complex.id, BreatheAndSpeakCorpus.complexes.first?.id)
    }

    func test_complexIdsAreUnique() {
        let ids = BreatheAndSpeakCorpus.complexes.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_holdSeconds_arePositive() {
        for complex in BreatheAndSpeakCorpus.complexes {
            for exercise in complex.exercises {
                XCTAssertGreaterThan(exercise.holdSeconds, 0)
            }
        }
    }
}
