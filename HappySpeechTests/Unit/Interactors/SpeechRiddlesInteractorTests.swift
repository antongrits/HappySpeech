@testable import HappySpeech
import XCTest

// MARK: - SpeechRiddlesInteractorTests
//
// SpeechRiddlesInteractor is a thin VIP MVP variant (@Observable). A correct
// answer increments score, shows .correct feedback and auto-advances after a
// ~700ms delay; a wrong answer shows .wrong(optionId) without advancing. Tests
// cover scoring, feedback states, the async auto-advance, manual advance, the
// progress/isComplete computeds and reset().

@MainActor
final class SpeechRiddlesInteractorTests: XCTestCase {

    private func makeSUT(childId: String = "child-1") -> SpeechRiddlesInteractor {
        SpeechRiddlesInteractor(childId: childId)
    }

    private func correctId(_ sut: SpeechRiddlesInteractor) -> String {
        sut.state.current!.correctOptionId
    }

    private func wrongId(_ sut: SpeechRiddlesInteractor) -> String {
        let current = sut.state.current!
        return current.options.first { $0.id != current.correctOptionId }!.id
    }

    // MARK: - Initial state

    func test_init_storesChildId() {
        let sut = makeSUT(childId: "kid-riddle")
        XCTAssertEqual(sut.childId, "kid-riddle")
    }

    func test_initialState_matchesInitial() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state, .initial)
    }

    func test_initialState_zeroScore() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.score, 0)
    }

    func test_initialState_feedbackNone() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.feedback, .none)
    }

    func test_initialState_currentIsFirstRiddle() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.current?.id, "r1")
    }

    func test_initialState_progressZero() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.progress, 0, accuracy: 0.0001)
    }

    func test_initialState_notComplete() {
        let sut = makeSUT()
        XCTAssertFalse(sut.state.isComplete)
    }

    // MARK: - wrong answer

    func test_answer_wrong_setsWrongFeedback() {
        let sut = makeSUT()
        let wrong = wrongId(sut)
        sut.answer(wrong)
        XCTAssertEqual(sut.state.feedback, .wrong(wrong))
    }

    func test_answer_wrong_doesNotIncrementScore() {
        let sut = makeSUT()
        sut.answer(wrongId(sut))
        XCTAssertEqual(sut.state.score, 0)
    }

    func test_answer_wrong_doesNotAdvance() {
        let sut = makeSUT()
        sut.answer(wrongId(sut))
        XCTAssertEqual(sut.state.currentIndex, 0)
    }

    // MARK: - correct answer (immediate effects)

    func test_answer_correct_incrementsScoreImmediately() {
        let sut = makeSUT()
        sut.answer(correctId(sut))
        XCTAssertEqual(sut.state.score, 1)
    }

    func test_answer_correct_setsCorrectFeedbackImmediately() {
        let sut = makeSUT()
        sut.answer(correctId(sut))
        XCTAssertEqual(sut.state.feedback, .correct)
    }

    func test_answer_correct_doesNotAdvanceSynchronously() {
        let sut = makeSUT()
        sut.answer(correctId(sut))
        // Advance happens after ~700ms; immediately it is still on the same riddle.
        XCTAssertEqual(sut.state.currentIndex, 0)
    }

    // MARK: - correct answer (async auto-advance)

    func test_answer_correct_autoAdvancesAfterDelay() async {
        let sut = makeSUT()
        sut.answer(correctId(sut))
        try? await Task.sleep(for: .milliseconds(900))
        XCTAssertEqual(sut.state.currentIndex, 1)
        XCTAssertEqual(sut.state.feedback, .none)
    }

    func test_answer_correct_autoAdvanceKeepsScore() async {
        let sut = makeSUT()
        sut.answer(correctId(sut))
        try? await Task.sleep(for: .milliseconds(900))
        XCTAssertEqual(sut.state.score, 1)
    }

    // MARK: - advance & completion

    func test_advance_movesToNextRiddle() {
        let sut = makeSUT()
        sut.advance()
        XCTAssertEqual(sut.state.currentIndex, 1)
        XCTAssertEqual(sut.state.feedback, .none)
    }

    func test_advance_pastLastRiddle_marksComplete() {
        let sut = makeSUT()
        let count = sut.state.riddles.count
        for _ in 0..<count { sut.advance() }
        XCTAssertTrue(sut.state.isComplete)
        XCTAssertNil(sut.state.current)
    }

    func test_progress_isFractionOfRiddlesAnswered() {
        let sut = makeSUT()
        sut.advance()
        let expected = 1.0 / Double(sut.state.riddles.count)
        XCTAssertEqual(sut.state.progress, expected, accuracy: 0.0001)
    }

    func test_progress_emptyRiddles_isZero() {
        let state = SpeechRiddlesModels.ViewState(riddles: [], currentIndex: 0, feedback: .none, score: 0)
        XCTAssertEqual(state.progress, 0)
    }

    // MARK: - reset

    func test_reset_restoresInitialState() {
        let sut = makeSUT()
        sut.advance()
        sut.answer(correctId(sut))
        sut.reset()
        XCTAssertEqual(sut.state, .initial)
    }

    // MARK: - Feedback equality

    func test_feedback_wrongCarriesOptionId() {
        XCTAssertEqual(SpeechRiddlesModels.Feedback.wrong("a"), .wrong("a"))
        XCTAssertNotEqual(SpeechRiddlesModels.Feedback.wrong("a"), .wrong("b"))
        XCTAssertNotEqual(SpeechRiddlesModels.Feedback.correct, .none)
    }
}
