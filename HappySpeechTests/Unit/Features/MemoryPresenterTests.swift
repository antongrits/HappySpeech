@testable import HappySpeech
import XCTest

// MARK: - MemoryPresenterTests
//
// Phase 2.6.1 v25 — покрытие MemoryPresenter (15 тестов).
// Тестируются все 6 методов: presentLoadSession, presentFlipCard,
// presentTimerTick, presentUseHint, presentCompleteRound, presentCompleteSession.

@MainActor
final class MemoryPresenterTests: XCTestCase {

    // MARK: - DisplaySpy

    @MainActor
    private final class DisplaySpy: MemoryDisplayLogic {
        var loadSessionVM: MemoryModels.LoadSession.ViewModel?
        var flipCardVM: MemoryModels.FlipCard.ViewModel?
        var timerTickVM: MemoryModels.TimerTick.ViewModel?
        var useHintVM: MemoryModels.UseHint.ViewModel?
        var completeRoundVM: MemoryModels.CompleteRound.ViewModel?
        var completeSessionVM: MemoryModels.CompleteSession.ViewModel?

        func displayLoadSession(_ viewModel: MemoryModels.LoadSession.ViewModel) { loadSessionVM = viewModel }
        func displayFlipCard(_ viewModel: MemoryModels.FlipCard.ViewModel) { flipCardVM = viewModel }
        func displayTimerTick(_ viewModel: MemoryModels.TimerTick.ViewModel) { timerTickVM = viewModel }
        func displayUseHint(_ viewModel: MemoryModels.UseHint.ViewModel) { useHintVM = viewModel }
        func displayCompleteRound(_ viewModel: MemoryModels.CompleteRound.ViewModel) { completeRoundVM = viewModel }
        func displayCompleteSession(_ viewModel: MemoryModels.CompleteSession.ViewModel) { completeSessionVM = viewModel }
    }

    private func makeSUT() -> (MemoryPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = MemoryPresenter()
        presenter.viewModel = spy
        return (presenter, spy)
    }

    private func makeCards(count: Int = 4) -> [MemoryCard] {
        (0..<count).map { i in
            MemoryCard(id: "card-\(i)", pairId: "pair-\(i/2)", emoji: "🐟", word: "рыба", soundGroup: "sonorant")
        }
    }

    private func makeRoundResult(
        matched: Int = 4,
        total: Int = 8,
        elapsed: Int = 30,
        timeLimit: Int = 60,
        reason: MemoryGameOverReason = .allMatched,
        megaStreak: Bool = false
    ) -> MemoryRoundResult {
        MemoryRoundResult(
            difficulty: .easy,
            matchedPairs: matched,
            totalPairs: total,
            elapsedSeconds: elapsed,
            timeLimit: timeLimit,
            reason: reason,
            cardStats: [],
            streakBonus: false,
            megaStreakBonus: megaStreak
        )
    }

    // MARK: - presentLoadSession

    func test_presentLoadSession_withName_setsGreeting() {
        let (sut, spy) = makeSUT()
        let response = MemoryModels.LoadSession.Response(
            cards: makeCards(),
            childName: "Маша",
            timeLimit: 60,
            difficulty: .easy,
            roundIndex: 0,
            totalRounds: 3,
            hintsRemaining: 3
        )
        sut.presentLoadSession(response)
        XCTAssertNotNil(spy.loadSessionVM)
        XCTAssertTrue(spy.loadSessionVM?.greeting.contains("Маша") ?? false)
    }

    func test_presentLoadSession_emptyName_setsDefaultGreeting() {
        let (sut, spy) = makeSUT()
        let response = MemoryModels.LoadSession.Response(
            cards: makeCards(),
            childName: "",
            timeLimit: 60,
            difficulty: .easy,
            roundIndex: 0,
            totalRounds: 3,
            hintsRemaining: 3
        )
        sut.presentLoadSession(response)
        XCTAssertFalse(spy.loadSessionVM?.greeting.isEmpty ?? true)
        XCTAssertFalse(spy.loadSessionVM?.greeting.contains("!") == false)
    }

    func test_presentLoadSession_timeLabelFormatted() {
        let (sut, spy) = makeSUT()
        let response = MemoryModels.LoadSession.Response(
            cards: makeCards(),
            childName: "",
            timeLimit: 90,
            difficulty: .medium,
            roundIndex: 1,
            totalRounds: 3,
            hintsRemaining: 2
        )
        sut.presentLoadSession(response)
        XCTAssertEqual(spy.loadSessionVM?.timeLimitLabel, "01:30")
    }

    func test_presentLoadSession_roundLabelContainsIndexAndTotal() {
        let (sut, spy) = makeSUT()
        let response = MemoryModels.LoadSession.Response(
            cards: makeCards(),
            childName: "",
            timeLimit: 60,
            difficulty: .easy,
            roundIndex: 1,
            totalRounds: 3,
            hintsRemaining: 3
        )
        sut.presentLoadSession(response)
        let roundLabel = spy.loadSessionVM?.roundLabel ?? ""
        XCTAssertTrue(roundLabel.contains("2"), "Должен содержать номер раунда (roundIndex+1=2)")
        XCTAssertTrue(roundLabel.contains("3"), "Должен содержать общее кол-во раундов")
    }

    // MARK: - presentFlipCard

    func test_presentFlipCard_gameOver_setsReason() {
        let (sut, spy) = makeSUT()
        let response = MemoryModels.FlipCard.Response(
            cards: makeCards(),
            matchFound: true,
            matchedPairId: "pair-0",
            gameOver: true,
            streakCount: 2,
            megaStreak: false,
            voiceCue: .allDone
        )
        sut.presentFlipCard(response)
        XCTAssertNotNil(spy.flipCardVM?.gameOverReason)
        XCTAssertEqual(spy.flipCardVM?.gameOverReason, .allMatched)
    }

