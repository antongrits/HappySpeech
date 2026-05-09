import Foundation
import OSLog

// MARK: - WeeklyChallengePresentationLogic

@MainActor
protocol WeeklyChallengePresentationLogic: AnyObject, Sendable {
    func presentLoad(response: WeeklyChallengeModels.Load.Response) async
    func presentMarkDay(response: WeeklyChallengeModels.MarkDay.Response) async
    func presentSwitchKind(response: WeeklyChallengeModels.SwitchKind.Response) async
}

// MARK: - WeeklyChallengePresenter (Clean Swift: Presenter)
//
// Block R.3 v18 — мапит Response → ViewModel.
//
// • Все строки через `String(localized:)` — ключи появятся в xcstrings
//   автоматически при сборке.
// • Дни недели локализованы (Пн, Вт, Ср ...).
// • Symbol per DayProgress: locked=lock.fill, pending=circle.dashed,
//   completed=checkmark.circle.fill, missed=xmark.circle.

@MainActor
final class WeeklyChallengePresenter: WeeklyChallengePresentationLogic {

    weak var displayLogic: (any WeeklyChallengeDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WeeklyChallenge.Presenter"
    )

    private let weekdayShortNames: [String] = [
        "Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"
    ]

    init(displayLogic: (any WeeklyChallengeDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Load

    func presentLoad(response: WeeklyChallengeModels.Load.Response) async {
        let state = response.state
        let title = String(localized: String.LocalizationValue(state.kind.titleKey))
        let description = String(localized: String.LocalizationValue(state.kind.descriptionKey))
        let progressLabel = "\(state.completed)/\(state.totalRequired)"
        let percent = Int(state.progress * 100)
        let percentLabel = "\(percent)%"

        let cells = (0..<7).map { idx -> WeeklyChallengeModels.Load.DayCellViewModel in
            let progress = state.dayStates[idx]
            return WeeklyChallengeModels.Load.DayCellViewModel(
                id: idx,
                dayLabel: weekdayShortNames[idx],
                progress: progress,
                symbolName: symbol(for: progress),
                accessibilityLabel: a11y(for: progress, dayName: weekdayShortNames[idx])
            )
        }

        let endOfWeekLabel: String
        if response.daysUntilEndOfWeek <= 0 {
            endOfWeekLabel = String(localized: "weekly.endOfWeek.today")
        } else if response.daysUntilEndOfWeek == 1 {
            endOfWeekLabel = String(localized: "weekly.endOfWeek.tomorrow")
        } else {
            endOfWeekLabel = String(
                format: String(localized: "weekly.endOfWeek.days"),
                response.daysUntilEndOfWeek
            )
        }

        let rewardTitle = String(localized: String.LocalizationValue(response.reward.titleKey))

        let viewModel = WeeklyChallengeModels.Load.ViewModel(
            challengeTitle: title,
            challengeDescription: description,
            symbolName: state.kind.symbolName,
            progressLabel: progressLabel,
            progress: state.progress,
            progressPercentLabel: percentLabel,
            dayCells: cells,
            endOfWeekLabel: endOfWeekLabel,
            rewardTitle: rewardTitle,
            rewardSymbol: response.reward.symbolName,
            rewardUnlocked: response.reward.isUnlocked,
            isCompleted: state.isCompleted
        )

        await displayLogic?.displayLoad(viewModel: viewModel)
    }

    // MARK: - MarkDay

    func presentMarkDay(response: WeeklyChallengeModels.MarkDay.Response) async {
        let toast: String
        let celebrate: Bool
        if response.unlockedReward {
            toast = String(localized: "weekly.toast.rewardUnlocked")
            celebrate = true
        } else if response.updatedState.isCompleted {
            toast = String(localized: "weekly.toast.completed")
            celebrate = true
        } else {
            toast = String(
                format: String(localized: "weekly.toast.dayMarked"),
                response.updatedState.completed,
                response.updatedState.totalRequired
            )
            celebrate = false
        }

        let viewModel = WeeklyChallengeModels.MarkDay.ViewModel(
            toastMessage: toast,
            celebrate: celebrate
        )

        await displayLogic?.displayMarkDay(viewModel: viewModel)
    }

    // MARK: - SwitchKind

    func presentSwitchKind(response: WeeklyChallengeModels.SwitchKind.Response) async {
        let title = String(
            localized: String.LocalizationValue(response.newState.kind.titleKey)
        )
        let toast = String(
            format: String(localized: "weekly.toast.kindSwitched"),
            title
        )

        let viewModel = WeeklyChallengeModels.SwitchKind.ViewModel(
            toastMessage: toast
        )

        await displayLogic?.displaySwitchKind(viewModel: viewModel)
    }

    // MARK: - Helpers

    private func symbol(for progress: DayProgress) -> String {
        switch progress {
        case .locked:    return "lock.fill"
        case .pending:   return "circle.dashed"
        case .completed: return "checkmark.circle.fill"
        case .missed:    return "xmark.circle"
        }
    }

    private func a11y(for progress: DayProgress, dayName: String) -> String {
        switch progress {
        case .locked:
            return String(format: String(localized: "weekly.day.a11y.locked"), dayName)
        case .pending:
            return String(format: String(localized: "weekly.day.a11y.pending"), dayName)
        case .completed:
            return String(format: String(localized: "weekly.day.a11y.completed"), dayName)
        case .missed:
            return String(format: String(localized: "weekly.day.a11y.missed"), dayName)
        }
    }
}
