import Foundation
import OSLog

// MARK: - ProgressDashboardPresentationLogic

@MainActor
protocol ProgressDashboardPresentationLogic: AnyObject {
    func presentLoadDashboard(_ response: ProgressDashboardModels.LoadDashboard.Response)
    func presentLoadSoundDetail(_ response: ProgressDashboardModels.LoadSoundDetail.Response)
    func presentRequestLLMSummary(_ response: ProgressDashboardModels.RequestLLMSummary.Response)
    func presentFailure(_ response: ProgressDashboardModels.Failure.Response)
}

// MARK: - ProgressDashboardPresenter

@MainActor
final class ProgressDashboardPresenter: ProgressDashboardPresentationLogic {

    weak var display: (any ProgressDashboardDisplayLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "ProgressDashboardPresenter")

    // MARK: - PresentationLogic

    func presentLoadDashboard(_ response: ProgressDashboardModels.LoadDashboard.Response) {
        let summaryCards = makeSummaryCards(response.summary)
        let dailyChart = response.dailyAccuracy.map {
            DailyChartPoint(day: $0.day, value: Double($0.accuracy * 100))
        }
        let weeklyChart = response.weeklyAccuracy.map {
            WeeklyChartPoint(weekIndex: $0.weekIndex, label: $0.label, value: Double($0.accuracy * 100))
        }
        let soundCells = response.sounds.map(makeSoundCell)
        let isEmpty = response.sounds.isEmpty
        let viewModel = ProgressDashboardModels.LoadDashboard.ViewModel(
            summaryCards: summaryCards,
            dailyChart: dailyChart,
            weeklyChart: weeklyChart,
            dailyAxisLabels: response.dailyAccuracy.map(\.day),
            soundCells: soundCells,
            isEmpty: isEmpty,
            emptyTitle: String(localized: "progressDashboard.empty.title"),
            emptyMessage: String(localized: "progressDashboard.empty.message")
        )
        display?.displayLoadDashboard(viewModel)
    }

    func presentLoadSoundDetail(_ response: ProgressDashboardModels.LoadSoundDetail.Response) {
        let history = response.history.map {
            DailyChartPoint(day: $0.day, value: Double($0.accuracy * 100))
        }
        let percent = Int(response.progress.accuracy * 100)
        let trendDesc = trendDescription(for: response.progress.trend)
        let title = String(
            format: String(localized: "progressDashboard.detail.titlePattern"),
            response.progress.sound
        )
        let label = String(
            format: String(localized: "progressDashboard.a11y.detailPattern"),
            response.progress.sound,
            percent,
            response.progress.sessions,
            trendDesc
        )
        let detail = SoundDetailViewModel(
            sound: response.progress.sound,
            accuracyPercent: percent,
            sessionsCount: response.progress.sessions,
            trend: response.progress.trend,
            history: history,
            title: title,
            trendDescription: trendDesc,
            accessibilityLabel: label
        )
        display?.displayLoadSoundDetail(.init(detail: detail))
    }

    func presentRequestLLMSummary(_ response: ProgressDashboardModels.RequestLLMSummary.Response) {
        let label = String(
            format: String(localized: "progressDashboard.a11y.llmSummaryPattern"),
            response.summaryText
        )
        let viewModel = LLMSummaryViewModel(
            title: String(localized: "progressDashboard.llm.title"),
            bodyText: response.summaryText,
            isFallback: response.isFallback,
            accessibilityLabel: label
        )
        display?.displayRequestLLMSummary(.init(summary: viewModel))
    }

    func presentFailure(_ response: ProgressDashboardModels.Failure.Response) {
        logger.error("failure: \(response.message, privacy: .public)")
        display?.displayFailure(.init(toastMessage: response.message))
    }

    // MARK: - Helpers

    private func makeSummaryCards(_ summary: DashboardSummary) -> [SummaryCardViewModel] {
        let accuracyPercent = Int(summary.overallAccuracy * 100)
        let accuracyCard = SummaryCardViewModel(
            id: "accuracy",
            kind: .accuracy,
            title: String(localized: "progressDashboard.summary.accuracy"),
            value: "\(accuracyPercent)%",
            valueAccent: .accent,
            caption: nil,
            progress: Double(summary.overallAccuracy),
            accessibilityLabel: String(
                format: String(localized: "progressDashboard.a11y.accuracyPattern"),
                accuracyPercent
            )
        )

        let streakCard = SummaryCardViewModel(
            id: "streak",
            kind: .streak,
            title: String(localized: "progressDashboard.summary.streak"),
            value: "\(summary.streakDays)",
            valueAccent: .butter,
            caption: String(
                format: String(localized: "progressDashboard.summary.daysSuffix"),
                summary.streakDays
            ),
            progress: nil,
            accessibilityLabel: String(
                format: String(localized: "progressDashboard.a11y.streakPattern"),
                summary.streakDays
            )
        )

        let minutesCard = SummaryCardViewModel(
            id: "minutes",
            kind: .minutes,
            title: String(localized: "progressDashboard.summary.minutes"),
            value: "\(summary.totalMinutes)",
            valueAccent: .mint,
            caption: String(localized: "progressDashboard.summary.minutesSuffix"),
            progress: nil,
            accessibilityLabel: String(
                format: String(localized: "progressDashboard.a11y.minutesPattern"),
                summary.totalMinutes
            )
        )

        let starsCard = SummaryCardViewModel(
            id: "stars",
            kind: .stars,
            title: String(localized: "progressDashboard.summary.stars"),
            value: "\(summary.totalStars)",
            valueAccent: .lilac,
            caption: String(localized: "progressDashboard.summary.starsSuffix"),
            progress: nil,
            accessibilityLabel: String(
                format: String(localized: "progressDashboard.a11y.starsPattern"),
                summary.totalStars
            )
        )

        return [accuracyCard, streakCard, minutesCard, starsCard]
    }

    private func makeSoundCell(_ progress: SoundProgress) -> SoundProgressCellViewModel {
        let percent = Int(progress.accuracy * 100)
        let icon: String
        switch progress.trend {
        case .up:     icon = "arrow.up.right"
        case .down:   icon = "arrow.down.right"
        case .stable: icon = "equal"
        }
        let sessionsCaption = String(
            format: String(localized: "progressDashboard.sound.sessionsPattern"),
            progress.sessions
        )
        let label = String(
            format: String(localized: "progressDashboard.a11y.soundCellPattern"),
            progress.sound,
            percent,
            progress.sessions,
            trendDescription(for: progress.trend)
        )

        return SoundProgressCellViewModel(
            id: progress.sound,
            sound: progress.sound,
            accuracyText: "\(percent)%",
            accuracyValue: Double(percent),
            trend: progress.trend,
            trendIconName: icon,
            sessionsCaption: sessionsCaption,
            familyHueName: familyHueName(for: progress.sound),
            accessibilityLabel: label
        )
    }

    private func familyHueName(for sound: String) -> String {
        switch sound {
        case "С", "З", "Ц":           return "SoundWhistlingHue"
        case "Ш", "Ж", "Ч", "Щ":      return "SoundHissingHue"
        case "Р", "Рь", "Л", "Ль":   return "SoundSonorantHue"
        case "К", "Г", "Х":           return "SoundVelarHue"
        default:                       return "SoundVowelsHue"
        }
    }

    private func trendDescription(for trend: ProgressTrend) -> String {
        switch trend {
        case .up:     return String(localized: "progressDashboard.trend.up")
        case .down:   return String(localized: "progressDashboard.trend.down")
        case .stable: return String(localized: "progressDashboard.trend.stable")
        }
    }
}
