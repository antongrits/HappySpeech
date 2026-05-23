import Foundation

// MARK: - FamilyChallengePresentationLogic

@MainActor
protocol FamilyChallengePresentationLogic: AnyObject {
    func presentChallenge(response: FamilyChallengeModels.LoadChallenge.Response) async
    func presentClaimedReward(response: FamilyChallengeModels.ClaimReward.Response) async
    func presentShareProgress(response: FamilyChallengeModels.ShareProgress.Response) async
}

// MARK: - FamilyChallengePresenter

@MainActor
final class FamilyChallengePresenter: FamilyChallengePresentationLogic {

    weak var displayLogic: (any FamilyChallengeDisplayLogic)?

    init(displayLogic: any FamilyChallengeDisplayLogic) {
        self.displayLogic = displayLogic
    }

    // MARK: - Load

    func presentChallenge(response: FamilyChallengeModels.LoadChallenge.Response) async {
        let challenge = response.challenge
        let maxContribution = max(1, challenge.contributions.map(\.value).max() ?? 1)
        let rows = challenge.contributions.map { contrib in
            ContributionRowViewModel(
                id: contrib.id,
                label: "\(contrib.memberName) \(contrib.memberEmoji)",
                valueLabel: "\(contrib.value) \(challenge.type.unitLabel)",
                progressFraction: Double(contrib.value) / Double(maxContribution),
                isChild: contrib.isChild,
                accessibilityLabel: makeContributionA11y(contrib: contrib, type: challenge.type)
            )
        }
        let progressLabel = "\(challenge.current) / \(challenge.goal) \(challenge.type.unitLabel)"
        let goalLabel = "Цель: \(challenge.goal) \(challenge.type.unitLabel) \(challenge.type.emoji)"
        let streakLabel = makeStreakLabel(weeks: challenge.streakWeeks)
        let summary = "Челлендж недели: \(challenge.type.localizedTitle). \(progressLabel). \(streakLabel)"

        let viewModel = FamilyChallengeModels.LoadChallenge.ViewModel(
            title: "Челлендж недели",
            subtitle: challenge.type.localizedTitle,
            iconSystemName: challenge.type.iconSystemName,
            emojiTag: challenge.type.emoji,
            progressFraction: challenge.progressFraction,
            progressLabel: progressLabel,
            goalLabel: goalLabel,
            contributions: rows,
            streakLabel: streakLabel,
            canManage: !response.isKidContext,
            accessibilitySummary: summary
        )
        await displayLogic?.displayChallenge(viewModel: viewModel)
    }

    // MARK: - Claim

    func presentClaimedReward(response: FamilyChallengeModels.ClaimReward.Response) async {
        let viewModel = FamilyChallengeModels.ClaimReward.ViewModel(
            toastMessage: "Награда получена!",
            confettiShown: response.confettiShown
        )
        await displayLogic?.displayClaimedReward(viewModel: viewModel)
    }

    // MARK: - Share

    func presentShareProgress(response: FamilyChallengeModels.ShareProgress.Response) async {
        let viewModel = FamilyChallengeModels.ShareProgress.ViewModel(
            shareText: response.shareText
        )
        await displayLogic?.displayShareProgress(viewModel: viewModel)
    }

    // MARK: - Helpers

    private func makeStreakLabel(weeks: Int) -> String {
        guard weeks > 0 else { return "Начало нового челленджа" }
        let suffix = streakSuffix(weeks: weeks)
        return "🔥 \(weeks)-\(suffix) подряд"
    }

    /// «1-я неделя», «2-я неделя», «5-я неделя» — морфология короткая.
    private func streakSuffix(weeks: Int) -> String {
        // Простейший правильный суффикс через `я неделя`.
        "я неделя"
    }

    private func makeContributionA11y(contrib: Contribution, type: ChallengeType) -> String {
        "\(contrib.memberName): \(contrib.value) \(type.unitLabel)"
    }
}
