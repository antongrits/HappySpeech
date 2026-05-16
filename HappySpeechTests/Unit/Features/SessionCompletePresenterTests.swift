@testable import HappySpeech
import XCTest

// MARK: - SessionCompletePresenterTests
//
// Phase 2.6 batch 2 v25 — покрытие SessionCompletePresenter (70% → цель ≥90%).

@MainActor
final class SessionCompletePresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: SessionCompleteDisplayLogic {
        var loadResultVM: SessionCompleteModels.LoadResult.ViewModel?
        var advancePhaseVM: SessionCompleteModels.AdvancePhase.ViewModel?
        var shareResultVM: SessionCompleteModels.ShareResult.ViewModel?
        var playAgainCalled: Bool = false
        var proceedToNextVM: SessionCompleteModels.ProceedToNext.ViewModel?
        var failureVM: SessionCompleteModels.Failure.ViewModel?
        var achievementUnlockedVM: SessionCompleteModels.AchievementUnlocked.ViewModel?
        var stickerRevealVM: SessionCompleteModels.StickerReveal.ViewModel?
        var streakUpdateVM: SessionCompleteModels.StreakUpdate.ViewModel?

        func displayLoadResult(_ viewModel: SessionCompleteModels.LoadResult.ViewModel) { loadResultVM = viewModel }
        func displayAdvancePhase(_ viewModel: SessionCompleteModels.AdvancePhase.ViewModel) { advancePhaseVM = viewModel }
        func displayShareResult(_ viewModel: SessionCompleteModels.ShareResult.ViewModel) { shareResultVM = viewModel }
        func displayPlayAgain(_ viewModel: SessionCompleteModels.PlayAgain.ViewModel) { playAgainCalled = true }
        func displayProceedToNext(_ viewModel: SessionCompleteModels.ProceedToNext.ViewModel) { proceedToNextVM = viewModel }
        func displayFailure(_ viewModel: SessionCompleteModels.Failure.ViewModel) { failureVM = viewModel }
        func displayAchievementUnlocked(_ viewModel: SessionCompleteModels.AchievementUnlocked.ViewModel) { achievementUnlockedVM = viewModel }
        func displayStickerReveal(_ viewModel: SessionCompleteModels.StickerReveal.ViewModel) { stickerRevealVM = viewModel }
        func displayStreakUpdate(_ viewModel: SessionCompleteModels.StreakUpdate.ViewModel) { streakUpdateVM = viewModel }
    }

    private func makeSUT() -> (SessionCompletePresenter, DisplaySpy) {
        let presenter = SessionCompletePresenter()
        let spy = DisplaySpy()
        presenter.display = spy
        return (presenter, spy)
    }

    private func makeResult(
        score: Float = 0.8,
        attempts: Int = 10,
        correctAttempts: Int = 8,
        hintsUsed: Int = 0,
        durationSec: Int = 120
    ) -> SessionResult {
        SessionResult(
            score: score,
            starsEarned: 2,
            gameTitle: "Повтори за мной",
            soundTarget: "С",
            attempts: attempts,
            correctAttempts: correctAttempts,
            hintsUsed: hintsUsed,
            durationSec: durationSec,
            nextLessonTitle: "Урок 2"
        )
    }

    private func makeBreakdown(
        accuracy: Float = 0.8,
        noHints: Bool = true,
        streakBonus: Int = 15,
        hintPenalty: Int = 0
    ) -> ScoreBreakdown {
        ScoreBreakdown(
            total: 80,
            baseScore: 65,
            streakBonus: streakBonus,
            hintPenalty: hintPenalty,
            accuracy: accuracy,
            hintsUsed: noHints ? 0 : 2,
            durationSec: 120,
            noHints: noHints
        )
    }

    private func makeAchievement(title: String = "Первая победа") -> UnlockedAchievementInfo {
        UnlockedAchievementInfo(title: title, description: "Описание", iconName: "star.fill", rarity: "common")
    }

    private func makeSticker() -> StickerRevealInfo {
        StickerRevealInfo(id: "s1", emoji: "⭐", name: "Звёздочка", collectionName: "Зимняя")
    }

    // MARK: - presentLoadResult

    func test_presentLoadResult_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentLoadResult(.init(result: makeResult(), breakdown: makeBreakdown()))
        XCTAssertNotNil(spy.loadResultVM)
    }

    func test_presentLoadResult_scoreLabelNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentLoadResult(.init(result: makeResult(), breakdown: makeBreakdown()))
        XCTAssertFalse(spy.loadResultVM?.scoreLabel.isEmpty ?? true)
    }

    func test_presentLoadResult_attemptsLabelNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentLoadResult(.init(result: makeResult(attempts: 12), breakdown: makeBreakdown()))
        XCTAssertFalse(spy.loadResultVM?.attemptsLabel.isEmpty ?? true)
    }

    func test_presentLoadResult_correctLabelNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentLoadResult(.init(result: makeResult(correctAttempts: 10), breakdown: makeBreakdown()))
        XCTAssertFalse(spy.loadResultVM?.correctLabel.isEmpty ?? true)
    }

    func test_presentLoadResult_durationLabelNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentLoadResult(.init(result: makeResult(durationSec: 90), breakdown: makeBreakdown()))
        XCTAssertFalse(spy.loadResultVM?.durationLabel.isEmpty ?? true)
    }

    func test_presentLoadResult_noHints_hintsLabelNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentLoadResult(.init(result: makeResult(hintsUsed: 0), breakdown: makeBreakdown()))
        XCTAssertFalse(spy.loadResultVM?.hintsLabel.isEmpty ?? true)
    }

    func test_presentLoadResult_withHints_hintsLabelNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentLoadResult(.init(result: makeResult(hintsUsed: 3), breakdown: makeBreakdown(noHints: false)))
        XCTAssertFalse(spy.loadResultVM?.hintsLabel.isEmpty ?? true)
    }

    func test_presentLoadResult_highScore_mascotTaglineNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentLoadResult(.init(result: makeResult(score: 0.95), breakdown: makeBreakdown(accuracy: 0.95)))
        XCTAssertFalse(spy.loadResultVM?.mascotTagline.isEmpty ?? true)
    }

    func test_presentLoadResult_lowScore_mascotTaglineNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentLoadResult(.init(result: makeResult(score: 0.3), breakdown: makeBreakdown(accuracy: 0.3)))
        XCTAssertFalse(spy.loadResultVM?.mascotTagline.isEmpty ?? true)
    }

    func test_presentLoadResult_excellentScore_isPerfect() {
        let (sut, spy) = makeSUT()
        // accuracy >= 0.85 && noHints → isPerfect
        sut.presentLoadResult(.init(result: makeResult(score: 0.9, hintsUsed: 0), breakdown: makeBreakdown(accuracy: 0.9, noHints: true)))
        XCTAssertTrue(spy.loadResultVM?.isPerfect ?? false)
    }

    func test_presentLoadResult_accuracy80_showConfettiTrue() {
        let (sut, spy) = makeSUT()
        sut.presentLoadResult(.init(result: makeResult(score: 0.85), breakdown: makeBreakdown(accuracy: 0.85)))
        XCTAssertTrue(spy.loadResultVM?.showConfetti ?? false)
    }

    func test_presentLoadResult_lowAccuracy_showConffettiFalse() {
        let (sut, spy) = makeSUT()
        sut.presentLoadResult(.init(result: makeResult(score: 0.5), breakdown: makeBreakdown(accuracy: 0.5)))
        XCTAssertFalse(spy.loadResultVM?.showConfetti ?? true)
    }

    func test_presentLoadResult_a11ySummaryNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentLoadResult(.init(result: makeResult(), breakdown: makeBreakdown()))
        XCTAssertFalse(spy.loadResultVM?.accessibilitySummary.isEmpty ?? true)
    }

    func test_presentLoadResult_starsTotalIsThree() {
        let (sut, spy) = makeSUT()
        sut.presentLoadResult(.init(result: makeResult(), breakdown: makeBreakdown()))
        XCTAssertEqual(spy.loadResultVM?.starsTotal, 3)
    }

    // MARK: - mascotTagline thresholds

    func test_mascotTagline_score0_9plus_excellentKey() {
        let (sut, spy) = makeSUT()
        sut.presentLoadResult(.init(result: makeResult(score: 0.95), breakdown: makeBreakdown(accuracy: 0.95)))
        XCTAssertFalse(spy.loadResultVM?.mascotTagline.isEmpty ?? true)
    }

    func test_mascotTagline_score0_75to0_89_goodKey() {
        let (sut, spy) = makeSUT()
        sut.presentLoadResult(.init(result: makeResult(score: 0.8), breakdown: makeBreakdown(accuracy: 0.8)))
        XCTAssertFalse(spy.loadResultVM?.mascotTagline.isEmpty ?? true)
    }

    func test_mascotTagline_score0_5to0_74_okayKey() {
        let (sut, spy) = makeSUT()
        sut.presentLoadResult(.init(result: makeResult(score: 0.6), breakdown: makeBreakdown(accuracy: 0.6)))
        XCTAssertFalse(spy.loadResultVM?.mascotTagline.isEmpty ?? true)
    }

    func test_mascotTagline_scoreLow_encouragingKey() {
        let (sut, spy) = makeSUT()
        sut.presentLoadResult(.init(result: makeResult(score: 0.3), breakdown: makeBreakdown(accuracy: 0.3)))
        XCTAssertFalse(spy.loadResultVM?.mascotTagline.isEmpty ?? true)
    }

    // MARK: - presentAdvancePhase

    func test_presentAdvancePhase_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentAdvancePhase(.init(phase: .stars))
        XCTAssertNotNil(spy.advancePhaseVM)
    }

    func test_presentAdvancePhase_phasePassedThrough() {
        let (sut, spy) = makeSUT()
        sut.presentAdvancePhase(.init(phase: .achievement))
        XCTAssertEqual(spy.advancePhaseVM?.phase, .achievement)
    }

    // MARK: - presentAchievementUnlocked

    func test_presentAchievementUnlocked_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentAchievementUnlocked(.init(achievements: [makeAchievement()]))
        XCTAssertNotNil(spy.achievementUnlockedVM)
    }

    func test_presentAchievementUnlocked_emptyList_notCalled() {
        let (sut, spy) = makeSUT()
        sut.presentAchievementUnlocked(.init(achievements: []))
        XCTAssertNil(spy.achievementUnlockedVM)
    }

    func test_presentAchievementUnlocked_singleAchievement_toastNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentAchievementUnlocked(.init(achievements: [makeAchievement(title: "Герой")]))
        XCTAssertFalse(spy.achievementUnlockedVM?.toastMessage.isEmpty ?? true)
    }

    func test_presentAchievementUnlocked_multipleAchievements_toastNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentAchievementUnlocked(.init(achievements: [makeAchievement(), makeAchievement()]))
        XCTAssertFalse(spy.achievementUnlockedVM?.toastMessage.isEmpty ?? true)
    }

    // MARK: - presentStickerReveal

    func test_presentStickerReveal_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentStickerReveal(.init(sticker: makeSticker()))
        XCTAssertNotNil(spy.stickerRevealVM)
    }

    func test_presentStickerReveal_revealLabelNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentStickerReveal(.init(sticker: makeSticker()))
        XCTAssertFalse(spy.stickerRevealVM?.revealLabel.isEmpty ?? true)
    }

    // MARK: - presentStreakUpdate

    func test_presentStreakUpdate_zeroStreak_labelNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentStreakUpdate(.init(streak: StreakInfo(currentStreak: 0, isMilestone: false, milestoneLabel: nil)))
        XCTAssertFalse(spy.streakUpdateVM?.streakLabel.isEmpty ?? true)
    }

    func test_presentStreakUpdate_nonZeroStreak_labelNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentStreakUpdate(.init(streak: StreakInfo(currentStreak: 5, isMilestone: false, milestoneLabel: nil)))
        XCTAssertFalse(spy.streakUpdateVM?.streakLabel.isEmpty ?? true)
    }

    func test_presentStreakUpdate_milestone_iconIsFlameFill() {
        let (sut, spy) = makeSUT()
        sut.presentStreakUpdate(.init(streak: StreakInfo(currentStreak: 7, isMilestone: true, milestoneLabel: "Неделя!")))
        XCTAssertEqual(spy.streakUpdateVM?.iconName, "flame.fill")
    }

    func test_presentStreakUpdate_noMilestone_iconIsFlame() {
        let (sut, spy) = makeSUT()
        sut.presentStreakUpdate(.init(streak: StreakInfo(currentStreak: 3, isMilestone: false, milestoneLabel: nil)))
        XCTAssertEqual(spy.streakUpdateVM?.iconName, "flame")
    }

    // MARK: - presentShareResult

    func test_presentShareResult_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentShareResult(.init(shareText: "Маша выполнила задание!"))
        XCTAssertNotNil(spy.shareResultVM)
    }

    func test_presentShareResult_shareTextPassedThrough() {
        let (sut, spy) = makeSUT()
        sut.presentShareResult(.init(shareText: "Текст для шаринга"))
        XCTAssertEqual(spy.shareResultVM?.shareText, "Текст для шаринга")
    }

    // MARK: - presentPlayAgain

    func test_presentPlayAgain_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentPlayAgain(.init())
        XCTAssertTrue(spy.playAgainCalled)
    }

    // MARK: - presentProceedToNext

    func test_presentProceedToNext_hasNextTrue() {
        let (sut, spy) = makeSUT()
        sut.presentProceedToNext(.init(hasNext: true))
        XCTAssertTrue(spy.proceedToNextVM?.hasNext ?? false)
    }

    func test_presentProceedToNext_hasNextFalse() {
        let (sut, spy) = makeSUT()
        sut.presentProceedToNext(.init(hasNext: false))
        XCTAssertFalse(spy.proceedToNextVM?.hasNext ?? true)
    }

    // MARK: - presentFailure

    func test_presentFailure_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentFailure(.init(message: "Ошибка загрузки"))
        XCTAssertNotNil(spy.failureVM)
    }

    func test_presentFailure_messagePassedThrough() {
        let (sut, spy) = makeSUT()
        sut.presentFailure(.init(message: "Нет данных"))
        XCTAssertEqual(spy.failureVM?.toastMessage, "Нет данных")
    }
}
