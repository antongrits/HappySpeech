@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubLetterTraceWorker: LetterTraceWorkerProtocol {

    var items: [TraceItem]
    var stubScore: TraceScore = TraceScore(similarity: 0.5)
    private(set) var scoreCallCount = 0

    init(items: [TraceItem] = StubLetterTraceWorker.defaultItems()) {
        self.items = items
    }

    func loadItems() -> [TraceItem] { items }

    func score(itemId: String, userStrokes: [[TracePoint]]) -> TraceScore {
        scoreCallCount += 1
        return stubScore
    }

    static func defaultItems() -> [TraceItem] {
        let line = [TracePoint(x: 0.2, y: 0.5), TracePoint(x: 0.8, y: 0.5)]
        return [
            TraceItem(id: "i1", kind: .letter,   symbol: "А", strokes: [line]),
            TraceItem(id: "i2", kind: .letter,   symbol: "Б", strokes: [line]),
            TraceItem(id: "i3", kind: .syllable, symbol: "ША", strokes: [line])
        ]
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyLetterTracePresenter:
    LetterTracePresentationLogic, @unchecked Sendable {
    var loadCount = 0
    var advanceCount = 0
    var scoreCount = 0
    var lastLoad: LetterTraceModels.Load.Response?
    var lastAdvance: LetterTraceModels.Advance.Response?
    var lastScore: LetterTraceModels.Score.Response?

    func presentLoad(response: LetterTraceModels.Load.Response) async {
        loadCount += 1
        lastLoad = response
    }
    func presentAdvance(response: LetterTraceModels.Advance.Response) async {
        advanceCount += 1
        lastAdvance = response
    }
    func presentScore(response: LetterTraceModels.Score.Response) async {
        scoreCount += 1
        lastScore = response
    }
}

// MARK: - Interactor Tests

@MainActor
final class LetterTraceInteractorTests: XCTestCase {

    private func makeSUT(
        items: [TraceItem] = StubLetterTraceWorker.defaultItems()
    ) -> (LetterTraceInteractor, SpyLetterTracePresenter, StubLetterTraceWorker, SpyHapticService) {
        let worker = StubLetterTraceWorker(items: items)
        let haptic = SpyHapticService()
        let interactor = LetterTraceInteractor(
            childId: "child-1",
            worker: worker,
            hapticService: haptic
        )
        let spy = SpyLetterTracePresenter()
        interactor.presenter = spy
        return (interactor, spy, worker, haptic)
    }

    func test_load_setsItemsAndPresentsResponse() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.load(request: .init(childId: "child-1"))
        XCTAssertEqual(spy.loadCount, 1)
        XCTAssertEqual(sut.items.count, 3)
        XCTAssertEqual(sut.currentItemId, "i1")
    }

    func test_advance_movesToNextItem() async {
        let (sut, spy, _, haptic) = makeSUT()
        await sut.load(request: .init(childId: "child-1"))
        await sut.advance(request: .init(currentItemId: "i1"))
        XCTAssertEqual(spy.lastAdvance?.nextItem?.id, "i2")
        XCTAssertEqual(spy.lastAdvance?.position, 2)
        XCTAssertGreaterThan(haptic.impactCount, 0)
    }

    func test_advance_atEnd_cyclesBackToFirst() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.load(request: .init(childId: "child-1"))
        await sut.advance(request: .init(currentItemId: "i3"))
        XCTAssertEqual(spy.lastAdvance?.nextItem?.id, "i1")
        XCTAssertEqual(spy.lastAdvance?.position, 1)
    }

    func test_score_excellentBand_firesSuccessHaptic() async {
        let (sut, spy, worker, haptic) = makeSUT()
        worker.stubScore = TraceScore(similarity: 0.85)
        await sut.load(request: .init(childId: "child-1"))
        await sut.score(request: .init(
            itemId: "i1",
            userStrokes: [[TracePoint(x: 0.2, y: 0.5), TracePoint(x: 0.8, y: 0.5)]]
        ))
        XCTAssertEqual(spy.scoreCount, 1)
        XCTAssertEqual(spy.lastScore?.score.band, .excellent)
        XCTAssertEqual(haptic.notificationCount, 1)
    }

    func test_score_tryAgainBand_firesWarningHaptic() async {
        let (sut, spy, worker, haptic) = makeSUT()
        worker.stubScore = TraceScore(similarity: 0.20)
        await sut.load(request: .init(childId: "child-1"))
        await sut.score(request: .init(itemId: "i1", userStrokes: [[]]))
        XCTAssertEqual(spy.lastScore?.score.band, .tryAgain)
        XCTAssertEqual(haptic.notificationCount, 1)
    }

    func test_score_goodBand_firesImpactHaptic() async {
        let (sut, spy, worker, haptic) = makeSUT()
        worker.stubScore = TraceScore(similarity: 0.60)
        await sut.load(request: .init(childId: "child-1"))
        await sut.score(request: .init(itemId: "i1", userStrokes: [[]]))
        XCTAssertEqual(spy.lastScore?.score.band, .good)
        XCTAssertEqual(haptic.impactCount, 1)
    }

    func test_traceScore_percentClamps() {
        XCTAssertEqual(TraceScore(similarity: -0.5).percent, 0)
        XCTAssertEqual(TraceScore(similarity: 2.0).percent, 100)
        XCTAssertEqual(TraceScore(similarity: 0.5).percent, 50)
    }
}

// MARK: - Scoring metric tests

final class LetterTraceScoringTests: XCTestCase {

    func test_similarity_perfectMatch_isHigh() {
        let reference: [[TracePoint]] = [[
            TracePoint(x: 0.1, y: 0.5), TracePoint(x: 0.5, y: 0.5), TracePoint(x: 0.9, y: 0.5)
        ]]
        let sim = LetterTraceScoring.similarity(userStrokes: reference, referenceStrokes: reference)
        XCTAssertGreaterThan(sim, 0.95)
    }

    func test_similarity_emptyUserStrokes_returnsZero() {
        let reference: [[TracePoint]] = [[
            TracePoint(x: 0.1, y: 0.5), TracePoint(x: 0.9, y: 0.5)
        ]]
        let sim = LetterTraceScoring.similarity(userStrokes: [], referenceStrokes: reference)
        XCTAssertEqual(sim, 0)
    }

    func test_similarity_completelyOff_isLow() {
        let reference: [[TracePoint]] = [[
            TracePoint(x: 0.1, y: 0.1), TracePoint(x: 0.5, y: 0.1)
        ]]
        let user: [[TracePoint]] = [[
            TracePoint(x: 0.1, y: 0.9), TracePoint(x: 0.5, y: 0.9)
        ]]
        let sim = LetterTraceScoring.similarity(userStrokes: user, referenceStrokes: reference)
        XCTAssertLessThan(sim, 0.7)
    }
}

// MARK: - Corpus tests

final class LetterTraceCorpusTests: XCTestCase {

    func test_corpusLoads_33LettersPlus10Syllables() {
        let items = LetterTraceCorpus.allItems
        XCTAssertGreaterThanOrEqual(items.count, 43)
        let letters = items.filter { $0.kind == .letter }
        let syllables = items.filter { $0.kind == .syllable }
        XCTAssertGreaterThanOrEqual(letters.count, 33)
        XCTAssertGreaterThanOrEqual(syllables.count, 10)
    }
}
