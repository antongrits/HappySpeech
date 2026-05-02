import Foundation
import Observation

// MARK: - SessionCompleteDisplayLogic

/// Контракт между Presenter'ом и SwiftUI-store'ом.
/// `display(_:)`-методы — единственный путь обновления UI-состояния.
@MainActor
protocol SessionCompleteDisplayLogic: AnyObject {
    func displayLoadResult(_ viewModel: SessionCompleteModels.LoadResult.ViewModel)
    func displayAdvancePhase(_ viewModel: SessionCompleteModels.AdvancePhase.ViewModel)
    func displayShareResult(_ viewModel: SessionCompleteModels.ShareResult.ViewModel)
    func displayPlayAgain(_ viewModel: SessionCompleteModels.PlayAgain.ViewModel)
    func displayProceedToNext(_ viewModel: SessionCompleteModels.ProceedToNext.ViewModel)
    func displayFailure(_ viewModel: SessionCompleteModels.Failure.ViewModel)
    func displayAchievementUnlocked(_ viewModel: SessionCompleteModels.AchievementUnlocked.ViewModel)
    func displayStickerReveal(_ viewModel: SessionCompleteModels.StickerReveal.ViewModel)
    func displayStreakUpdate(_ viewModel: SessionCompleteModels.StreakUpdate.ViewModel)
}

// MARK: - SessionCompleteDisplay (Observable Store)

/// Источник истины для SwiftUI-вью SessionCompleteView.
/// Никакой бизнес-логики — только состояние и помощники для view.
@Observable
@MainActor
final class SessionCompleteDisplay: SessionCompleteDisplayLogic {

    // MARK: - Phase progression

    var currentPhase: RewardStage = .celebration

    // MARK: - Score block

    var scoreInt: Int = 0
    var scoreLabel: String = ""
    var starsEarned: Int = 0
    var starsTotal: Int = 3
    var isPerfect: Bool = false
    var showConfetti: Bool = false

    // MARK: - Score breakdown

    var baseScoreLabel: String = ""
    var streakBonusLabel: String = ""
    var hintPenaltyLabel: String = ""
    var totalScoreLabel: String = ""

    // MARK: - Header

    var gameTitle: String = ""
    var soundLabel: String = ""

    // MARK: - Summary cards

    var attemptsLabel: String = ""
    var correctLabel: String = ""
    var durationLabel: String = ""
    var hintsLabel: String = ""

    // MARK: - Next lesson preview

    var nextLessonTitle: String?

    // MARK: - Mascot bubble

    var mascotTagline: String = ""

    // MARK: - Achievement reveal (Stage 4)

    var pendingAchievements: [UnlockedAchievementInfo] = []
    var hasNewAchievements: Bool = false
    var achievementToastMessage: String = ""

    // MARK: - Sticker reveal (Stage 5)

    var pendingSticker: StickerRevealInfo?
    var stickerRevealLabel: String = ""

    // MARK: - Streak update (Stage 6)

    var streakInfo: StreakInfo?
    var streakLabel: String = ""
    var streakMilestoneLabel: String?
    var streakIconName: String = "flame"

    // MARK: - Share

    var pendingShareText: String?

    // MARK: - Routing intent

    var pendingPlayAgain: Bool = false
    var pendingProceed: Bool = false
    var pendingHasNext: Bool = false

    // MARK: - Toast

    var toastMessage: String?

    // MARK: - A11y

    var accessibilitySummary: String = ""

    // MARK: - SessionCompleteDisplayLogic

    func displayLoadResult(_ viewModel: SessionCompleteModels.LoadResult.ViewModel) {
        scoreInt = viewModel.scoreInt
        scoreLabel = viewModel.scoreLabel
        starsEarned = viewModel.starsEarned
        starsTotal = viewModel.starsTotal
        gameTitle = viewModel.gameTitle
        soundLabel = viewModel.soundLabel
        attemptsLabel = viewModel.attemptsLabel
        correctLabel = viewModel.correctLabel
        durationLabel = viewModel.durationLabel
        hintsLabel = viewModel.hintsLabel
        nextLessonTitle = viewModel.nextLessonTitle
        mascotTagline = viewModel.mascotTagline
        accessibilitySummary = viewModel.accessibilitySummary
        isPerfect = viewModel.isPerfect
        showConfetti = viewModel.showConfetti
        baseScoreLabel = viewModel.baseScoreLabel
        streakBonusLabel = viewModel.streakBonusLabel
        hintPenaltyLabel = viewModel.hintPenaltyLabel
        totalScoreLabel = viewModel.totalScoreLabel
        currentPhase = .celebration
    }

    func displayAdvancePhase(_ viewModel: SessionCompleteModels.AdvancePhase.ViewModel) {
        currentPhase = viewModel.phase
    }

    func displayAchievementUnlocked(_ viewModel: SessionCompleteModels.AchievementUnlocked.ViewModel) {
        pendingAchievements = viewModel.achievements
        hasNewAchievements = viewModel.hasAchievements
        achievementToastMessage = viewModel.toastMessage
    }

    func displayStickerReveal(_ viewModel: SessionCompleteModels.StickerReveal.ViewModel) {
        pendingSticker = viewModel.sticker
        stickerRevealLabel = viewModel.revealLabel
    }

    func displayStreakUpdate(_ viewModel: SessionCompleteModels.StreakUpdate.ViewModel) {
        streakInfo = viewModel.streak
        streakLabel = viewModel.streakLabel
        streakMilestoneLabel = viewModel.milestoneLabel
        streakIconName = viewModel.iconName
    }

    func displayShareResult(_ viewModel: SessionCompleteModels.ShareResult.ViewModel) {
        pendingShareText = viewModel.shareText
    }

    func displayPlayAgain(_ viewModel: SessionCompleteModels.PlayAgain.ViewModel) {
        pendingPlayAgain = true
    }

    func displayProceedToNext(_ viewModel: SessionCompleteModels.ProceedToNext.ViewModel) {
        pendingProceed = true
        pendingHasNext = viewModel.hasNext
    }

    func displayFailure(_ viewModel: SessionCompleteModels.Failure.ViewModel) {
        toastMessage = viewModel.toastMessage
    }

    // MARK: - View helpers

    func clearToast() { toastMessage = nil }
    func consumeShare() { pendingShareText = nil }
    func consumePlayAgain() { pendingPlayAgain = false }
    func consumeProceed() {
        pendingProceed = false
        pendingHasNext = false
    }

    /// Проверяет, должна ли быть видна указанная стадия.
    func isPhaseVisible(_ phase: RewardStage) -> Bool {
        currentPhase >= phase
    }
}
