@testable import HappySpeech
import XCTest

// MARK: - MinimalPairsPresenterTests
//
// Phase 2.6.1 v25 — покрытие MinimalPairsPresenter (13 тестов).
// Тестируются все 7 методов: presentLoadSession, presentStartRound,
// presentSelectOption, presentReplayWord, presentHint,
// presentBonusRoundAdded, presentCompleteSession.

@MainActor
final class MinimalPairsPresenterTests: XCTestCase {

    // MARK: - DisplaySpy

    @MainActor
    private final class DisplaySpy: MinimalPairsDisplayLogic {
        var loadSessionVM: MinimalPairsModels.LoadSession.ViewModel?
        var startRoundVM: MinimalPairsModels.StartRound.ViewModel?
        var selectOptionVM: MinimalPairsModels.SelectOption.ViewModel?
        var replayWordVM: MinimalPairsModels.ReplayWord.ViewModel?
        var hintVM: MinimalPairsModels.RequestHint.ViewModel?
        var bonusRoundVM: MinimalPairsModels.BonusRoundAdded.ViewModel?
        var completeSessionVM: MinimalPairsModels.CompleteSession.ViewModel?

        func displayLoadSession(_ viewModel: MinimalPairsModels.LoadSession.ViewModel) { loadSessionVM = viewModel }
        func displayStartRound(_ viewModel: MinimalPairsModels.StartRound.ViewModel) { startRoundVM = viewModel }
        func displaySelectOption(_ viewModel: MinimalPairsModels.SelectOption.ViewModel) { selectOptionVM = viewModel }
        func displayReplayWord(_ viewModel: MinimalPairsModels.ReplayWord.ViewModel) { replayWordVM = viewModel }
        func displayHint(_ viewModel: MinimalPairsModels.RequestHint.ViewModel) { hintVM = viewModel }
        func displayBonusRoundAdded(_ viewModel: MinimalPairsModels.BonusRoundAdded.ViewModel) { bonusRoundVM = viewModel }
        func displayCompleteSession(_ viewModel: MinimalPairsModels.CompleteSession.ViewModel) { completeSessionVM = viewModel }
    }

    private func makeSUT() -> (MinimalPairsPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = MinimalPairsPresenter()
        presenter.viewModel = spy
        return (presenter, spy)
    }

    private func makePair() -> MinimalPairRound {
        MinimalPairRound(
            id: "pair-sh-s",
            targetWord: "шар",
            foilWord: "сар",
            targetEmoji: "balloon.fill",
            foilEmoji: "word_flower",
            soundContrast: "С-Ш",
            targetIsLeft: true
        )
    }

    // MARK: - presentLoadSession

    func test_presentLoadSession_withName_greetingContainsName() {
        let (sut, spy) = makeSUT()
        let response = MinimalPairsModels.LoadSession.Response(
            rounds: [],
            childName: "Катя",
            totalRounds: 5
        )
        sut.presentLoadSession(response)
        XCTAssertTrue(spy.loadSessionVM?.greeting.contains("Катя") ?? false)
    }

    func test_presentLoadSession_emptyName_defaultGreeting() {
        let (sut, spy) = makeSUT()
        let response = MinimalPairsModels.LoadSession.Response(
            rounds: [],
            childName: "",
            totalRounds: 5
        )
        sut.presentLoadSession(response)
        XCTAssertFalse(spy.loadSessionVM?.greeting.isEmpty ?? true)
        XCTAssertEqual(spy.loadSessionVM?.totalRounds, 5)
    }

    // MARK: - presentStartRound

    func test_presentStartRound_progressLabelContainsNumbers() {
        let (sut, spy) = makeSUT()
        let response = MinimalPairsModels.StartRound.Response(
            pair: makePair(),
            roundNumber: 2,
            total: 5,
            hintsAvailable: 3
        )
        sut.presentStartRound(response)
        let progress = spy.startRoundVM?.progressLabel ?? ""
        XCTAssertTrue(progress.contains("2"))
        XCTAssertTrue(progress.contains("5"))
    }

    func test_presentStartRound_promptContainsTargetWord() {
        let (sut, spy) = makeSUT()
        let response = MinimalPairsModels.StartRound.Response(
            pair: makePair(),
            roundNumber: 1,
            total: 5,
            hintsAvailable: 2
        )
        sut.presentStartRound(response)
        XCTAssertTrue(spy.startRoundVM?.promptText.contains("шар") ?? false)
    }

    // MARK: - presentSelectOption

    func test_presentSelectOption_correct_positiveFeedback() {
        let (sut, spy) = makeSUT()
        let response = MinimalPairsModels.SelectOption.Response(
            correct: true,
            correctAnswer: "шар",
            foilAnswer: "сар",
            soundContrast: "С-Ш",
            streakCount: 1,
            isStreakBonus: false,
            hintsUsedThisRound: 0,
            roundDurationSeconds: 3.0
        )
        sut.presentSelectOption(response)
        XCTAssertTrue(spy.selectOptionVM?.correct ?? false)
        XCTAssertFalse(spy.selectOptionVM?.feedbackText.isEmpty ?? true)
    }

    func test_presentSelectOption_wrong_showsCorrectAnswer() {
        let (sut, spy) = makeSUT()
        let response = MinimalPairsModels.SelectOption.Response(
            correct: false,
            correctAnswer: "шар",
            foilAnswer: "сар",
            soundContrast: "С-Ш",
            streakCount: 0,
            isStreakBonus: false,
            hintsUsedThisRound: 1,
            roundDurationSeconds: 5.0
        )
        sut.presentSelectOption(response)
        XCTAssertFalse(spy.selectOptionVM?.correct ?? true)
        XCTAssertTrue(spy.selectOptionVM?.feedbackText.contains("шар") ?? false)
    }

