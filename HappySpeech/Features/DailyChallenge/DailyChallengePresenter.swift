import Foundation
import OSLog

// MARK: - DailyChallengePresentationLogic

@MainActor
protocol DailyChallengePresentationLogic: AnyObject {
    func presentLoad(response: DailyChallengeModels.Load.Response) async
    func presentStartSession(response: DailyChallengeModels.StartSession.Response) async
    func presentShareCompletion(response: DailyChallengeModels.ShareCompletion.Response) async
}

// MARK: - DailyChallengePresenter (Clean Swift: Presenter)
//
// Block AE batch 2 v21 — мапит Response → ViewModel.
// Все строки через `String(localized:)` — ключи появятся в xcstrings.

@MainActor
final class DailyChallengePresenter: DailyChallengePresentationLogic {

    weak var displayLogic: (any DailyChallengeDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "DailyChallenge.Presenter"
    )

    init(displayLogic: (any DailyChallengeDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Load

    func presentLoad(response: DailyChallengeModels.Load.Response) async {
        let goal = response.goal
        let kind = goal.kind

        let goalTitle = String(localized: String.LocalizationValue(kind.titleKey))
        let goalSubtitleKey = "dailyChallenge.goal.\(kind.rawValue).subtitle"
        let goalSubtitle = String(
            format: String(localized: String.LocalizationValue(goalSubtitleKey)),
            goal.target,
            goal.targetSound
        )

        let progressValue: Double = {
            guard goal.target > 0 else { return 0 }
            return min(1.0, Double(goal.current) / Double(goal.target))
        }()

        let progressLabel = String(
            format: String(localized: "dailyChallenge.progress.format"),
            goal.current,
            goal.target
        )

        let streakTitle = String(
            format: String(localized: "dailyChallenge.streak.title"),
            response.streak.current
        )
        let streakA11y = String(
            format: String(localized: "dailyChallenge.streak.a11y"),
            response.streak.current
        )
        let longestLabel = String(
            format: String(localized: "dailyChallenge.streak.longest"),
            response.streak.longest
        )

        let rewardTitle = String(
            localized: String.LocalizationValue(response.reward.titleKey)
        )
        let rewardSubtitle = String(
            format: String(localized: "dailyChallenge.reward.xp"),
            response.reward.xpAward
        )

        let ctaTitle: String
        if goal.isCompleted {
            ctaTitle = String(localized: "dailyChallenge.cta.share")
        } else {
            ctaTitle = String(localized: "dailyChallenge.cta.start")
        }

        let heroSubtitle = String(
            format: String(localized: "dailyChallenge.hero.subtitle"),
            response.childDisplayName
        )

        let viewModel = DailyChallengeModels.Load.ViewModel(
            goalTitle: goalTitle,
            goalSubtitle: goalSubtitle,
            goalSymbol: kind.symbolName,
            goalProgressValue: progressValue,
            goalProgressLabel: progressLabel,
            isCompleted: goal.isCompleted,
            streakTitle: streakTitle,
            streakAccessibilityLabel: streakA11y,
            longestStreakLabel: longestLabel,
            rewardTitle: rewardTitle,
            rewardSubtitle: rewardSubtitle,
            rewardSticker: response.reward.stickerName,
            ctaTitle: ctaTitle,
            heroSubtitle: heroSubtitle
        )

        await displayLogic?.displayLoad(viewModel: viewModel)
    }

    // MARK: - StartSession

    func presentStartSession(response: DailyChallengeModels.StartSession.Response) async {
        let viewModel = DailyChallengeModels.StartSession.ViewModel(
            childId: response.childId,
            targetSound: response.targetSound
        )
        await displayLogic?.displayStartSession(viewModel: viewModel)
    }

    // MARK: - ShareCompletion

    func presentShareCompletion(response: DailyChallengeModels.ShareCompletion.Response) async {
        let toast = String(localized: String.LocalizationValue(response.toastKey))
        let viewModel = DailyChallengeModels.ShareCompletion.ViewModel(
            snapshotText: response.snapshotText,
            toastMessage: toast
        )
        await displayLogic?.displayShareCompletion(viewModel: viewModel)
    }
}
