@testable import HappySpeech
import XCTest

// MARK: - LyalyaPersonalCoachInteractorTests
//
// LyalyaPersonalCoachInteractor is a thin VIP MVP variant (@Observable). It walks
// through a fixed pool of quiz rounds: a correct answer bumps correctCount and
// shows .correct, a wrong answer shows .tryAgain without scoring, and next()
// advances the cursor (resetting the reaction). Tests cover scoring, the reaction
// states, the current/isFinished computeds, full traversal and guard branches.

@MainActor
final class LyalyaPersonalCoachInteractorTests: XCTestCase {

    private func makeSUT(childId: String = "child-1") -> LyalyaPersonalCoachInteractor {
        LyalyaPersonalCoachInteractor(childId: childId)
    }

    private func correctIndex(_ sut: LyalyaPersonalCoachInteractor) -> Int {
        sut.current!.correctIndex
    }

    private func wrongIndex(_ sut: LyalyaPersonalCoachInteractor) -> Int {
        let round = sut.current!
        return (0..<round.options.count).first { $0 != round.correctIndex }!
    }

    // MARK: - Initial state

    func test_init_storesChildId() {
        let sut = makeSUT(childId: "kid-coach")
        XCTAssertEqual(sut.childId, "kid-coach")
    }

    func test_init_startsAtFirstRound() {
        let sut = makeSUT()
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(sut.current?.id, 1)
    }

    func test_init_reactionNone() {
        let sut = makeSUT()
        XCTAssertEqual(sut.reaction, .none)
    }

    func test_init_correctCountZero() {
        let sut = makeSUT()
        XCTAssertEqual(sut.correctCount, 0)
    }

    func test_init_notFinished() {
        let sut = makeSUT()
        XCTAssertFalse(sut.isFinished)
    }

    func test_seedRounds_areNonEmptyAndWellFormed() {
        let sut = makeSUT()
        XCTAssertFalse(sut.rounds.isEmpty)
        for round in sut.rounds {
            XCTAssertFalse(round.question.isEmpty)
            XCTAssertFalse(round.options.isEmpty)
            XCTAssertTrue(round.options.indices.contains(round.correctIndex),
                          "correctIndex out of bounds for round \(round.id)")
        }
    }

    // MARK: - answer (correct)

    func test_answer_correct_incrementsCorrectCount() {
        let sut = makeSUT()
        sut.answer(correctIndex(sut))
        XCTAssertEqual(sut.correctCount, 1)
    }

    func test_answer_correct_setsCorrectReaction() {
        let sut = makeSUT()
        sut.answer(correctIndex(sut))
        XCTAssertEqual(sut.reaction, .correct)
    }

    func test_answer_correct_doesNotAdvance() {
        let sut = makeSUT()
        sut.answer(correctIndex(sut))
        XCTAssertEqual(sut.currentIndex, 0)
    }

    // MARK: - answer (wrong)

    func test_answer_wrong_setsTryAgainReaction() {
        let sut = makeSUT()
        sut.answer(wrongIndex(sut))
        XCTAssertEqual(sut.reaction, .tryAgain)
    }

    func test_answer_wrong_doesNotScore() {
        let sut = makeSUT()
        sut.answer(wrongIndex(sut))
        XCTAssertEqual(sut.correctCount, 0)
    }

    func test_answer_wrongThenCorrect_onlyCountsCorrect() {
        let sut = makeSUT()
        sut.answer(wrongIndex(sut))
        sut.answer(correctIndex(sut))
        XCTAssertEqual(sut.correctCount, 1)
        XCTAssertEqual(sut.reaction, .correct)
    }

    // MARK: - answer guard (finished)

    func test_answer_afterFinished_isIgnored() {
        let sut = makeSUT()
        let total = sut.rounds.count
        for _ in 0..<total { sut.next() }
        XCTAssertTrue(sut.isFinished)
        sut.answer(0)
        XCTAssertEqual(sut.correctCount, 0)
        XCTAssertEqual(sut.reaction, .none)
    }

    // MARK: - next

    func test_next_advancesIndex() {
        let sut = makeSUT()
        sut.next()
        XCTAssertEqual(sut.currentIndex, 1)
        XCTAssertEqual(sut.current?.id, 2)
    }

    func test_next_resetsReaction() {
        let sut = makeSUT()
        sut.answer(correctIndex(sut))
        sut.next()
        XCTAssertEqual(sut.reaction, .none)
    }

    func test_next_pastLastRound_marksFinished() {
        let sut = makeSUT()
        let total = sut.rounds.count
        for _ in 0..<total { sut.next() }
        XCTAssertTrue(sut.isFinished)
        XCTAssertNil(sut.current)
    }

    // MARK: - full perfect playthrough

    func test_fullPerfectPlaythrough_scoresEveryRound() {
        let sut = makeSUT()
        let total = sut.rounds.count
        for _ in 0..<total {
            sut.answer(correctIndex(sut))
            sut.next()
        }
        XCTAssertEqual(sut.correctCount, total)
        XCTAssertTrue(sut.isFinished)
    }

    // MARK: - Reaction equality

    func test_reaction_equatable() {
        XCTAssertEqual(LyalyaPersonalCoachModels.Reaction.correct, .correct)
        XCTAssertNotEqual(LyalyaPersonalCoachModels.Reaction.correct, .tryAgain)
        XCTAssertNotEqual(LyalyaPersonalCoachModels.Reaction.none, .tryAgain)
    }
}
