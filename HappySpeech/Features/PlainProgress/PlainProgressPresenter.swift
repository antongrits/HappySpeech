import Foundation
import OSLog

// MARK: - PlainProgressPresentationLogic

@MainActor
protocol PlainProgressPresentationLogic: AnyObject {
    func presentLoad(response: PlainProgressModels.Load.Response) async
    func presentLoadFailure(error: Error) async
    func presentShare(response: PlainProgressModels.Load.Response) async
}

// MARK: - PlainProgressPresenter (Clean Swift: Presenter)
//
// v29 Фаза 8, Функция 9 «Понятный прогресс».
//
// Собирает человекочитаемый нарратив из размеченных шаблонов
// (`PlainProgressTemplates`), подставляя реальные метрики. Все строки —
// через `String(localized:)`. Никаких диагнозов и гарантий (project guide §11).

@MainActor
final class PlainProgressPresenter: PlainProgressPresentationLogic {

    weak var displayLogic: (any PlainProgressDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "PlainProgress.Presenter"
    )

    init(displayLogic: (any PlainProgressDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Load

    func presentLoad(response: PlainProgressModels.Load.Response) async {
        let viewModel = PlainProgressModels.Load.ViewModel(
            headerTitle: String(localized: "plainProgress.header.title"),
            headerSubtitle: String(
                format: String(localized: "plainProgress.header.subtitle"),
                response.childName
            ),
            narrative: makeNarrative(response),
            comparison: makeComparison(response),
            milestones: makeMilestones(response),
            recommendationTitle: String(localized: "plainProgress.reco.sectionTitle"),
            recommendationText: makeRecommendation(response),
            shareButtonTitle: String(localized: "plainProgress.share.button"),
            emptyStateText: response.hasWeekData
                ? nil
                : String(localized: "plainProgress.empty.text")
        )
        await displayLogic?.displayLoad(viewModel: viewModel)
    }

    func presentLoadFailure(error: Error) async {
        Self.logger.error("Presenting failure: \(error.localizedDescription, privacy: .public)")
        await displayLogic?.displayLoadFailure(
            message: String(localized: "plainProgress.error.load")
        )
    }

    // MARK: - Share

    func presentShare(response: PlainProgressModels.Load.Response) async {
        let summary = String(
            format: String(localized: "plainProgress.share.summary"),
            response.childName,
            Self.percent(response.weekSuccessRate),
            response.sessionsThisWeek,
            response.practiceMinutesThisWeek,
            response.focusSound
        )
        await displayLogic?.displayShare(
            viewModel: .init(summaryText: summary)
        )
    }

    // MARK: - Narrative builder

    private func makeNarrative(
        _ response: PlainProgressModels.Load.Response
    ) -> PlainProgressModels.Load.NarrativeViewModel {

        let trend = response.trend
        let title = localized(PlainProgressTemplates.narrativeTitleKey(for: trend))

        let opening = String(
            format: localized(PlainProgressTemplates.openingKey(for: trend)),
            response.childName
        )

        let body: String
        if trend == .noData {
            body = opening
        } else {
            let focus = String(
                format: localized(PlainProgressTemplates.focusSoundKey(rate: response.focusSoundRate)),
                response.focusSound,
                Self.percent(response.focusSoundRate)
            )
            let closing = localized(PlainProgressTemplates.closingKey(for: trend))
            body = "\(opening) \(focus) \(closing)"
        }

        let metricsLine = response.hasWeekData
            ? String(
                format: String(localized: "plainProgress.narrative.metrics"),
                response.sessionsThisWeek,
                response.practiceMinutesThisWeek,
                Self.percent(response.weekSuccessRate)
            )
            : String(localized: "plainProgress.narrative.metrics.none")

        return .init(
            title: title,
            body: body,
            trendSymbol: trend.symbolName,
            trendTint: Self.tint(for: trend),
            metricsLine: metricsLine
        )
    }

    // MARK: - Comparison builder

    private func makeComparison(
        _ response: PlainProgressModels.Load.Response
    ) -> PlainProgressModels.Load.ComparisonViewModel? {
        // Сравнение показываем только когда есть данные обоих периодов.
        guard response.hasWeekData, response.monthAgoSuccessRate > 0 else { return nil }

        let delta = response.weekSuccessRate - response.monthAgoSuccessRate
        let deltaText: String
        if delta >= 0.06 {
            deltaText = String(
                format: String(localized: "plainProgress.comparison.delta.up"),
                Self.percent(abs(delta))
            )
        } else if delta <= -0.06 {
            deltaText = String(
                format: String(localized: "plainProgress.comparison.delta.down"),
                Self.percent(abs(delta))
            )
        } else {
            deltaText = String(localized: "plainProgress.comparison.delta.same")
        }

        return .init(
            title: String(localized: "plainProgress.comparison.title"),
            monthAgoLabel: String(localized: "plainProgress.comparison.monthAgo"),
            monthAgoValue: Self.percent(response.monthAgoSuccessRate),
            nowLabel: String(localized: "plainProgress.comparison.now"),
            nowValue: Self.percent(response.weekSuccessRate),
            deltaText: deltaText,
            monthAgoFraction: response.monthAgoSuccessRate,
            nowFraction: response.weekSuccessRate
        )
    }

    // MARK: - Milestones builder

    private func makeMilestones(
        _ response: PlainProgressModels.Load.Response
    ) -> [PlainProgressModels.Load.MilestoneViewModel] {
        PlainProgressTemplates.milestoneTitleKeys.map { item in
            let reached = Self.isMilestoneReached(id: item.id, response: response)
            let title = localized(item.key)
            let stateText = reached
                ? String(localized: "plainProgress.milestone.reached")
                : String(localized: "plainProgress.milestone.inProgress")
            return .init(
                id: item.id,
                title: title,
                symbolName: item.symbol,
                reached: reached,
                accessibilityLabel: "\(title). \(stateText)"
            )
        }
    }

    private static func isMilestoneReached(
        id: String,
        response: PlainProgressModels.Load.Response
    ) -> Bool {
        switch id {
        case "milestone-first-session":
            return response.sessionsThisWeek > 0 || response.currentStreak > 0
        case "milestone-week-streak":
            return response.currentStreak >= 7
        case "milestone-sound-stable":
            return response.focusSoundRate >= 0.8
        case "milestone-ten-sessions":
            return response.sessionsThisWeek >= 10
        case "milestone-high-accuracy":
            return response.weekSuccessRate >= 0.9
        default:
            return false
        }
    }

    // MARK: - Recommendation builder

    private func makeRecommendation(
        _ response: PlainProgressModels.Load.Response
    ) -> String {
        let key = PlainProgressTemplates.recommendationKey(
            for: response.trend,
            focusRate: response.focusSoundRate
        )
        return String(format: localized(key), response.focusSound)
    }

    // MARK: - Helpers

    private func localized(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }

    private static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private static func tint(for trend: PlainProgressDirection) -> TrendTint {
        switch trend {
        case .improved: return .positive
        case .steady:   return .neutral
        case .declined: return .attention
        case .noData:   return .neutral
        }
    }
}
