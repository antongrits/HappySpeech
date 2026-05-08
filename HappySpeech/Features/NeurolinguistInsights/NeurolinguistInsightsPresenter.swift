import Foundation
import OSLog

// MARK: - NeurolinguistInsightsPresenter
//
// Преобразует Insight + Metrics в готовый InsightCard и набор MetricChip.

@MainActor
final class NeurolinguistInsightsPresenter {

    weak var viewModel: NeurolinguistInsightsViewModel?

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "d MMMM, HH:mm"
        return df
    }()

    // MARK: - Load

    func presentLoad(_ response: NeurolinguistInsights.LoadResponse) {
        let insight = response.insight
        let metrics = response.metricsSnapshot

        let card = NeurolinguistInsights.InsightCard(
            title: String(localized: "insights.card.title"),
            summaryMarkdown: insight.summaryText,
            trendBadge: trendBadgeText(insight.trendLabel),
            trendColorToken: trendColorToken(insight.trendLabel),
            recommendation: insight.recommendation,
            primaryFocus: insight.primarySoundFocus,
            generatedAtText: dateFormatter.string(from: insight.generatedAt)
        )

        let chips = makeChips(metrics: metrics)

        viewModel?.card = card
        viewModel?.metricChips = chips
        viewModel?.metricsSnapshot = metrics
        viewModel?.state = metrics.sessionsCount == 0 ? .empty : .ready
        viewModel?.errorMessage = nil
    }

    func presentError(_ message: String) {
        viewModel?.state = .error(message)
        viewModel?.errorMessage = message
    }

    // MARK: - Helpers

    private func trendBadgeText(_ rawLabel: String) -> String {
        switch rawLabel {
        case NeurolinguistInsights.TrendKind.improving.rawValue:
            return String(localized: "insights.trend.improving")
        case NeurolinguistInsights.TrendKind.declining.rawValue:
            return String(localized: "insights.trend.declining")
        case NeurolinguistInsights.TrendKind.stable.rawValue:
            return String(localized: "insights.trend.stable")
        default:
            return String(localized: "insights.trend.no_data")
        }
    }

    private func trendColorToken(_ rawLabel: String) -> String {
        switch rawLabel {
        case NeurolinguistInsights.TrendKind.improving.rawValue: return "success"
        case NeurolinguistInsights.TrendKind.declining.rawValue: return "warning"
        case NeurolinguistInsights.TrendKind.stable.rawValue:    return "info"
        default: return "neutral"
        }
    }

    private func makeChips(metrics: NeurolinguistInsights.MetricsSnapshot) -> [NeurolinguistInsights.MetricChip] {
        let accuracyPct = Int((metrics.averageAccuracy * 100).rounded())

        var chips: [NeurolinguistInsights.MetricChip] = [
            NeurolinguistInsights.MetricChip(
                label: String(localized: "insights.chip.sessions"),
                value: "\(metrics.sessionsCount)",
                icon: "play.circle.fill",
                colorToken: "primary"
            ),
            NeurolinguistInsights.MetricChip(
                label: String(localized: "insights.chip.accuracy"),
                value: "\(accuracyPct)%",
                icon: "target",
                colorToken: accuracyPct >= 70 ? "success" : "warning"
            ),
            NeurolinguistInsights.MetricChip(
                label: String(localized: "insights.chip.minutes"),
                value: "\(metrics.totalMinutes)",
                icon: "clock.fill",
                colorToken: "info"
            ),
            NeurolinguistInsights.MetricChip(
                label: String(localized: "insights.chip.streak"),
                value: "\(metrics.consecutiveDays)",
                icon: "flame.fill",
                colorToken: metrics.consecutiveDays > 0 ? "warning" : "neutral"
            )
        ]

        if let best = metrics.bestSound {
            chips.append(NeurolinguistInsights.MetricChip(
                label: String(localized: "insights.chip.best_sound"),
                value: best,
                icon: "star.fill",
                colorToken: "success"
            ))
        }
        if let challenge = metrics.challengingSound,
           challenge != metrics.bestSound {
            chips.append(NeurolinguistInsights.MetricChip(
                label: String(localized: "insights.chip.challenge"),
                value: challenge,
                icon: "exclamationmark.triangle.fill",
                colorToken: "warning"
            ))
        }
        return chips
    }
}

// MARK: - NeurolinguistInsightsViewModel

@Observable
@MainActor
final class NeurolinguistInsightsViewModel {
    var state: NeurolinguistInsights.ScreenState = .loading
    var card: NeurolinguistInsights.InsightCard?
    var metricChips: [NeurolinguistInsights.MetricChip] = []
    var metricsSnapshot: NeurolinguistInsights.MetricsSnapshot?
    var errorMessage: String?
    var isRefreshing: Bool = false
}
