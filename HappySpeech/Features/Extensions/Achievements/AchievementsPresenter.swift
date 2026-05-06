import Foundation
import OSLog

// MARK: - AchievementsPresentationLogic

@MainActor
protocol AchievementsPresentationLogic: AnyObject {
    func presentAchievements(_ response: AchievementsModels.Load.Response)
    func presentUnlockedToast(_ response: AchievementsModels.ToastUnlocked.Response)
    func presentNextAchievementProgress(_ response: AchievementsModels.NextAchievementProgress.Response)
    func presentMotivationalMessage(_ response: AchievementsModels.MotivationalMessage.Response)
    func presentShareAchievement(_ response: AchievementsModels.Share.Response)
}

// MARK: - AchievementsPresenter

@MainActor
final class AchievementsPresenter: AchievementsPresentationLogic {

    weak var view: (any AchievementsDisplayLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Achievements")
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        f.locale = Locale(identifier: "ru_RU")
        return f
    }()

    // MARK: - Present Achievements

    func presentAchievements(_ response: AchievementsModels.Load.Response) {
        let sections = buildSections(from: response.achievements)
        let leaderboardDays = buildLeaderboardDays(from: response.sessions)
        let siblingLeaderboard = buildSiblingLeaderboard(from: response.siblingProfiles)

        let progressText = String(
            format: String(localized: "achievements.progress.format"),
            response.totalUnlocked,
            response.totalCount
        )

        let viewModel = AchievementsModels.Load.ViewModel(
            progressText: progressText,
            sections: sections,
            leaderboardDays: leaderboardDays,
            siblingLeaderboard: siblingLeaderboard,
            showFamilyLeaderboard: response.siblingProfiles.count >= 2
        )
        view?.displayAchievements(viewModel)
    }

    // MARK: - Present Toast

    func presentUnlockedToast(_ response: AchievementsModels.ToastUnlocked.Response) {
        let message = String(
            format: String(localized: "achievements.toast.format"),
            response.achievement.localizedTitle
        )
        let viewModel = AchievementsModels.ToastUnlocked.ViewModel(
            message: message,
            iconName: response.achievement.iconName
        )
        view?.displayUnlockedToast(viewModel)
        logger.info("Toast: \(response.achievement.rawValue, privacy: .public)")
    }

    // MARK: - Present NextAchievementProgress

    func presentNextAchievementProgress(_ response: AchievementsModels.NextAchievementProgress.Response) {
        let p = response.progress
        let title = String(localized: "achievement.title.\(p.achievementKey)")
        let label = String(
            format: String(localized: "achievements.progress.next.format"),
            p.currentValue,
            p.requiredValue
        )
        let vm = AchievementsModels.NextAchievementProgress.ViewModel(
            achievementTitle: title,
            progressFraction: p.fraction,
            progressLabel: label
        )
        view?.displayNextAchievementProgress(vm)
    }

    // MARK: - Present MotivationalMessage

    func presentMotivationalMessage(_ response: AchievementsModels.MotivationalMessage.Response) {
        view?.displayMotivationalMessage(response.message)
        logger.debug("motivationalMessage displayed для \(response.achievementKey, privacy: .public)")
    }

    // MARK: - Present ShareAchievement

    func presentShareAchievement(_ response: AchievementsModels.Share.Response) {
        view?.displayShareSheet(shareText: response.shareText, achievement: response.achievement)
        logger.info("shareAchievement: \(response.achievement.rawValue, privacy: .public)")
    }

    // MARK: - Private helpers

    private func buildSections(from dtos: [AchievementDTO]) -> [AchievementSection] {
        AchievementRarity.allCases.compactMap { rarity in
            let items = dtos
                .filter { $0.achievement.rarity == rarity }
                .sorted { lhs, rhs in
                    if lhs.isUnlocked != rhs.isUnlocked { return lhs.isUnlocked }
                    return lhs.id < rhs.id
                }
                .map { dto -> AchievementCellViewModel in
                    let formatted: String?
                    if let date = dto.unlockedAt {
                        formatted = String(
                            format: String(localized: "achievements.unlocked.format"),
                            Self.dateFormatter.string(from: date)
                        )
                    } else {
                        formatted = nil
                    }
                    return AchievementCellViewModel(
                        id: dto.id,
                        title: dto.isUnlocked
                            ? dto.achievement.localizedTitle
                            : String(localized: "achievements.locked.title"),
                        description: dto.isUnlocked
                            ? dto.achievement.localizedDescription
                            : "",
                        iconName: dto.achievement.iconName,
                        rarity: dto.achievement.rarity,
                        isUnlocked: dto.isUnlocked,
                        unlockedAt: dto.unlockedAt,
                        unlockedDateFormatted: formatted
                    )
                }
            guard !items.isEmpty else { return nil }
            return AchievementSection(rarity: rarity, items: items)
        }
    }

    private func buildLeaderboardDays(from sessions: [SessionDayEntry]) -> [LeaderboardDayEntry] {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale(identifier: "ru_RU")
        return sessions.map { entry in
            LeaderboardDayEntry(
                id: entry.id,
                date: entry.date,
                label: formatter.string(from: entry.date),
                roundsCompleted: entry.roundsCompleted,
                successRate: entry.successRate
            )
        }
    }

    private func buildSiblingLeaderboard(
        from siblings: [SiblingProgressDTO]
    ) -> [SiblingLeaderboardEntry] {
        let sorted = siblings.sorted { $0.totalUnlocked > $1.totalUnlocked }
        return sorted.enumerated().map { index, sibling in
            SiblingLeaderboardEntry(
                id: sibling.id,
                childName: sibling.name,
                totalAchievements: sibling.totalUnlocked,
                rank: index + 1
            )
        }
    }
}