    func test_presentFlipCard_noGameOver_reasonNil() {
        let (sut, spy) = makeSUT()
        let response = MemoryModels.FlipCard.Response(
            cards: makeCards(),
            matchFound: false,
            matchedPairId: nil,
            gameOver: false,
            streakCount: 0,
            megaStreak: false,
            voiceCue: nil
        )
        sut.presentFlipCard(response)
        XCTAssertNil(spy.flipCardVM?.gameOverReason)
    }

    // MARK: - presentTimerTick

    func test_presentTimerTick_aboveWarning_colorGreen() {
        let (sut, spy) = makeSUT()
        sut.presentTimerTick(MemoryModels.TimerTick.Response(remaining: 45, expired: false))
        XCTAssertEqual(spy.timerTickVM?.timerColor, "green")
        XCTAssertEqual(spy.timerTickVM?.timerLabel, "00:45")
    }

    func test_presentTimerTick_orange_range() {
        let (sut, spy) = makeSUT()
        sut.presentTimerTick(MemoryModels.TimerTick.Response(remaining: 15, expired: false))
        XCTAssertEqual(spy.timerTickVM?.timerColor, "orange")
    }

    func test_presentTimerTick_red_range() {
        let (sut, spy) = makeSUT()
        sut.presentTimerTick(MemoryModels.TimerTick.Response(remaining: 5, expired: false))
        XCTAssertEqual(spy.timerTickVM?.timerColor, "red")
    }

    func test_presentTimerTick_expired_setsFlag() {
        let (sut, spy) = makeSUT()
        sut.presentTimerTick(MemoryModels.TimerTick.Response(remaining: 0, expired: true))
        XCTAssertTrue(spy.timerTickVM?.expired ?? false)
    }

    // MARK: - presentUseHint

    func test_presentUseHint_hintsRemain_buttonEnabled() {
        let (sut, spy) = makeSUT()
        let response = MemoryModels.UseHint.Response(
            highlightedCardIds: ["card-0"],
            hintLevel: .single,
            hintsRemaining: 2
        )
        sut.presentUseHint(response)
        XCTAssertTrue(spy.useHintVM?.hintButtonEnabled ?? false)
        XCTAssertEqual(spy.useHintVM?.hintsRemaining, 2)
    }

    func test_presentUseHint_noHintsLeft_buttonDisabled() {
        let (sut, spy) = makeSUT()
        let response = MemoryModels.UseHint.Response(
            highlightedCardIds: [],
            hintLevel: .all,
            hintsRemaining: 0
        )
        sut.presentUseHint(response)
        XCTAssertFalse(spy.useHintVM?.hintButtonEnabled ?? true)
    }

    // MARK: - presentCompleteRound

    func test_presentCompleteRound_highScore_3stars() {
        let (sut, spy) = makeSUT()
        let result = makeRoundResult(matched: 8, total: 8, elapsed: 10, timeLimit: 60)
        sut.presentCompleteRound(MemoryModels.CompleteRound.Request(result: result, hasNextRound: true))
        XCTAssertEqual(spy.completeRoundVM?.starsEarned, 3)
        XCTAssertTrue(spy.completeRoundVM?.hasNextRound ?? false)
    }

    func test_presentCompleteRound_megaStreak_specialMessage() {
        let (sut, spy) = makeSUT()
        let result = makeRoundResult(matched: 4, total: 8, elapsed: 30, timeLimit: 60, megaStreak: true)
        sut.presentCompleteRound(MemoryModels.CompleteRound.Request(result: result, hasNextRound: false))
        let message = spy.completeRoundVM?.message ?? ""
        XCTAssertFalse(message.isEmpty)
        XCTAssertTrue(message.contains("пять") || message.contains("Пять") || message.contains("чемпион"))
    }

    func test_presentCompleteRound_timeExpired_zeroStars() {
        let (sut, spy) = makeSUT()
        let result = makeRoundResult(matched: 0, total: 8, elapsed: 60, timeLimit: 60, reason: .timeExpired)
        sut.presentCompleteRound(MemoryModels.CompleteRound.Request(result: result, hasNextRound: false))
        XCTAssertEqual(spy.completeRoundVM?.starsEarned, 0)
        let message = spy.completeRoundVM?.message ?? ""
        XCTAssertFalse(message.isEmpty)
    }

    // MARK: - presentCompleteSession

    func test_presentCompleteSession_nonZeroPairs_setsLabel() {
        let (sut, spy) = makeSUT()
        let request = MemoryModels.CompleteSession.Request(
            matchedPairs: 20,
            elapsedSeconds: 150,
            reason: .allMatched
        )
        sut.presentCompleteSession(request)
        XCTAssertNotNil(spy.completeSessionVM)
        XCTAssertFalse(spy.completeSessionVM?.message.isEmpty ?? true)
    }

    func test_presentCompleteSession_zeroPairs_noNaN() {
        let (sut, spy) = makeSUT()
        let request = MemoryModels.CompleteSession.Request(
            matchedPairs: 0,
            elapsedSeconds: 60,
            reason: .timeExpired
        )
        sut.presentCompleteSession(request)
        let score = spy.completeSessionVM?.finalScore ?? -1
        XCTAssertFalse(score.isNaN)
        XCTAssertGreaterThanOrEqual(score, 0)
        XCTAssertLessThanOrEqual(score, 1)
    }
}
