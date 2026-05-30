@testable import HappySpeech
import XCTest

// MARK: - PalindromeHunterInteractorTests
//
// PalindromeHunterInteractor is a thin VIP MVP variant (@Observable). pick(_:)
// scores against the round's declared `palindrome`, then advances (clamped to
// rounds.count). Tests cover correct/wrong scoring, advancement, completion and
// the progress computed.

@MainActor
final class PalindromeHunterInteractorTests: XCTestCase {

    private func makeSUT(childId: String = "child-1") -> PalindromeHunterInteractor {
        PalindromeHunterInteractor(childId: childId)
    }

    // MARK: - Initial state

    func test_init_storesChildId() {
        let sut = makeSUT(childId: "kid-13")
        XCTAssertEqual(sut.childId, "kid-13")
    }

    func test_initialState_matchesInitial() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state, .initial)
    }

    func test_initialState_startsAtFirstRound() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.currentRoundIndex, 0)
        XCTAssertEqual(sut.state.correctCount, 0)
        XCTAssertEqual(sut.state.currentRound?.id, 0)
        XCTAssertEqual(sut.state.currentRound?.palindrome, "шалаш")
    }

    // MARK: - pick: correct

    func test_pick_correctWord_returnsTrueAndScores() {
        let sut = makeSUT()
        let correct = sut.state.currentRound!.palindrome
        let result = sut.pick(correct)
        XCTAssertTrue(result)
        XCTAssertEqual(sut.state.correctCount, 1)
    }

    func test_pick_advancesToNextRound() {
        let sut = makeSUT()
        let correct = sut.state.currentRound!.palindrome
        _ = sut.pick(correct)
        XCTAssertEqual(sut.state.currentRoundIndex, 1)
        XCTAssertEqual(sut.state.currentRound?.id, 1)
    }

    // MARK: - pick: wrong

    func test_pick_wrongWord_returnsFalseAndDoesNotScore() {
        let sut = makeSUT()
        let wrong = sut.state.currentRound!.words.first { $0 != sut.state.currentRound!.palindrome }!
        let result = sut.pick(wrong)
        XCTAssertFalse(result)
        XCTAssertEqual(sut.state.correctCount, 0)
    }

    func test_pick_wrongWord_stillAdvances() {
        let sut = makeSUT()
        let wrong = sut.state.currentRound!.words.first { $0 != sut.state.currentRound!.palindrome }!
        _ = sut.pick(wrong)
        XCTAssertEqual(sut.state.currentRoundIndex, 1)
    }

    // MARK: - completion / clamping

    func test_pick_allRoundsCorrect_scoresEach() {
        let sut = makeSUT()
        let total = sut.state.rounds.count
        for _ in 0..<total {
            guard let round = sut.state.currentRound else { break }
            _ = sut.pick(round.palindrome)
        }
        XCTAssertEqual(sut.state.correctCount, total)
        XCTAssertEqual(sut.state.currentRoundIndex, total)
        XCTAssertNil(sut.state.currentRound)
    }

    func test_pick_afterLastRound_returnsFalseAndDoesNotOverflow() {
        let sut = makeSUT()
        let total = sut.state.rounds.count
        for _ in 0..<total {
            guard let round = sut.state.currentRound else { break }
            _ = sut.pick(round.palindrome)
        }
        // Now currentRound == nil → pick guards out, returns false, index stays clamped.
        let result = sut.pick("anything")
        XCTAssertFalse(result)
        XCTAssertEqual(sut.state.currentRoundIndex, total)
    }

    // MARK: - progress

    func test_progress_atStart_isZero() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.progress, 0)
    }

    func test_progress_advancesProportionally() {
        let sut = makeSUT()
        _ = sut.pick(sut.state.currentRound!.palindrome)
        let expected = 1.0 / Double(sut.state.rounds.count)
        XCTAssertEqual(sut.state.progress, expected, accuracy: 0.0001)
    }

    func test_progress_emptyRounds_isZero() {
        let state = PalindromeHunterModels.ViewState(rounds: [], currentRoundIndex: 0, correctCount: 0)
        XCTAssertEqual(state.progress, 0)
    }

    // MARK: - Round.isPalindrome heuristic

    func test_round_isPalindrome_detectsRealPalindrome() {
        let round = PalindromeHunterModels.ViewState.initial.rounds[0]
        XCTAssertTrue(round.isPalindrome("шалаш"))
        XCTAssertFalse(round.isPalindrome("забор"))
    }

    func test_round_isPalindrome_isCaseInsensitive() {
        let round = PalindromeHunterModels.ViewState.initial.rounds[0]
        XCTAssertTrue(round.isPalindrome("ШаЛаШ"))
    }

    // MARK: - reset

    func test_reset_restoresInitial() {
        let sut = makeSUT()
        _ = sut.pick(sut.state.currentRound!.palindrome)
        sut.reset()
        XCTAssertEqual(sut.state, .initial)
    }
}
