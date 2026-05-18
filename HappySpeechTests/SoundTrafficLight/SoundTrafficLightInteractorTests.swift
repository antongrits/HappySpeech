@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubTrafficLightWorker: SoundTrafficLightWorkerProtocol {
    var response: SoundTrafficLightModels.Start.Response
    private(set) var buildCallCount = 0

    init(response: SoundTrafficLightModels.Start.Response) {
        self.response = response
    }

    func buildSession(childId: String) async -> SoundTrafficLightModels.Start.Response {
        buildCallCount += 1
        return response
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyTrafficLightPresenter: SoundTrafficLightPresentationLogic, @unchecked Sendable {
    var startCount = 0
    var sortCount = 0
    var lastSort: SoundTrafficLightModels.Sort.Response?

    func presentStart(response: SoundTrafficLightModels.Start.Response) async {
        startCount += 1
    }
    func presentSort(response: SoundTrafficLightModels.Sort.Response) async {
        sortCount += 1
        lastSort = response
    }
}

// MARK: - Helpers

@MainActor
private func makeResponse(rounds: [TrafficLightRound]) -> SoundTrafficLightModels.Start.Response {
    .init(
        pair: .init(id: "p", soundA: "С", soundB: "Ш",
                    wordsA: ["сок"], wordsB: ["шар"]),
        rounds: rounds
    )
}

private let twoRounds: [TrafficLightRound] = [
    .init(id: "r1", word: "сок", belongsToA: true),
    .init(id: "r2", word: "шар", belongsToA: false)
]

// MARK: - Interactor Tests

@MainActor
final class SoundTrafficLightInteractorTests: XCTestCase {

    private func makeSUT(
        rounds: [TrafficLightRound]
    ) -> (SoundTrafficLightInteractor, SpyTrafficLightPresenter, StubTrafficLightWorker, SpyHapticService) {
        let worker = StubTrafficLightWorker(response: makeResponse(rounds: rounds))
        let haptic = SpyHapticService()
        let sut = SoundTrafficLightInteractor(childId: "child-1", worker: worker, hapticService: haptic)
        let spy = SpyTrafficLightPresenter()
        sut.presenter = spy
        return (sut, spy, worker, haptic)
    }

    func test_start_buildsSessionAndPresents() async {
        let (sut, spy, worker, _) = makeSUT(rounds: twoRounds)
        await sut.start(request: .init(childId: "child-1"))
        XCTAssertEqual(worker.buildCallCount, 1)
        XCTAssertEqual(spy.startCount, 1)
        XCTAssertEqual(sut.rounds.count, 2)
        XCTAssertEqual(sut.currentIndex, 0)
    }

    func test_sort_correctAnswer_incrementsCorrectCount() async {
        let (sut, spy, _, haptic) = makeSUT(rounds: twoRounds)
        await sut.start(request: .init(childId: "child-1"))
        // r1 = "сок" belongs to A; picking garage A is correct.
        await sut.sort(request: .init(pickedGarageA: true))
        XCTAssertEqual(sut.correctCount, 1)
        XCTAssertEqual(spy.lastSort?.wasCorrect, true)
        XCTAssertEqual(haptic.notificationCount, 1)
    }

    func test_sort_wrongAnswer_doesNotIncrementCorrect() async {
        let (sut, spy, _, _) = makeSUT(rounds: twoRounds)
        await sut.start(request: .init(childId: "child-1"))
        // r1 belongs to A; picking garage B is wrong.
        await sut.sort(request: .init(pickedGarageA: false))
        XCTAssertEqual(sut.correctCount, 0)
        XCTAssertEqual(spy.lastSort?.wasCorrect, false)
    }

    func test_sort_advancesThroughRounds() async {
        let (sut, spy, _, _) = makeSUT(rounds: twoRounds)
        await sut.start(request: .init(childId: "child-1"))
        await sut.sort(request: .init(pickedGarageA: true))
        XCTAssertEqual(sut.currentIndex, 1)
        XCTAssertEqual(spy.lastSort?.isFinished, false)
        XCTAssertNotNil(spy.lastSort?.nextRound)
        XCTAssertEqual(spy.lastSort?.nextRoundIndex, 1)
    }

    func test_sort_lastRound_marksFinished() async {
        let (sut, spy, _, _) = makeSUT(rounds: twoRounds)
        await sut.start(request: .init(childId: "child-1"))
        await sut.sort(request: .init(pickedGarageA: true))
        await sut.sort(request: .init(pickedGarageA: false))
        XCTAssertEqual(spy.lastSort?.isFinished, true)
        XCTAssertNil(spy.lastSort?.nextRound)
        XCTAssertNil(spy.lastSort?.nextRoundIndex)
        XCTAssertEqual(spy.lastSort?.correctCount, 2)
    }

    func test_sort_afterFinish_isIgnored() async {
        let (sut, spy, _, _) = makeSUT(rounds: twoRounds)
        await sut.start(request: .init(childId: "child-1"))
        await sut.sort(request: .init(pickedGarageA: true))
        await sut.sort(request: .init(pickedGarageA: false))
        let countAfterFinish = spy.sortCount
        await sut.sort(request: .init(pickedGarageA: true))
        XCTAssertEqual(spy.sortCount, countAfterFinish)
    }

    func test_start_resetsProgress() async {
        let (sut, _, _, _) = makeSUT(rounds: twoRounds)
        await sut.start(request: .init(childId: "child-1"))
        await sut.sort(request: .init(pickedGarageA: true))
        await sut.start(request: .init(childId: "child-1"))
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(sut.correctCount, 0)
    }
}

// MARK: - Corpus Tests

final class SoundTrafficLightCorpusTests: XCTestCase {

    func test_corpus_hasEightPairs() {
        XCTAssertEqual(SoundTrafficLightCorpus.pairs.count, 8)
    }

    func test_corpus_pairsHaveWordsForBothSounds() {
        for pair in SoundTrafficLightCorpus.pairs {
            XCTAssertGreaterThanOrEqual(pair.wordsA.count, SoundTrafficLightCorpus.roundsPerSession / 2)
            XCTAssertGreaterThanOrEqual(pair.wordsB.count, SoundTrafficLightCorpus.roundsPerSession / 2)
        }
    }

    func test_recommendedPair_matchesTargetSound() {
        let pair = SoundTrafficLightCorpus.recommendedPair(for: ["Р"])
        XCTAssertTrue(pair.soundA == "Р" || pair.soundB == "Р")
    }

    func test_recommendedPair_unknownSound_returnsDefault() {
        let pair = SoundTrafficLightCorpus.recommendedPair(for: ["Я"])
        XCTAssertEqual(pair.id, SoundTrafficLightCorpus.pairs[0].id)
    }

    func test_pairIdsAreUnique() {
        let ids = SoundTrafficLightCorpus.pairs.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }
}
