@testable import HappySpeech
import XCTest

// MARK: - WordRhymeGameInteractorTests
//
// WordRhymeGameInteractor загружает раунды из словаря через worker и
// фиксирует результаты в AdaptivePlannerService. Тесты используют детермини-
// рованный mock-worker (без обращения к манифесту) и spy-планировщик.

@MainActor
final class WordRhymeGameInteractorTests: XCTestCase {

    // MARK: - Mocks

    private final class MockWorker: WordRhymeGameWorkerProtocol {
        let rounds: [WordRhymeGameModels.Round]
        var lastChildId: String?
        init(rounds: [WordRhymeGameModels.Round]) { self.rounds = rounds }
        func buildRounds(childId: String) async -> [WordRhymeGameModels.Round] {
            lastChildId = childId
            return rounds
        }
    }

    private func makeRound(id: String, correct: String = "ok") -> WordRhymeGameModels.Round {
        WordRhymeGameModels.Round(
            id: id,
            targetWord: "Кошка",
            targetAsset: "word_cat",
            options: [
                WordRhymeGameModels.RhymeOption(id: "ok", word: "Мошка", asset: nil),
                WordRhymeGameModels.RhymeOption(id: "no1", word: "Дом", asset: nil),
                WordRhymeGameModels.RhymeOption(id: "no2", word: "Лук", asset: nil)
            ],
            correctOptionId: correct
        )
    }

    private func makeSUT(
        childId: String = "child-1",
        rounds: [WordRhymeGameModels.Round]? = nil,
        planner: AdaptivePlannerService? = nil
    ) -> (WordRhymeGameInteractor, MockWorker) {
        let worker = MockWorker(rounds: rounds ?? [makeRound(id: "r1"), makeRound(id: "r2")])
        let sut = WordRhymeGameInteractor(childId: childId, worker: worker, adaptivePlanner: planner)
        return (sut, worker)
    }

    // MARK: - Initial / load

    func test_init_storesChildId() {
        let (sut, _) = makeSUT(childId: "kid-11")
        XCTAssertEqual(sut.childId, "kid-11")
    }

    func test_initialState_isNotLoaded() {
        let (sut, _) = makeSUT()
        XCTAssertFalse(sut.state.isLoaded)
        XCTAssertTrue(sut.state.rounds.isEmpty)
    }

    func test_load_withoutWorker_marksLoadedEmpty() async {
        let sut = WordRhymeGameInteractor(childId: "c")
        await sut.load()
        XCTAssertTrue(sut.state.isLoaded)
        XCTAssertTrue(sut.state.isEmpty)
    }

    func test_load_populatesRoundsFromWorker() async {
        let (sut, worker) = makeSUT()
        await sut.load()
        XCTAssertTrue(sut.state.isLoaded)
        XCTAssertEqual(sut.state.rounds.count, 2)
        XCTAssertEqual(sut.state.current?.id, "r1")
        XCTAssertEqual(worker.lastChildId, "child-1")
    }

    // MARK: - correct / wrong

    func test_answer_correct_incrementsScoreAndSetsFeedback() async {
        let (sut, _) = makeSUT()
        await sut.load()
        sut.answer("ok")
        XCTAssertEqual(sut.state.score, 1)
        XCTAssertEqual(sut.state.feedback, .correct)
    }

    func test_answer_correct_autoAdvancesAfterDelay() async {
        let (sut, _) = makeSUT()
        await sut.load()
        sut.answer("ok")
        XCTAssertEqual(sut.state.index, 0)
        try? await Task.sleep(for: .milliseconds(900))
        XCTAssertEqual(sut.state.index, 1)
        XCTAssertEqual(sut.state.feedback, .none)
    }

    func test_answer_wrong_setsWrongFeedbackWithoutScore() async {
        let (sut, _) = makeSUT()
        await sut.load()
        sut.answer("no1")
        XCTAssertEqual(sut.state.feedback, .wrong("no1"))
        XCTAssertEqual(sut.state.score, 0)
    }

    func test_answer_wrong_doesNotAdvance() async {
        let (sut, _) = makeSUT()
        await sut.load()
        sut.answer("no1")
        try? await Task.sleep(for: .milliseconds(900))
        XCTAssertEqual(sut.state.index, 0)
    }

    // MARK: - advance / completion

    func test_advance_pastLastRound_marksComplete() async {
        let (sut, _) = makeSUT()
        await sut.load()
        let count = sut.state.rounds.count
        for _ in 0..<count { sut.advance() }
        XCTAssertTrue(sut.state.isComplete)
        XCTAssertNil(sut.state.current)
    }

    func test_answer_pastEnd_doesNothing() async {
        let (sut, _) = makeSUT()
        await sut.load()
        let count = sut.state.rounds.count
        for _ in 0..<count { sut.advance() }
        sut.answer("anything")
        XCTAssertEqual(sut.state.score, 0)
    }

    // MARK: - progress

    func test_progress_atStart_isZero() async {
        let (sut, _) = makeSUT()
        await sut.load()
        XCTAssertEqual(sut.state.progress, 0)
    }

    func test_progress_advancesProportionally() async {
        let (sut, _) = makeSUT()
        await sut.load()
        sut.advance()
        let expected = 1.0 / Double(sut.state.rounds.count)
        XCTAssertEqual(sut.state.progress, expected, accuracy: 0.0001)
    }

    func test_progress_emptyRounds_isZero() {
        let state = WordRhymeGameModels.ViewState(
            rounds: [], index: 0, feedback: .none, score: 0, isLoaded: true
        )
        XCTAssertEqual(state.progress, 0)
    }

    // MARK: - reset

    func test_reset_keepsRoundsButResetsProgress() async {
        let (sut, _) = makeSUT()
        await sut.load()
        sut.answer("ok")
        sut.advance()
        sut.reset()
        XCTAssertEqual(sut.state.index, 0)
        XCTAssertEqual(sut.state.score, 0)
        XCTAssertEqual(sut.state.feedback, .none)
        XCTAssertEqual(sut.state.rounds.count, 2)
    }
}
