@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubPhonemicWorker: PhonemicListeningWorkerProtocol {
    var response: PhonemicListeningModels.Start.Response
    private(set) var buildCallCount = 0

    init(response: PhonemicListeningModels.Start.Response) {
        self.response = response
    }

    func buildSession(childId: String) async -> PhonemicListeningModels.Start.Response {
        buildCallCount += 1
        return response
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyPhonemicPresenter: PhonemicListeningPresentationLogic, @unchecked Sendable {
    var startCount = 0
    var answerCount = 0
    var lastAnswer: PhonemicListeningModels.Answer.Response?

    func presentStart(response: PhonemicListeningModels.Start.Response) async {
        startCount += 1
    }
    func presentAnswer(response: PhonemicListeningModels.Answer.Response) async {
        answerCount += 1
        lastAnswer = response
    }
}

// MARK: - Helpers

@MainActor
private func makeWord(
    id: String = "w",
    position: PhonemePosition = .start,
    sounds: [String] = ["с", "о", "к"]
) -> PhonemicWord {
    .init(id: id, text: "сок", targetSound: "С", position: position, sounds: sounds)
}

@MainActor
private func makeRounds() -> [PhonemicRound] {
    [
        .init(id: "r1", operation: .position, word: makeWord(position: .start)),
        .init(id: "r2", operation: .count, word: makeWord(sounds: ["к", "о", "т"]))
    ]
}

// MARK: - Interactor Tests

@MainActor
final class PhonemicListeningInteractorTests: XCTestCase {

    private func makeSUT(
        rounds: [PhonemicRound]
    ) -> (PhonemicListeningInteractor, SpyPhonemicPresenter, StubPhonemicWorker, SpyHapticService) {
        let worker = StubPhonemicWorker(response: .init(rounds: rounds))
        let haptic = SpyHapticService()
        let sut = PhonemicListeningInteractor(childId: "child-1", worker: worker, hapticService: haptic)
        let spy = SpyPhonemicPresenter()
        sut.presenter = spy
        return (sut, spy, worker, haptic)
    }

    func test_start_buildsSessionAndPresents() async {
        let (sut, spy, worker, _) = makeSUT(rounds: makeRounds())
        await sut.start(request: .init(childId: "child-1"))
        XCTAssertEqual(worker.buildCallCount, 1)
        XCTAssertEqual(spy.startCount, 1)
        XCTAssertEqual(sut.rounds.count, 2)
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(sut.correctCount, 0)
    }

    func test_answer_positionCorrect_incrementsCorrect() async {
        let (sut, spy, _, haptic) = makeSUT(rounds: makeRounds())
        await sut.start(request: .init(childId: "child-1"))
        // r1 — позиция .start; правильный индекс = 0.
        await sut.answer(request: .init(optionIndex: 0))
        XCTAssertEqual(sut.correctCount, 1)
        XCTAssertEqual(spy.lastAnswer?.wasCorrect, true)
        XCTAssertEqual(haptic.notificationCount, 1)
    }

    func test_answer_positionWrong_doesNotIncrement() async {
        let (sut, spy, _, _) = makeSUT(rounds: makeRounds())
        await sut.start(request: .init(childId: "child-1"))
        await sut.answer(request: .init(optionIndex: 2))
        XCTAssertEqual(sut.correctCount, 0)
        XCTAssertEqual(spy.lastAnswer?.wasCorrect, false)
    }

    func test_answer_advancesThroughRounds() async {
        let (sut, spy, _, _) = makeSUT(rounds: makeRounds())
        await sut.start(request: .init(childId: "child-1"))
        await sut.answer(request: .init(optionIndex: 0))
        XCTAssertEqual(sut.currentIndex, 1)
        XCTAssertEqual(spy.lastAnswer?.isFinished, false)
        XCTAssertNotNil(spy.lastAnswer?.nextRound)
        XCTAssertEqual(spy.lastAnswer?.nextRoundIndex, 1)
    }

    func test_answer_lastRound_marksFinished() async {
        let (sut, spy, _, _) = makeSUT(rounds: makeRounds())
        await sut.start(request: .init(childId: "child-1"))
        await sut.answer(request: .init(optionIndex: 0))
        await sut.answer(request: .init(optionIndex: 1))
        XCTAssertEqual(spy.lastAnswer?.isFinished, true)
        XCTAssertNil(spy.lastAnswer?.nextRound)
        XCTAssertEqual(spy.lastAnswer?.correctCount, 2)
    }

    func test_answer_afterFinish_isIgnored() async {
        let (sut, spy, _, _) = makeSUT(rounds: makeRounds())
        await sut.start(request: .init(childId: "child-1"))
        await sut.answer(request: .init(optionIndex: 0))
        await sut.answer(request: .init(optionIndex: 1))
        let afterFinish = spy.answerCount
        await sut.answer(request: .init(optionIndex: 0))
        XCTAssertEqual(spy.answerCount, afterFinish)
    }

    func test_start_resetsProgress() async {
        let (sut, _, _, _) = makeSUT(rounds: makeRounds())
        await sut.start(request: .init(childId: "child-1"))
        await sut.answer(request: .init(optionIndex: 0))
        await sut.start(request: .init(childId: "child-1"))
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(sut.correctCount, 0)
    }

    func test_correctOptionIndex_countOperation_isMiddle() {
        let round = PhonemicRound(
            id: "c", operation: .count,
            word: .init(id: "w", text: "кот", targetSound: "К",
                        position: .start, sounds: ["к", "о", "т"])
        )
        XCTAssertEqual(PhonemicListeningInteractor.correctOptionIndex(for: round), 1)
    }

    func test_correctOptionIndex_synthesisOperation_isZero() {
        let round = PhonemicRound(
            id: "s", operation: .synthesis,
            word: .init(id: "w", text: "сок", targetSound: "С",
                        position: .start, sounds: ["с", "о", "к"])
        )
        XCTAssertEqual(PhonemicListeningInteractor.correctOptionIndex(for: round), 0)
    }
}

// MARK: - Corpus Tests

final class PhonemicListeningCorpusTests: XCTestCase {

    func test_corpus_hasWordsForEveryOperation() {
        XCTAssertFalse(PhonemicListeningCorpus.positionWords.isEmpty)
        XCTAssertFalse(PhonemicListeningCorpus.countWords.isEmpty)
        XCTAssertFalse(PhonemicListeningCorpus.synthesisWords.isEmpty)
    }

    func test_positionWords_coverAllPositions() {
        let positions = Set(PhonemicListeningCorpus.positionWords.map(\.position))
        XCTAssertEqual(positions, Set(PhonemePosition.allCases))
    }

    func test_soundsMatchSoundCount() {
        for word in PhonemicListeningCorpus.allWords {
            XCTAssertEqual(word.soundCount, word.sounds.count)
            XCTAssertGreaterThanOrEqual(word.soundCount, 3)
        }
    }

    func test_wordIdsAreUnique() {
        let ids = PhonemicListeningCorpus.allWords.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_words_forOperation_returnsEnoughForSession() {
        let words = PhonemicListeningCorpus.words(for: .position, targetSounds: [])
        XCTAssertGreaterThanOrEqual(words.count, PhonemicListeningCorpus.roundsPerSession / 3)
    }

    func test_words_prioritisesTargetSound() {
        let words = PhonemicListeningCorpus.words(for: .position, targetSounds: ["Р"])
        // Первые слова — с целевым звуком Р.
        XCTAssertEqual(words.first?.targetSound, "Р")
    }
}
