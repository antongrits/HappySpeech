@testable import HappySpeech
import Foundation
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubTempoWorker: SpeechTempoWorkerProtocol {
    var response: SpeechTempoModels.Start.Response
    private(set) var buildCallCount = 0

    init(response: SpeechTempoModels.Start.Response) {
        self.response = response
    }

    func buildSession(childId: String) async -> SpeechTempoModels.Start.Response {
        buildCallCount += 1
        return response
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyTempoPresenter: SpeechTempoPresentationLogic, @unchecked Sendable {
    var startCount = 0
    var finishCount = 0
    var lastFinish: SpeechTempoModels.Finish.Response?

    func presentStart(response: SpeechTempoModels.Start.Response) async {
        startCount += 1
    }
    func presentFinish(response: SpeechTempoModels.Finish.Response) async {
        finishCount += 1
        lastFinish = response
    }
}

// MARK: - Helpers

private let twoRhymes: [TempoRhyme] = [
    .init(id: "rh1", text: "Са-са-са", syllables: ["са", "са", "са"]),
    .init(id: "rh2", text: "Ши-ши-ши", syllables: ["ши", "ши", "ши"])
]

// MARK: - Interactor Tests

@MainActor
final class SpeechTempoInteractorTests: XCTestCase {

    private func makeSUT(
        rhymes: [TempoRhyme] = twoRhymes
    ) -> (SpeechTempoInteractor, SpyTempoPresenter, StubTempoWorker, SpyHapticService) {
        let worker = StubTempoWorker(response: .init(rhymes: rhymes))
        let haptic = SpyHapticService()
        let sut = SpeechTempoInteractor(childId: "child-1", worker: worker, hapticService: haptic)
        let spy = SpyTempoPresenter()
        sut.presenter = spy
        return (sut, spy, worker, haptic)
    }

    func test_start_buildsSessionAndPresents() async {
        let (sut, spy, worker, _) = makeSUT()
        await sut.start(request: .init(childId: "child-1"))
        XCTAssertEqual(worker.buildCallCount, 1)
        XCTAssertEqual(spy.startCount, 1)
        XCTAssertEqual(sut.rhymes.count, 2)
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertTrue(sut.beats.isEmpty)
    }

    func test_recordBeat_accumulatesBeats() async {
        let (sut, _, _, haptic) = makeSUT()
        await sut.start(request: .init(childId: "child-1"))
        await sut.recordBeat(request: .init(timestamp: 0.0))
        await sut.recordBeat(request: .init(timestamp: 0.5))
        XCTAssertEqual(sut.beats.count, 2)
        XCTAssertEqual(haptic.impactCount, 2)
    }

    func test_finishRhyme_evenBeats_ratedSmooth() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.start(request: .init(childId: "child-1"))
        // Ровные интервалы 0.5с — CV = 0 → smooth.
        for index in 0..<5 {
            await sut.recordBeat(request: .init(timestamp: Double(index) * 0.5))
        }
        await sut.finishRhyme(request: .init())
        XCTAssertEqual(spy.lastFinish?.rating, .smooth)
        XCTAssertEqual(sut.smoothCount, 1)
    }

    func test_finishRhyme_unevenBeats_ratedUneven() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.start(request: .init(childId: "child-1"))
        // Рваные интервалы.
        for timestamp in [0.0, 0.1, 1.5, 1.6, 4.0] {
            await sut.recordBeat(request: .init(timestamp: timestamp))
        }
        await sut.finishRhyme(request: .init())
        XCTAssertEqual(spy.lastFinish?.rating, .uneven)
        XCTAssertEqual(sut.smoothCount, 0)
    }

    func test_finishRhyme_advancesAndResetsBeats() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.start(request: .init(childId: "child-1"))
        await sut.recordBeat(request: .init(timestamp: 0.0))
        await sut.finishRhyme(request: .init())
        XCTAssertEqual(sut.currentIndex, 1)
        XCTAssertTrue(sut.beats.isEmpty)
        XCTAssertEqual(spy.lastFinish?.isFinished, false)
        XCTAssertNotNil(spy.lastFinish?.nextRhyme)
    }

    func test_finishRhyme_lastRhyme_marksFinished() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.start(request: .init(childId: "child-1"))
        await sut.finishRhyme(request: .init())
        await sut.finishRhyme(request: .init())
        XCTAssertEqual(spy.lastFinish?.isFinished, true)
        XCTAssertNil(spy.lastFinish?.nextRhyme)
    }

    func test_finishRhyme_afterFinish_isIgnored() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.start(request: .init(childId: "child-1"))
        await sut.finishRhyme(request: .init())
        await sut.finishRhyme(request: .init())
        let afterFinish = spy.finishCount
        await sut.finishRhyme(request: .init())
        XCTAssertEqual(spy.finishCount, afterFinish)
    }

    func test_start_resetsProgress() async {
        let (sut, _, _, _) = makeSUT()
        await sut.start(request: .init(childId: "child-1"))
        await sut.recordBeat(request: .init(timestamp: 0.0))
        await sut.finishRhyme(request: .init())
        await sut.start(request: .init(childId: "child-1"))
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(sut.smoothCount, 0)
        XCTAssertTrue(sut.beats.isEmpty)
    }
}

