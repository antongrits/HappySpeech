import Foundation
import OSLog

// MARK: - DailyStreakPresentationLogic

@MainActor
protocol DailyStreakPresentationLogic: AnyObject, Sendable {
    func presentLoad(response: DailyStreakModels.Load.Response) async
    func presentCheckIn(response: DailyStreakModels.CheckIn.Response) async
    func presentUseSaver(response: DailyStreakModels.UseSaver.Response) async
}

// MARK: - DailyStreakPresenter (Clean Swift: Presenter)
//
// Block S.1 v16 — мапит Response → ViewModel.
//
// • Локализация через `String(localized:)` — ключи появляются в xcstrings
//   автоматически при сборке.
// • Доли прогресса: текущий стрик / след milestone.
// • Список milestones: уникальная иконка + флаг unlock.

@MainActor
final class DailyStreakPresenter: DailyStreakPresentationLogic {

    weak var displayLogic: (any DailyStreakDisplayLogic)?

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "DailyStreak.Presenter")

    init(displayLogic: (any DailyStreakDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Load

    func presentLoad(response: DailyStreakModels.Load.Response) async {
        let progress = computeProgress(
            current: response.currentStreak,
            next: response.nextMilestone
        )

        let statusLabel: String
        let statusEmoji: String
        switch response.status {
        case .fresh:
            statusLabel = String(localized: "streak.status.fresh")
            statusEmoji = "🌱"
        case .active:
            statusLabel = String(localized: "streak.status.active")
            statusEmoji = "🔥"
        case .pendingToday:
            statusLabel = String(localized: "streak.status.pending")
            statusEmoji = "⏳"
        case .broken:
            statusLabel = String(localized: "streak.status.broken")
            statusEmoji = "💤"
        case .saved:
            statusLabel = String(localized: "streak.status.saved")
            statusEmoji = "🛟"
        }

        let saverHint: String
        if response.saver.availableThisMonth {
            saverHint = String(localized: "streak.saver.hint.available")
        } else {
            saverHint = String(localized: "streak.saver.hint.usedThisMonth")
        }

        let milestonesRows = DailyStreakMilestone.all.map { milestone in
            DailyStreakModels.Load.MilestoneRow(
                id: milestone.id,
                title: String(localized: String.LocalizationValue(milestone.titleKey)),
                days: milestone.days,
                symbolName: milestone.symbolName,
                isUnlocked: response.unlockedMilestones.contains(milestone),
                accessibilityLabel: String(
                    format: String(localized: "streak.milestone.a11y"),
                    milestone.days
                )
            )
        }

        let viewModel = DailyStreakModels.Load.ViewModel(
            currentStreak: response.currentStreak,
            longestStreak: response.longestStreak,
            statusLabel: statusLabel,
            statusEmoji: statusEmoji,
            progressToNext: progress,
            nextMilestoneTitle: response.nextMilestone.map {
                String(localized: String.LocalizationValue($0.titleKey))
            },
            nextMilestoneDays: response.nextMilestone?.days,
            unlockedCount: response.unlockedMilestones.count,
            totalMilestones: DailyStreakMilestone.all.count,
            saverAvailable: response.saver.availableThisMonth,
            saverHintLabel: saverHint,
            milestones: milestonesRows
        )

        await displayLogic?.displayLoad(viewModel: viewModel)
    }

    // MARK: - CheckIn

    func presentCheckIn(response: DailyStreakModels.CheckIn.Response) async {
        let toast: String
        let celebrate: Bool
        var milestoneTitle: String?
        if let milestone = response.unlockedMilestone {
            toast = String(
                format: String(localized: "streak.toast.milestoneUnlocked"),
                milestone.days
            )
            celebrate = true
            milestoneTitle = String(localized: String.LocalizationValue(milestone.titleKey))
        } else if response.status == .broken {
            toast = String(localized: "streak.toast.broken")
            celebrate = false
        } else if response.newStreak > 1 {
            toast = String(
                format: String(localized: "streak.toast.continued"),
                response.newStreak
            )
            celebrate = false
        } else {
            toast = String(localized: "streak.toast.started")
            celebrate = true
        }

        let viewModel = DailyStreakModels.CheckIn.ViewModel(
            toastMessage: toast,
            celebrate: celebrate,
            unlockedMilestoneTitle: milestoneTitle
        )
        await displayLogic?.displayCheckIn(viewModel: viewModel)
    }

    // MARK: - UseSaver

    func presentUseSaver(response: DailyStreakModels.UseSaver.Response) async {
        let banner: String
        if response.success {
            banner = String(
                format: String(localized: "streak.saver.success"),
                response.restoredStreak
            )
        } else {
            banner = String(localized: "streak.saver.unavailable")
        }

        let viewModel = DailyStreakModels.UseSaver.ViewModel(
            bannerMessage: banner,
            success: response.success
        )
        await displayLogic?.displayUseSaver(viewModel: viewModel)
    }

    // MARK: - Helpers

    private func computeProgress(current: Int, next: DailyStreakMilestone?) -> Double {
        guard let next else { return 1.0 }
        guard let previous = DailyStreakMilestone.all.last(where: { $0.days <= current }) else {
            return Double(current) / Double(next.days)
        }
        let span = Double(next.days - previous.days)
        guard span > 0 else { return 1.0 }
        let walked = Double(current - previous.days)
        return min(max(walked / span, 0.0), 1.0)
    }
}
