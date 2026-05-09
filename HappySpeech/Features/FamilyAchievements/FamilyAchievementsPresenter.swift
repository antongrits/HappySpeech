import Foundation
import OSLog

// MARK: - FamilyAchievementsPresentationLogic

@MainActor
protocol FamilyAchievementsPresentationLogic: AnyObject, Sendable {
    func presentLoad(response: FamilyAchievementsModels.Load.Response) async
    func presentRecompute(response: FamilyAchievementsModels.Recompute.Response) async
}

// MARK: - FamilyAchievementsPresenter (Clean Swift: Presenter)
//
// Block R.4 v18 — мапит Response → ViewModel.
//
// • Все строки через `String(localized:)` — ключи появятся в xcstrings
//   автоматически при сборке.
// • Family streak hero: «3/3 активны сегодня! 12 дней вместе».
// • Achievements сортируются: unlocked first, then by progressFraction desc.

@MainActor
final class FamilyAchievementsPresenter: FamilyAchievementsPresentationLogic {

    weak var displayLogic: (any FamilyAchievementsDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "FamilyAchievements.Presenter"
    )

    init(displayLogic: (any FamilyAchievementsDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Load

    func presentLoad(response: FamilyAchievementsModels.Load.Response) async {
        let streakHero = makeStreakHero(state: response.streakState)
        let memberRows = response.members.map { makeMemberRow(member: $0) }
        let achievementRows = makeAchievementRows(
            achievements: response.achievements,
            unlocked: response.unlockedIds,
            progress: response.progressById
        )
        let summary = makeSummaryRow(
            members: response.members,
            achievements: response.achievements,
            unlocked: response.unlockedIds
        )

        let viewModel = FamilyAchievementsModels.Load.ViewModel(
            streakHero: streakHero,
            memberRows: memberRows,
            achievements: achievementRows,
            summary: summary
        )

        await displayLogic?.displayLoad(viewModel: viewModel)
    }

    // MARK: - Recompute

    func presentRecompute(response: FamilyAchievementsModels.Recompute.Response) async {
        if response.newUnlockedIds.isEmpty {
            let viewModel = FamilyAchievementsModels.Recompute.ViewModel(
                toastMessage: nil,
                unlockedAchievementsTitles: []
            )
            await displayLogic?.displayRecompute(viewModel: viewModel)
            return
        }

        let titles = response.newUnlockedIds
            .compactMap { FamilyAchievement.find(id: $0) }
            .map { String(localized: String.LocalizationValue($0.titleKey)) }

        let toast: String
        if titles.count == 1 {
            toast = String(
                format: String(localized: "family.toast.unlocked.single"),
                titles[0]
            )
        } else {
            toast = String(
                format: String(localized: "family.toast.unlocked.multiple"),
                titles.count
            )
        }

        let viewModel = FamilyAchievementsModels.Recompute.ViewModel(
            toastMessage: toast,
            unlockedAchievementsTitles: titles
        )

        await displayLogic?.displayRecompute(viewModel: viewModel)
    }

    // MARK: - Helpers

    private func makeStreakHero(
        state: FamilyStreakState
    ) -> FamilyAchievementsModels.Load.StreakHeroViewModel {
        let activeLabel = String(
            format: String(localized: "family.streak.activeRatio"),
            state.activeTodayCount,
            state.totalMembers
        )

        let titleLabel: String
        let subtitleLabel: String
        let progressFraction: Double

        if state.totalMembers == 0 {
            titleLabel = String(localized: "family.streak.empty.title")
            subtitleLabel = String(localized: "family.streak.empty.subtitle")
            progressFraction = 0.0
        } else if state.allActiveToday {
            titleLabel = String(
                format: String(localized: "family.streak.together.title"),
                state.combinedDays
            )
            subtitleLabel = String(localized: "family.streak.together.subtitle")
            progressFraction = 1.0
        } else {
            titleLabel = String(localized: "family.streak.partial.title")
            subtitleLabel = String(
                format: String(localized: "family.streak.partial.subtitle"),
                state.totalMembers - state.activeTodayCount
            )
            progressFraction = state.totalMembers > 0
                ? Double(state.activeTodayCount) / Double(state.totalMembers)
                : 0.0
        }

        return FamilyAchievementsModels.Load.StreakHeroViewModel(
            combinedDays: state.combinedDays,
            activeLabel: activeLabel,
            allActiveToday: state.allActiveToday,
            titleLabel: titleLabel,
            subtitleLabel: subtitleLabel,
            progressFraction: progressFraction
        )
    }

    private func makeMemberRow(
        member: FamilyMemberSummary
    ) -> FamilyAchievementsModels.Load.MemberRow {
        let ageLabel = String(
            format: String(localized: "family.member.ageLabel"),
            member.age
        )

        let streakLabel: String
        if member.currentStreak == 0 {
            streakLabel = String(localized: "family.member.noStreak")
        } else if member.currentStreak == 1 {
            streakLabel = String(localized: "family.member.streak.day1")
        } else {
            streakLabel = String(
                format: String(localized: "family.member.streak.daysN"),
                member.currentStreak
            )
        }

        let masteredText: String
        if member.masteredSounds.isEmpty {
            masteredText = String(localized: "family.member.noMastered")
        } else {
            masteredText = member.masteredSounds.joined(separator: " · ")
        }

        let activeStatus = member.isActive
            ? String(localized: "family.member.activeToday")
            : String(localized: "family.member.notActiveToday")

        let a11y = String(
            format: String(localized: "family.member.a11y"),
            member.displayName,
            ageLabel,
            streakLabel,
            activeStatus
        )

        return FamilyAchievementsModels.Load.MemberRow(
            id: member.id,
            name: member.displayName,
            ageLabel: ageLabel,
            avatarSymbol: member.avatarSymbol,
            streakLabel: streakLabel,
            masteredSoundsLabel: masteredText,
            isActiveToday: member.isActive,
            accessibilityLabel: a11y
        )
    }

    private func makeAchievementRows(
        achievements: [FamilyAchievement],
        unlocked: Set<String>,
        progress: [String: Int]
    ) -> [FamilyAchievementsModels.Load.AchievementRow] {
        let rows = achievements.map { ach -> FamilyAchievementsModels.Load.AchievementRow in
            let title = String(localized: String.LocalizationValue(ach.titleKey))
            let description = String(
                localized: String.LocalizationValue(ach.descriptionKey)
            )
            let current = progress[ach.id] ?? 0
            let isUnlocked = unlocked.contains(ach.id)
            let progressLabel = "\(min(current, ach.totalRequired))/\(ach.totalRequired)"
            let progressFraction = ach.totalRequired > 0
                ? min(Double(current) / Double(ach.totalRequired), 1.0)
                : 0.0
            let categoryLabel = categoryLabel(for: ach.category)

            let a11y: String
            if isUnlocked {
                a11y = String(
                    format: String(localized: "family.ach.a11y.unlocked"),
                    title,
                    progressLabel
                )
            } else {
                a11y = String(
                    format: String(localized: "family.ach.a11y.locked"),
                    title,
                    progressLabel
                )
            }

            return FamilyAchievementsModels.Load.AchievementRow(
                id: ach.id,
                title: title,
                description: description,
                symbolName: ach.symbolName,
                isUnlocked: isUnlocked,
                progressLabel: progressLabel,
                progressFraction: progressFraction,
                categoryLabel: categoryLabel,
                accessibilityLabel: a11y
            )
        }

        // Сортировка: unlocked сначала, потом по progressFraction desc.
        return rows.sorted { lhs, rhs in
            if lhs.isUnlocked != rhs.isUnlocked {
                return lhs.isUnlocked
            }
            return lhs.progressFraction > rhs.progressFraction
        }
    }

    private func categoryLabel(for category: FamilyAchievement.Category) -> String {
        switch category {
        case .streak:    return String(localized: "family.ach.category.streak")
        case .sounds:    return String(localized: "family.ach.category.sounds")
        case .sessions:  return String(localized: "family.ach.category.sessions")
        case .milestone: return String(localized: "family.ach.category.milestone")
        case .bonus:     return String(localized: "family.ach.category.bonus")
        }
    }

    private func makeSummaryRow(
        members: [FamilyMemberSummary],
        achievements: [FamilyAchievement],
        unlocked: Set<String>
    ) -> FamilyAchievementsModels.Load.SummaryRow {
        let totalSessions = members.reduce(0) { $0 + $1.totalSessions }
        let totalMastered = Set(members.flatMap { $0.masteredSounds }).count

        let sessionsLabel = String(
            format: String(localized: "family.summary.sessions"),
            totalSessions
        )
        let masteredLabel = String(
            format: String(localized: "family.summary.mastered"),
            totalMastered
        )

        return FamilyAchievementsModels.Load.SummaryRow(
            totalSessionsLabel: sessionsLabel,
            totalMasteredSoundsLabel: masteredLabel,
            unlockedCount: unlocked.count,
            totalCount: achievements.count
        )
    }
}
