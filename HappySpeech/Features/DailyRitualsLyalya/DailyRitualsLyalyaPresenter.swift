import Foundation
import OSLog

// MARK: - DailyRitualsLyalyaPresentationLogic

@MainActor
protocol DailyRitualsLyalyaPresentationLogic: AnyObject {
    func presentLoad(response: DailyRitualsLyalyaModels.Load.Response) async
    func presentToggleReminder(response: DailyRitualsLyalyaModels.ToggleReminder.Response) async
    func presentUpdateTime(response: DailyRitualsLyalyaModels.UpdateTime.Response) async
    func presentPermissionResult(response: DailyRitualsLyalyaModels.RequestPermission.Response) async
}

// MARK: - DailyRitualsLyalyaPresenter (Clean Swift: Presenter)

@MainActor
final class DailyRitualsLyalyaPresenter: DailyRitualsLyalyaPresentationLogic {

    weak var displayLogic: (any DailyRitualsLyalyaDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "DailyRituals.Presenter"
    )

    init(displayLogic: (any DailyRitualsLyalyaDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    func presentLoad(response: DailyRitualsLyalyaModels.Load.Response) async {
        let steps = response.steps.map(makeStepViewModel)
        let totalSeconds = response.steps.reduce(0) { $0 + $1.durationSeconds }
        let totalMinutes = max(1, Int(round(Double(totalSeconds) / 60.0)))
        let totalMinutesLabel = String(
            format: String(localized: "dailyRituals.totalMinutes"),
            totalMinutes
        )
        let reminderTimeLabel = String(
            format: "%02d:%02d",
            response.reminderTime.hour,
            response.reminderTime.minute
        )
        let needsAuth = response.reminderEnabled && !response.notificationsAuthorized
        let viewModel = DailyRitualsLyalyaModels.Load.ViewModel(
            kind: response.kind,
            title: localized(response.kind.titleKey),
            subtitle: localized(response.kind.subtitleKey),
            symbolName: response.kind.symbolName,
            steps: steps,
            totalMinutesLabel: totalMinutesLabel,
            reminderToggleLabel: String(localized: "dailyRituals.reminder.toggle.label"),
            reminderToggleSubtitle: String(localized: "dailyRituals.reminder.toggle.subtitle"),
            reminderEnabled: response.reminderEnabled,
            reminderTime: response.reminderTime,
            reminderTimeLabel: reminderTimeLabel,
            needsAuthorization: needsAuth,
            authorizationCtaLabel: String(localized: "dailyRituals.reminder.authorize.cta")
        )
        await displayLogic?.displayLoad(viewModel: viewModel)
    }

    func presentToggleReminder(response: DailyRitualsLyalyaModels.ToggleReminder.Response) async {
        await displayLogic?.displayToggleReminder(response: response)
    }

    func presentUpdateTime(response: DailyRitualsLyalyaModels.UpdateTime.Response) async {
        await displayLogic?.displayUpdateTime(response: response)
    }

    func presentPermissionResult(response: DailyRitualsLyalyaModels.RequestPermission.Response) async {
        await displayLogic?.displayPermissionResult(response: response)
    }

    // MARK: - Helpers

    private func makeStepViewModel(_ step: RitualStep) -> DailyRitualsLyalyaModels.Load.StepViewModel {
        let title = localized(step.titleKey)
        let description = localized(step.descriptionKey)
        let minutes = max(1, Int(round(Double(step.durationSeconds) / 60.0)))
        let durationLabel = String(
            format: String(localized: "dailyRituals.step.minutes"),
            minutes
        )
        return .init(
            id: step.id,
            title: title,
            description: description,
            symbolName: step.symbolName,
            durationLabel: durationLabel,
            accessibilityLabel: "\(title). \(description). \(durationLabel)"
        )
    }

    private func localized(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }
}
