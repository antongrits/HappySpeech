import Charts
import SwiftUI

// MARK: - ProgressDashboardViewDetail
//
// Детальный экран прогресса по звуку для `ProgressDashboardView`.

// MARK: - SoundProgressDetailView

struct SoundProgressDetailView: View {

    let detail: SoundDetailViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sectionGap) {
                headerCard
                historyChart
                metricsRow
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.vertical, SpacingTokens.large)
        }
        .background(ColorTokens.Parent.bg.ignoresSafeArea())
        .navigationTitle(detail.title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
    }

    private var headerCard: some View {
        HSLiquidGlassCard(style: .elevated) {
            HStack(alignment: .top, spacing: SpacingTokens.regular) {
                Text(detail.sound)
                    .font(TypographyTokens.display(48))
                    .foregroundStyle(ColorTokens.Brand.primary)

                VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                    Text(detail.title)
                        .font(TypographyTokens.headline(18))
                        .foregroundStyle(ColorTokens.Parent.ink)
                    Text(detail.trendDescription)
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                }

                Spacer()

                Text("\(detail.accuracyPercent)%")
                    .font(TypographyTokens.display(36))
                    .foregroundStyle(ColorTokens.Semantic.success)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(detail.accessibilityLabel)
    }

    private var historyChart: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.regular) {
            Text(String(localized: "progressDashboard.detail.historyTitle"))
                .font(TypographyTokens.title(20))
                .foregroundStyle(ColorTokens.Parent.ink)

            HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.regular) {
                Chart(detail.history) { point in
                    LineMark(
                        x: .value(String(localized: "progressDashboard.chart.day"), point.day),
                        y: .value(String(localized: "progressDashboard.chart.accuracy"), point.value)
                    )
                    .foregroundStyle(ColorTokens.Parent.accent)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                    .symbol(.circle)
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)%")
                                    .font(TypographyTokens.caption(11))
                                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                            }
                        }
                        AxisGridLine()
                            .foregroundStyle(ColorTokens.Parent.line.opacity(0.5))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel()
                            .font(TypographyTokens.caption(11))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }
                }
                .frame(height: 180)
            }
        }
    }

    private var metricsRow: some View {
        HStack(spacing: SpacingTokens.regular) {
            DetailMetric(
                title: String(localized: "progressDashboard.detail.metric.accuracy"),
                value: "\(detail.accuracyPercent)%",
                color: ColorTokens.Semantic.success
            )
            DetailMetric(
                title: String(localized: "progressDashboard.detail.metric.sessions"),
                value: "\(detail.sessionsCount)",
                color: ColorTokens.Parent.accent
            )
        }
    }
}

// MARK: - DetailMetric

struct DetailMetric: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HSLiquidGlassCard(style: .primary, padding: SpacingTokens.regular) {
            VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                Text(title)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                Text(value)
                    .font(TypographyTokens.headline(20))
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}
