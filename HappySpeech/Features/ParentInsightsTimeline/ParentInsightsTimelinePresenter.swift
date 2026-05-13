import Foundation
import OSLog

// MARK: - ParentInsightsTimelinePresentationLogic

@MainActor
protocol ParentInsightsTimelinePresentationLogic: AnyObject {
    func presentLoad(response: ParentInsightsTimelineModels.Load.Response) async
    func presentSelectDay(response: ParentInsightsTimelineModels.SelectDay.Response) async
    func presentRefresh(response: ParentInsightsTimelineModels.Refresh.Response) async
}

// MARK: - ParentInsightsTimelinePresenter (Clean Swift: Presenter)
//
// Block AE batch 2 v21 — мапит Response → ViewModel.

@MainActor
final class ParentInsightsTimelinePresenter: ParentInsightsTimelinePresentationLogic {

    weak var displayLogic: (any ParentInsightsTimelineDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ParentInsightsTimeline.Presenter"
    )

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM"
        return f
    }()

    init(displayLogic: (any ParentInsightsTimelineDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Load

    func presentLoad(response: ParentInsightsTimelineModels.Load.Response) async {
        let heroTitle = String(
            format: String(localized: "parentInsightsTimeline.hero.title"),
            response.childName
        )
        let heroSubtitle: String = {
            guard let first = response.insights.first, let last = response.insights.last else {
                return ""
            }
            return String(
                format: String(localized: "parentInsightsTimeline.hero.subtitle.range"),
                dateFormatter.string(from: first.day),
                dateFormatter.string(from: last.day)
            )
        }()

        let cells: [ParentInsightsTimelineModels.Load.DayCellViewModel] = response.insights.map { insight in
            let metricsLine = String(
                format: String(localized: "parentInsightsTimeline.cell.metrics"),
                insight.sessionCount,
                insight.minutesPracticed,
                Int(insight.successRate * 100)
            )
            let comment: String
            if let llm = insight.llmComment, !llm.isEmpty {
                comment = llm
            } else {
                comment = WeekTimelineBuilder.heuristicComment(
                    sessionCount: insight.sessionCount,
                    minutes: insight.minutesPracticed,
                    successRate: insight.successRate,
                    isToday: insight.isToday
                )
            }
            let a11y = String(
                format: String(localized: "parentInsightsTimeline.cell.a11y"),
                insight.weekdayShort,
                metricsLine,
                comment
            )

            return .init(
                id: insight.id,
                weekdayShort: insight.weekdayShort,
                dateLabel: dateFormatter.string(from: insight.day),
                severitySymbol: insight.severity.symbolName,
                severityColorName: insight.severity.rawValue,
                metricsLine: metricsLine,
                comment: comment,
                isToday: insight.isToday,
                accessibilityLabel: a11y
            )
        }

        let summaryStats: [ParentInsightsTimelineModels.Load.SummaryStat] = [
            .init(
                id: "sessions",
                label: String(localized: "parentInsightsTimeline.stat.sessions.label"),
                value: "\(response.summary.totalSessions)",
                symbolName: "list.bullet.rectangle"
            ),
            .init(
                id: "minutes",
                label: String(localized: "parentInsightsTimeline.stat.minutes.label"),
                value: String(
                    format: String(localized: "parentInsightsTimeline.stat.minutes.value"),
                    response.summary.totalMinutes
                ),
                symbolName: "clock"
            ),
            .init(
                id: "successRate",
                label: String(localized: "parentInsightsTimeline.stat.successRate.label"),
                value: "\(Int(response.summary.averageSuccessRate * 100))%",
                symbolName: "chart.line.uptrend.xyaxis"
            ),
            .init(
                id: "activeDays",
                label: String(localized: "parentInsightsTimeline.stat.activeDays.label"),
                value: String(
                    format: String(localized: "parentInsightsTimeline.stat.activeDays.value"),
                    response.summary.activeDays
                ),
                symbolName: "flame.fill"
            )
        ]

        let llmSourceLabel: String = response.usedLLM
            ? String(localized: "parentInsightsTimeline.source.llmA")
            : String(localized: "parentInsightsTimeline.source.heuristic")

        let viewModel = ParentInsightsTimelineModels.Load.ViewModel(
            heroTitle: heroTitle,
            heroSubtitle: heroSubtitle,
            summaryStats: summaryStats,
            cells: cells,
            llmSourceLabel: llmSourceLabel
        )

        await displayLogic?.displayLoad(viewModel: viewModel)
    }

    // MARK: - SelectDay

    func presentSelectDay(response: ParentInsightsTimelineModels.SelectDay.Response) async {
        let insight = response.insight
        let titleLabel = String(
            format: String(localized: "parentInsightsTimeline.detail.title"),
            insight.weekdayShort,
            dateFormatter.string(from: insight.day)
        )
        let metricsLabel = String(
            format: String(localized: "parentInsightsTimeline.detail.metrics"),
            insight.sessionCount,
            insight.minutesPracticed,
            Int(insight.successRate * 100)
        )

        let recommendation: String? = {
            switch insight.severity {
            case .attention:
                return String(localized: "parentInsightsTimeline.detail.recommendation.attention")
            case .positive:
                return String(localized: "parentInsightsTimeline.detail.recommendation.positive")
            case .neutral:
                return nil
            }
        }()

        let viewModel = ParentInsightsTimelineModels.SelectDay.ViewModel(
            titleLabel: titleLabel,
            metricsLabel: metricsLabel,
            detailParagraph: response.detail,
            recommendationLabel: recommendation
        )
        await displayLogic?.displaySelectDay(viewModel: viewModel)
    }

    // MARK: - Refresh

    func presentRefresh(response: ParentInsightsTimelineModels.Refresh.Response) async {
        let toast = String(localized: String.LocalizationValue(response.toastKey))
        let viewModel = ParentInsightsTimelineModels.Refresh.ViewModel(toastMessage: toast)
        await displayLogic?.displayRefresh(viewModel: viewModel)
    }
}
