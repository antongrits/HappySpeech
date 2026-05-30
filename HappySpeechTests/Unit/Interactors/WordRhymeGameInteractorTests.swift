@testable import HappySpeech
import XCTest

// MARK: - WordRhymeGameInteractorTests
//
// WordRhymeGameInteractor is a thin VIP MVP variant (@Observable). A correct
// answer bumps the score and auto-advances after 700ms; a wrong answer records
// .wrong feedback without advancing. Tests cover both paths plus the computed
// current/isComplete/progress helpers.

@MainActor
final class WordRhymeGameInteractorTests: XCTestCase {

    private func makeSUT(childId: String = "child-1") -> WordRhymeGameInteractor {
        WordRhymeGameInteractor(childId: childId)
    }

    // MARK: - Initial state

    func test_init_storesChildId() {
        let sut = makeSUT(childId: "kid-11")
        XCTAssertEqual(sut.childId, "kid-11")
    }

    func test_initialState_matchesInitial() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state, .initial)
    }

    func test_initialState_startsAtFirstRound() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.index, 0)
        XCTAssertEqual(sut.state.score, 0)
        XCTAssertEqual(sut.state.feedback, .none)
        XCTAssertEqual(sut.state.current?.id, "r1")
        XCTAssertFalse(sut.state.isComplete)
    }

    // MARK: - correct answer

    func test_answer_correct_incrementsScoreAndSetsFeedback() {
        let sut = makeSUT()
        let correct = sut.state.current!.correctOptionId
        sut.answer(correct)
        XCTAssertEqual(sut.state.score, 1)
        XCTAssertEqual(sut.state.feedback, .correct)
    }

    func test_answer_correct_autoAdvancesAfterDelay() async {
        let sut = makeSUT()
        let correct = sut.state.current!.correctOptionId
        sut.answer(correct)
        XCTAssertEqual(sut.state.index, 0) // not advanced yet
        try? await Task.sleep(for: .milliseconds(900))
        XCTAssertEqual(sut.state.index, 1)
        XCTAssertEqual(sut.state.feedback, .none)
    }

    // MARK: - wrong answer

    func test_answer_wrong_setsWrongFeedbackWithOptionId() {
        let sut = makeSUT()
        let wrong = sut.state.current!.options.first { $0.id != sut.state.current!.correctOptionId }!.id
        sut.answer(wrong)
        XCTAssertEqual(sut.state.feedback, .wrong(wrong))
    }

    func test_answer_wrong_doesNotIncrementScore() {
        let sut = makeSUT()
        let wrong = sut.state.current!.options.first { $0.id != sut.state.current!.correctOptionId }!.id
        sut.answer(wrong)
        XCTAssertEqual(sut.state.score, 0)
    }

    func test_answer_wrong_doesNotAdvance() async {
        let sut = makeSUT()
        let wrong = sut.state.current!.options.first { $0.id != sut.state.current!.correctOptionId }!.id
        sut.answer(wrong)
        try? await Task.sleep(for: .milliseconds(900))
        XCTAssertEqual(sut.state.index, 0)
    }

    // MARK: - advance / completion

    func test_advance_movesToNextRoundAndClearsFeedback() {
        let sut = makeSUT()
        sut.state.feedback = .correct
        sut.advance()
        XCTAssertEqual(sut.state.index, 1)
        XCTAssertEqual(sut.state.feedback, .none)
    }

    func test_advance_pastLastRound_marksComplete() {
        let sut = makeSUT()
        let count = sut.state.rounds.count
        for _ in 0..<count { sut.advance() }
        XCTAssertTrue(sut.state.isComplete)
        XCTAssertNil(sut.state.current)
    }

    func test_answer_pastEnd_doesNothing() {
        let sut = makeSUT()
        let count = sut.state.rounds.count
        for _ in 0..<count { sut.advance() }
        // current is nil → answer guard returns early.
        sut.answer("anything")
        XCTAssertEqual(sut.state.score, 0)
        XCTAssertEqual(sut.state.feedback, .none)
    }

    // MARK: - progress

    func test_progress_atStart_isZero() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.progress, 0)
    }

    func test_progress_advancesProportionally() {
        let sut = makeSUT()
        sut.advance()
        let expected = 1.0 / Double(sut.state.rounds.count)
        XCTAssertEqual(sut.state.progress, expected, accuracy: 0.0001)
    }

    func test_progress_emptyRounds_isZero() {
        let state = WordRhymeGameModels.ViewState(rounds: [], index: 0, feedback: .none, score: 0)
        XCTAssertEqual(state.progress, 0)
    }

    // MARK: - reset

    func test_reset_restoresInitial() {
        let sut = makeSUT()
        let correct = sut.state.current!.correctOptionId
        sut.answer(correct)
        sut.advance()
        sut.reset()
        XCTAssertEqual(sut.state, .initial)
    }
}
