import Foundation
import OSLog

// MARK: - SessionCompletePresentationLogic

@MainActor
protocol SessionCompletePresentationLogic: AnyObject {
    func presentLoadResult(_ response: SessionCompleteModels.LoadResult.Response)
    func presentAdvancePhase(_ response: SessionCompleteModels.AdvancePhase.Response)
    func presentShareResult(_ response: SessionCompleteModels.ShareResult.Response)
    func presentPlayAgain(_ response: SessionCompleteModels.PlayAgain.Response)
    func presentProceedToNext(_ response: SessionCompleteModels.ProceedToNext.Response)
    func presentFailure(_ response: SessionCompleteModels.Failure.Response)
    func presentAchievementUnlocked(_ response: SessionCompleteModels.AchievementUnlocked.Response)
    func presentStickerReveal(_ response: SessionCompleteModels.StickerReveal.Response)
    func presentStreakUpdate(_ response: SessionCompleteModels.StreakUpdate.Response)
}

// MARK: - SessionCompletePresenter

/// Преобразует Response → ViewModel: локализация, форматирование, accessibility.
/// Никаких вычислений и I/O — только презентационная логика.
@MainActor
final class SessionCompletePresenter: SessionCompletePresentationLogic {

    // MARK: - Collaborators

    weak var display: (any SessionCompleteDisplayLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SessionCompletePresenter")

    // MARK: - Formatters

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    // MARK: - presentLoadResult

    func presentLoadResult(_ response: SessionCompleteModels.LoadResult.Response) {
        let result = response.result
        let breakdown = response.breakdown
        let scoreInt = breakdown.total

        let scoreLabel = "\(scoreInt)"
        let attemptsTemplate = String(localized: "sessionComplete.summary.attemptsCount")
        let attemptsLabel = String(format: attemptsTemplate, result.attempts)

        let correctTemplate = String(localized: "sessionComplete.summary.correctCount")
        let correctLabel = String(format: correctTemplate, result.correctAttempts)

        let durationLabel = formatDuration(seconds: result.durationSec)

        let soundLabel = String(
            format: String(localized: "sessionComplete.summary.soundTarget"),
            result.soundTarget
        )

        let hintsTemplate = String(localized: "sessionComplete.summary.hintsUsed")
        let hintsLabel = result.hintsUsed == 0
            ? String(localized: "sessionComplete.summary.noHints")
            : String(format: hintsTemplate, result.hintsUsed)

        let mascotTagline = makeMascotTagline(score: result.score)

        let summaryTemplate = String(localized: "sessionComplete.a11y.summary")
        let accessibilitySummary = String(
            format: summaryTemplate,
            scoreInt,
            breakdown.starsEarned,
            result.attempts
        )

        let isPerfect = breakdown.accuracy >= 0.85 && breakdown.noHints
        let showConfetti = breakdown.accuracy >= 0.80

        // Score breakdown labels
        let baseScoreLabel = String(
            format: String(localized: "sessionComplete.breakdown.base"),
            breakdown.baseScore
        )
        let streakBonusLabel = breakdown.streakBonus > 0
            ? String(format: String(localized: "sessionComplete.breakdown.bonus"), breakdown.streakBonus)
            : String(localized: "sessionComplete.breakdown.noBonus")
        let hintPenaltyLabel = breakdown.hintPenalty < 0
            ? String(format: String(localized: "sessionComplete.breakdown.penalty"), abs(breakdown.hintPenalty))
            : String(localized: "sessionComplete.breakdown.noPenalty")
        let totalScoreLabel = String(
            format: String(localized: "sessionComplete.breakdown.total"),
            scoreInt
        )

        let viewModel = SessionCompleteModels.LoadResult.ViewModel(
            scoreInt: scoreInt,
            scoreLabel: scoreLabel,
            starsEarned: breakdown.starsEarned,
            starsTotal: 3,
            gameTitle: result.gameTitle,
            soundLabel: soundLabel,
            attemptsLabel: attemptsLabel,
            correctLabel: correctLabel,
            durationLabel: durationLabel,
            hintsLabel: hintsLabel,
            nextLessonTitle: result.nextLessonTitle,
            mascotTagline: mascotTagline,
            accessibilitySummary: accessibilitySummary,
            isPerfect: isPerfect,
            showConfetti: showConfetti,
            baseScoreLabel: baseScoreLabel,
            streakBonusLabel: streakBonusLabel,
            hintPenaltyLabel: hintPenaltyLabel,
            totalScoreLabel: totalScoreLabel
        )
        display?.displayLoadResult(viewModel)
    }

    // MARK: - presentAdvancePhase

    func presentAdvancePhase(_ response: SessionCompleteModels.AdvancePhase.Response) {
        display?.displayAdvancePhase(.init(phase: response.phase))
    }

    // MARK: - presentAchievementUnlocked

    func presentAchievementUnlocked(_ response: SessionCompleteModels.AchievementUnlocked.Response) {
        guard !response.achievements.isEmpty else { return }
        let toastMessage: String
        if response.achievements.count == 1 {
            toastMessage = String(
                format: String(localized: "sessionComplete.achievement.unlocked.single"),
                response.achievements[0].title
            )
        } else {
            toastMessage = String(
                format: String(localized: "sessionComplete.achievement.unlocked.multiple"),
                response.achievements.count
            )
        }
        let viewModel = SessionCompleteModels.AchievementUnlocked.ViewModel(
            achievements: response.achievements,
            hasAchievements: true,
            toastMessage: toastMessage
        )
        display?.displayAchievementUnlocked(viewModel)
        logger.info("presentAchievementUnlocked count=\(response.achievements.count, privacy: .public)")
    }

    // MARK: - presentStickerReveal

    func presentStickerReveal(_ response: SessionCompleteModels.StickerReveal.Response) {
        let revealLabel = String(
            format: String(localized: "sessionComplete.sticker.reveal"),
            response.sticker.name
        )
        let viewModel = SessionCompleteModels.StickerReveal.ViewModel(
            sticker: response.sticker,
            revealLabel: revealLabel
        )
        display?.displayStickerReveal(viewModel)
        logger.debug("presentStickerReveal sticker=\(response.sticker.id, privacy: .public)")
    }

    // MARK: - presentStreakUpdate

    func presentStreakUpdate(_ response: SessionCompleteModels.StreakUpdate.Response) {
        let streak = response.streak
        let streakLabel: String
        if streak.currentStreak == 0 {
            streakLabel = String(localized: "sessionComplete.streak.first")
        } else {
            streakLabel = String(
                format: String(localized: "sessionComplete.streak.days"),
                streak.currentStreak
            )
        }
        let iconName = streak.isMilestone ? "flame.fill" : "flame"
        let viewModel = SessionCompleteModels.StreakUpdate.ViewModel(
            streak: streak,
            streakLabel: streakLabel,
            milestoneLabel: streak.milestoneLabel,
            iconName: iconName
        )
        display?.displayStreakUpdate(viewModel)
        logger.debug("presentStreakUpdate streak=\(streak.currentStreak, privacy: .public) milestone=\(streak.isMilestone, privacy: .public)")
    }

    // MARK: - presentShareResult

    func presentShareResult(_ response: SessionCompleteModels.ShareResult.Response) {
        display?.displayShareResult(.init(shareText: response.shareText))
    }

    // MARK: - presentPlayAgain

    func presentPlayAgain(_ response: SessionCompleteModels.PlayAgain.Response) {
        display?.displayPlayAgain(.init())
    }

    // MARK: - presentProceedToNext

    func presentProceedToNext(_ response: SessionCompleteModels.ProceedToNext.Response) {
        display?.displayProceedToNext(.init(hasNext: response.hasNext))
    }

    // MARK: - presentFailure

    func presentFailure(_ response: SessionCompleteModels.Failure.Response) {
        logger.error("failure: \(response.message, privacy: .public)")
        display?.displayFailure(.init(toastMessage: response.message))
    }

    // MARK: - Private helpers

    private func formatDuration(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        if minutes > 0 {
            return String(
                format: String(localized: "sessionComplete.summary.durationMinSec"),
                minutes,
                remainder
            )
        }
        return String(
            format: String(localized: "sessionComplete.summary.durationSec"),
            remainder
        )
    }

    private func makeMascotTagline(score: Float) -> String {
        switch score {
        case 0.9...:
            return String(localized: "sessionComplete.mascot.excellent")
        case 0.75..<0.9:
            return String(localized: "sessionComplete.mascot.good")
        case 0.5..<0.75:
            return String(localized: "sessionComplete.mascot.okay")
        default:
            return String(localized: "sessionComplete.mascot.encouraging")
        }
    }
}