    func test_presentSelectOption_streakBonus_specialMessage() {
        let (sut, spy) = makeSUT()
        let response = MinimalPairsModels.SelectOption.Response(
            correct: true,
            correctAnswer: "шар",
            foilAnswer: "сар",
            soundContrast: "С-Ш",
            streakCount: 5,
            isStreakBonus: true,
            hintsUsedThisRound: 0,
            roundDurationSeconds: 2.0
        )
        sut.presentSelectOption(response)
        XCTAssertTrue(spy.selectOptionVM?.isStreakBonus ?? false)
        XCTAssertFalse(spy.selectOptionVM?.feedbackText.isEmpty ?? true)
    }

    func test_presentSelectOption_streak3OrMore_labelSet() {
        let (sut, spy) = makeSUT()
        let response = MinimalPairsModels.SelectOption.Response(
            correct: true,
            correctAnswer: "шар",
            foilAnswer: "сар",
            soundContrast: "С-Ш",
            streakCount: 4,
            isStreakBonus: false,
            hintsUsedThisRound: 0,
            roundDurationSeconds: 2.0
        )
        sut.presentSelectOption(response)
        XCTAssertNotNil(spy.selectOptionVM?.streakLabel)
    }

    func test_presentSelectOption_streakBelow3_labelNil() {
        let (sut, spy) = makeSUT()
        let response = MinimalPairsModels.SelectOption.Response(
            correct: true,
            correctAnswer: "шар",
            foilAnswer: "сар",
            soundContrast: "С-Ш",
            streakCount: 2,
            isStreakBonus: false,
            hintsUsedThisRound: 0,
            roundDurationSeconds: 2.0
        )
        sut.presentSelectOption(response)
        XCTAssertNil(spy.selectOptionVM?.streakLabel)
    }

    // MARK: - presentReplayWord

    func test_presentReplayWord_capReached_toastSet() {
        let (sut, spy) = makeSUT()
        let response = MinimalPairsModels.ReplayWord.Response(
            word: "шар",
            replaysRemaining: 0,
            capReached: true
        )
        sut.presentReplayWord(response)
        XCTAssertNotNil(spy.replayWordVM?.toastMessage)
        XCTAssertTrue(spy.replayWordVM?.capReached ?? false)
    }

    func test_presentReplayWord_capNotReached_toastNil() {
        let (sut, spy) = makeSUT()
        let response = MinimalPairsModels.ReplayWord.Response(
            word: "шар",
            replaysRemaining: 2,
            capReached: false
        )
        sut.presentReplayWord(response)
        XCTAssertNil(spy.replayWordVM?.toastMessage)
    }

    // MARK: - presentHint

    func test_presentHint_capReached_toastSet() {
        let (sut, spy) = makeSUT()
        let response = MinimalPairsModels.RequestHint.Response(
            level: .highlight,
            highlightDuration: 1.0,
            voiceText: nil,
            hintsRemaining: 0,
            capReached: true
        )
        sut.presentHint(response)
        XCTAssertFalse(spy.hintVM?.toastMessage.isEmpty ?? true)
        XCTAssertTrue(spy.hintVM?.capReached ?? false)
    }

    func test_presentHint_highlight_toastSet() {
        let (sut, spy) = makeSUT()
        let response = MinimalPairsModels.RequestHint.Response(
            level: .highlight,
            highlightDuration: 2.0,
            voiceText: nil,
            hintsRemaining: 1,
            capReached: false
        )
        sut.presentHint(response)
        XCTAssertFalse(spy.hintVM?.toastMessage.isEmpty ?? true)
    }

    func test_presentHint_voiceClarification_toastSet() {
        let (sut, spy) = makeSUT()
        let response = MinimalPairsModels.RequestHint.Response(
            level: .voiceClarification,
            highlightDuration: 0,
            voiceText: "Слушай звук Ш",
            hintsRemaining: 2,
            capReached: false
        )
        sut.presentHint(response)
        XCTAssertFalse(spy.hintVM?.toastMessage.isEmpty ?? true)
    }

    // MARK: - presentBonusRoundAdded

    func test_presentBonusRoundAdded_passesThrough() {
        let (sut, spy) = makeSUT()
        let response = MinimalPairsModels.BonusRoundAdded.Response(
            message: "Бонусный раунд добавлен!",
            totalRounds: 7
        )
        sut.presentBonusRoundAdded(response)
        XCTAssertEqual(spy.bonusRoundVM?.toastMessage, "Бонусный раунд добавлен!")
        XCTAssertEqual(spy.bonusRoundVM?.totalRounds, 7)
    }

    // MARK: - presentCompleteSession

    func test_presentCompleteSession_perfectScore_3stars() {
        let (sut, spy) = makeSUT()
        let response = MinimalPairsModels.CompleteSession.Response(
            correctCount: 5,
            totalRounds: 5,
            pairAccuracy: [:],
            maxStreak: 5,
            totalHintsUsed: 0,
            totalDurationSeconds: 60,
            sm2Quality: .correct
        )
        sut.presentCompleteSession(response)
        XCTAssertEqual(spy.completeSessionVM?.starsEarned, 3)
        XCTAssertEqual(spy.completeSessionVM?.scoreLabel, "5 / 5")
    }

    func test_presentCompleteSession_lowScore_0stars() {
        let (sut, spy) = makeSUT()
        let response = MinimalPairsModels.CompleteSession.Response(
            correctCount: 1,
            totalRounds: 5,
            pairAccuracy: [:],
            maxStreak: 1,
            totalHintsUsed: 3,
            totalDurationSeconds: 120,
            sm2Quality: .blackout
        )
        sut.presentCompleteSession(response)
        XCTAssertEqual(spy.completeSessionVM?.starsEarned, 0)
    }
}
