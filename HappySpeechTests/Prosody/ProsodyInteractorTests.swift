@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubProsodyWorker: ProsodyWorkerProtocol {
    var response: ProsodyModels.Start.Response
    private(set) var buildCallCount = 0

    init(response: ProsodyModels.Start.Response) {
        self.response = response
    }

    func buildSession(childId: String) async -> ProsodyModels.Start.Response {
        buildCallCount += 1
        return response
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyProsodyPresenter: ProsodyPresentationLogic, @unchecked Sendable {
    var startCount = 0
    var answerCount = 0
    var lastAnswer: ProsodyModels.Answer.Response?

    func presentStart(response: ProsodyModels.Start.Response) async {
        startCount += 1
    }
    func presentAnswer(response: ProsodyModels.Answer.Response) async {
        answerCount += 1
        lastAnswer = response
    }
}

// MARK: - Helpers

@MainActor
private func makePhrase(
    id: String = "p",
    intonation: IntonationType = .declarative
) -> ProsodyPhrase {
    .init(id: id, text: "Кошка спит.", intonation: intonation, theme: "Животные")
}

@MainActor
private func makeRounds() -> [ProsodyRound] {
    [
        .init(id: "r1", stage: .discriminate, phrase: makePhrase(intonation: .declarative)),
        .init(id: "r2", stage: .imitate, phrase: makePhrase(intonation: .interrogative)),
        .init(id: "r3", stage: .produce, phrase: makePhrase(intonation: .exclamatory))
    ]
}

// MARK: - Interactor Tests

@MainActor
final class ProsodyInteractorTests: XCTestCase {

    private func makeSUT(
        rounds: [ProsodyRound]
    ) -> (ProsodyInteractor, SpyProsodyPresenter, StubProsodyWorker, SpyHapticService) {
        let worker = StubProsodyWorker(response: .init(rounds: rounds))
        let haptic = SpyHapticService()
        let sut = ProsodyInteractor(childId: "child-1", worker: worker, hapticService: haptic)
        let spy = SpyProsodyPresenter()
        sut.presenter = spy
        return (sut, spy, worker, haptic)
    }

    func test_start_buildsSessionAndPresents() async {
        let (sut, spy, worker, _) = makeSUT(rounds: makeRounds())
        await sut.start(request: .init(childId: "child-1"))
        XCTAssertEqual(worker.buildCallCount, 1)
        XCTAssertEqual(spy.startCount, 1)
        XCTAssertEqual(sut.rounds.count, 3)
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(sut.correctCount, 0)
    }

    func test_answer_discriminateCorrect_incrementsCorrect() async {
        let (sut, spy, _, haptic) = makeSUT(rounds: makeRounds())
        await sut.start(request: .init(childId: "child-1"))
        // r1 — declarative; правильный индекс = 0.
        await sut.answer(request: .init(optionIndex: 0, voiceAttempted: false))
        XCTAssertEqual(sut.correctCount, 1)
        XCTAssertEqual(spy.lastAnswer?.wasCorrect, true)
        XCTAssertEqual(haptic.notificationCount, 1)
    }

    func test_answer_discriminateWrong_doesNotIncrement() async {
        let (sut, spy, _, _) = makeSUT(rounds: makeRounds())
        await sut.start(request: .init(childId: "child-1"))
        await sut.answer(request: .init(optionIndex: 2, voiceAttempted: false))
        XCTAssertEqual(sut.correctCount, 0)
        XCTAssertEqual(spy.lastAnswer?.wasCorrect, false)
    }

    func test_answer_imitate_voiceAttempted_isCorrect() async {
        let (sut, spy, _, _) = makeSUT(rounds: makeRounds())
        await sut.start(request: .init(childId: "child-1"))
        await sut.answer(request: .init(optionIndex: 0, voiceAttempted: false))
        // r2 — imitate; засчитывается голосовая попытка.
        await sut.answer(request: .init(optionIndex: 0, voiceAttempted: true))
        XCTAssertEqual(spy.lastAnswer?.wasCorrect, true)
    }

    func test_answer_advancesAndFinishes() async {
        let (sut, spy, _, _) = makeSUT(rounds: makeRounds())
        await sut.start(request: .init(childId: "child-1"))
        await sut.answer(request: .init(optionIndex: 0, voiceAttempted: false))
        await sut.answer(request: .init(optionIndex: 0, voiceAttempted: true))
        await sut.answer(request: .init(optionIndex: 0, voiceAttempted: true))
        XCTAssertEqual(spy.lastAnswer?.isFinished, true)
        XCTAssertNil(spy.lastAnswer?.nextRound)
    }

    func test_answer_afterFinish_isIgnored() async {
        let (sut, spy, _, _) = makeSUT(rounds: makeRounds())
        await sut.start(request: .init(childId: "child-1"))
        for _ in 0..<3 {
            await sut.answer(request: .init(optionIndex: 0, voiceAttempted: true))
        }
        let afterFinish = spy.answerCount
        await sut.answer(request: .init(optionIndex: 0, voiceAttempted: true))
        XCTAssertEqual(spy.answerCount, afterFinish)
    }

    func test_correctOptionIndex_matchesIntonationOrder() {
        let round = ProsodyRound(
            id: "r", stage: .discriminate,
            phrase: .init(id: "p", text: "Что это?", intonation: .interrogative, theme: "T")
        )
        XCTAssertEqual(ProsodyInteractor.correctOptionIndex(for: round), 1)
    }
}

// MARK: - Corpus Tests

final class ProsodyCorpusTests: XCTestCase {

    func test_corpus_hasPhrasesForEveryIntonation() {
        for type in IntonationType.allCases {
            XCTAssertFalse(ProsodyCorpus.phrases(of: type).isEmpty)
        }
    }

    func test_phraseIdsAreUnique() {
        let ids = ProsodyCorpus.phrases.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_sessionPhrases_coversAllIntonations() {
        let phrases = ProsodyCorpus.sessionPhrases()
        let types = Set(phrases.map(\.intonation))
        XCTAssertEqual(types, Set(IntonationType.allCases))
    }
}
