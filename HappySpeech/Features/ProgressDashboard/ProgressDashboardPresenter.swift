import Foundation
import OSLog

// MARK: - ProgressDashboardPresentationLogic

@MainActor
protocol ProgressDashboardPresentationLogic: AnyObject {
    func presentLoadDashboard(_ response: ProgressDashboardModels.LoadDashboard.Response)
    func presentLoadSoundDetail(_ response: ProgressDashboardModels.LoadSoundDetail.Response)
    func presentRequestLLMSummary(_ response: ProgressDashboardModels.RequestLLMSummary.Response)
    func presentLoadInsights(_ response: ProgressDashboardModels.LoadInsights.Response)
    func presentInsightsLoading(_ isLoading: Bool)
    func presentLLMLoading(_ isLoading: Bool)
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
        // Сортируем cells: worst first — фокус внимания родителя на проблемных звуках.
        let sortedSounds = response.sounds.sorted { $0.accuracy < $1.accuracy }
        let soundCells = sortedSounds.map(makeSoundCell)

        let topPerformers = makeTopPerformers(response.sounds)
        let needsWork = makeNeedsWork(response.sounds)
        let recommendations = makeRecommendations(response.recommendations)
        let periodOptions = makePeriodOptions(selected: response.period)

        let isEmpty = response.sounds.isEmpty
        let viewModel = ProgressDashboardModels.LoadDashboard.ViewModel(
            summaryCards: summaryCards,
            dailyChart: dailyChart,
            weeklyChart: weeklyChart,
            dailyAxisLabels: response.dailyAccuracy.map(\.day),
            soundCells: soundCells,
            topPerformers: topPerformers,
            needsWork: needsWork,
            recommendations: recommendations,
            periodOptions: periodOptions,
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

    func presentLoadInsights(_ response: ProgressDashboardModels.LoadInsights.Response) {
        let cards = response.insights.map { insight in
            ParentInsightCardViewModel(
                id: insight.id.uuidString,
                icon: insight.icon,
                toneRawValue: toneRawValue(insight.tone),
                text: insight.text,
                accessibilityLabel: insight.text
            )
        }
        display?.displayLoadInsights(.init(insightCards: cards))
    }

    func presentInsightsLoading(_ isLoading: Bool) {
        display?.displayInsightsLoading(isLoading)
    }

    func presentLLMLoading(_ isLoading: Bool) {
        display?.displayLLMLoading(isLoading)
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

    // MARK: - Top performers / needs work

    private func makeTopPerformers(_ sounds: [SoundProgress]) -> [SoundChipViewModel] {
        sounds
            .filter { $0.accuracy >= 0.80 }
            .sorted { $0.accuracy > $1.accuracy }
            .prefix(3)
            .map { progress in
                let percent = Int(progress.accuracy * 100)
                let label = String(
                    format: String(localized: "progressDashboard.a11y.topChipPattern"),
                    progress.sound, percent
                )
                return SoundChipViewModel(
                    sound: progress.sound,
                    percentText: "\(percent)%",
                    tone: .positive,
                    accessibilityLabel: label
                )
            }
    }

    private func makeNeedsWork(_ sounds: [SoundProgress]) -> [SoundChipViewModel] {
        sounds
            .filter { $0.accuracy < 0.60 }
            .sorted { $0.accuracy < $1.accuracy }
            .prefix(3)
            .map { progress in
                let percent = Int(progress.accuracy * 100)
                let label = String(
                    format: String(localized: "progressDashboard.a11y.workChipPattern"),
                    progress.sound, percent
                )
                return SoundChipViewModel(
                    sound: progress.sound,
                    percentText: "\(percent)%",
                    tone: .attention,
                    accessibilityLabel: label
                )
            }
    }

    // MARK: - Recommendations

    private func makeRecommendations(_ items: [String]) -> [RecommendationViewModel] {
        items.enumerated().map { index, text in
            RecommendationViewModel(
                id: index,
                text: text,
                iconName: "checkmark.circle.fill",
                accessibilityLabel: text
            )
        }
    }

    // MARK: - Insight tone

    private func toneRawValue(_ tone: InsightTone) -> String {
        switch tone {
        case .positive: return "positive"
        case .neutral:  return "neutral"
        case .warning:  return "warning"
        }
    }

    // MARK: - Period options

    private func makePeriodOptions(selected: ProgressDashboardModels.TimePeriod) -> [PeriodOptionViewModel] {
        ProgressDashboardModels.TimePeriod.allCases.map { period in
            let title = String(localized: period.titleKey)
            let isSelected = (period == selected)
            let label = String(
                format: String(localized: "progressDashboard.a11y.periodPattern"),
                title,
                isSelected ? String(localized: "progressDashboard.a11y.selected") : ""
            )
            return PeriodOptionViewModel(
                period: period,
                title: title,
                isSelected: isSelected,
                accessibilityLabel: label
            )
        }
    }
}