// MARK: - TempoAnalyzer Tests

final class TempoAnalyzerTests: XCTestCase {

    func test_variationCoefficient_evenBeats_isNearZero() {
        let beats: [TimeInterval] = [0.0, 0.5, 1.0, 1.5, 2.0]
        XCTAssertEqual(TempoAnalyzer.variationCoefficient(of: beats), 0.0, accuracy: 0.001)
    }

    func test_variationCoefficient_tooFewBeats_isZero() {
        XCTAssertEqual(TempoAnalyzer.variationCoefficient(of: [0.0, 1.0]), 0.0)
    }

    func test_variationCoefficient_unevenBeats_isHigh() {
        let beats: [TimeInterval] = [0.0, 0.1, 1.5, 1.6, 4.0]
        XCTAssertGreaterThan(TempoAnalyzer.variationCoefficient(of: beats), 0.45)
    }

    func test_rating_evenBeats_isSmooth() {
        XCTAssertEqual(TempoAnalyzer.rating(for: [0.0, 0.5, 1.0, 1.5]), .smooth)
    }

    func test_rating_tooFewBeats_isUneven() {
        XCTAssertEqual(TempoAnalyzer.rating(for: [0.0, 0.5]), .uneven)
    }

    func test_rating_forCoefficient_thresholds() {
        XCTAssertEqual(TempoAnalyzer.rating(forVariationCoefficient: 0.1), .smooth)
        XCTAssertEqual(TempoAnalyzer.rating(forVariationCoefficient: 0.35), .slightlyUneven)
        XCTAssertEqual(TempoAnalyzer.rating(forVariationCoefficient: 0.8), .uneven)
    }
}

// MARK: - Corpus Tests

final class SpeechTempoCorpusTests: XCTestCase {

    func test_corpus_isNotEmpty() {
        XCTAssertGreaterThanOrEqual(
            SpeechTempoCorpus.rhymes.count,
            SpeechTempoCorpus.rhymesPerSession
        )
    }

    func test_everyRhyme_hasSyllables() {
        for rhyme in SpeechTempoCorpus.rhymes {
            XCTAssertGreaterThanOrEqual(rhyme.syllableCount, 3)
        }
    }

    func test_session_returnsSessionSizedSet() {
        let session = SpeechTempoCorpus.session(for: [])
        XCTAssertEqual(session.count, SpeechTempoCorpus.rhymesPerSession)
    }

    func test_rhymeIdsAreUnique() {
        let ids = SpeechTempoCorpus.rhymes.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }
}
