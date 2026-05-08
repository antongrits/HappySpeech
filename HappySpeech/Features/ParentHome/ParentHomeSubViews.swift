import Charts
import SwiftUI

// MARK: - ParentHomeSubViews
//
// Вынесены из ParentHomeView.swift для соблюдения лимита 600 строк (SwiftLint file_length).
// Все структуры — internal (доступны внутри модуля), используются в ParentDashboardTab,
// ParentSessionsTab и ParentAnalyticsTab.

// MARK: - Sessions Tab

struct ParentSessionsTab: View {
    let sessions: [ParentHomeModels.SessionSummary]

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    HSEmptyState(
                        icon: "list.bullet.rectangle",
                        title: String(localized: "Занятий ещё не было"),
                        message: String(localized: "История занятий появится здесь после первого сеанса")
                    )
                } else {
                    List(sessions, id: \.id) { session in
                        SessionRow(session: session)
                            .listRowBackground(ColorTokens.Parent.surface)
                            .listRowSeparatorTint(ColorTokens.Parent.line)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(ColorTokens.Parent.bg)
                }
            }
            .navigationTitle(String(localized: "История занятий"))
        }
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: ParentHomeModels.SessionSummary

    var body: some View {
        HStack(spacing: SpacingTokens.sp3) {
            soundBadge
            infoStack
            Spacer()
            resultLabel
        }
        .padding(.vertical, SpacingTokens.sp2)
    }

    private var soundBadge: some View {
        ZStack {
            Circle()
                .fill(ColorTokens.Brand.primary.opacity(0.12))
                .frame(width: 44, height: 44)
            Text(session.targetSound)
                .font(TypographyTokens.kidDisplay(18))
                .foregroundStyle(ColorTokens.Brand.primary)
        }
    }

    private var infoStack: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(session.templateName)
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Parent.ink)
            HStack(spacing: SpacingTokens.sp2) {
                Text(session.dateText)
                Text("·")
                Text(session.durationText)
            }
            .font(TypographyTokens.caption())
            .foregroundStyle(ColorTokens.Parent.inkMuted)
            .lineLimit(2)
        }
    }

    private var resultLabel: some View {
        let color = session.successRate >= 0.7
            ? ColorTokens.Semantic.success
            : ColorTokens.Semantic.warning
        return Text(session.resultText)
            .font(TypographyTokens.mono(14))
            .foregroundStyle(color)
    }
}

// MARK: - Analytics Tab

struct ParentAnalyticsTab: View {
    let progress: [ParentHomeModels.SoundProgress]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SpacingTokens.sp5) {
                    if progress.isEmpty {
                        HSEmptyState(
                            icon: "chart.bar.xaxis",
                            title: String(localized: "Данных пока нет"),
                            message: String(localized: "Аналитика появится после первых занятий")
                        )
                        .frame(minHeight: 360)
                    } else {
                        SoundAccuracyChartCard(progress: progress)

                        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                            Text(String(localized: "По звукам"))
                                .font(TypographyTokens.headline(17))
                                .foregroundStyle(ColorTokens.Parent.ink)
                                .padding(.horizontal, SpacingTokens.sp1)

                            ForEach(progress, id: \.sound) { item in
                                SoundProgressCard(item: item)
                            }
                        }
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.vertical, SpacingTokens.sp5)
            }
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
            .navigationTitle(String(localized: "Аналитика"))
        }
    }
}

// MARK: - Sound Accuracy Chart (Swift Charts)

/// Bar chart of average accuracy per target sound.
/// Uses Swift Charts (`Chart` / `BarMark`) — iOS 16+. Tinted to the parent
/// circuit accent. Bars are sorted in the same order as the cards below for
/// visual continuity.
struct SoundAccuracyChartCard: View {
    let progress: [ParentHomeModels.SoundProgress]

    private var chartData: [ChartPoint] {
        progress.map { item in
            ChartPoint(
                sound: item.sound,
                accuracy: item.overallRate,
                tint: Self.tint(for: item.overallRate)
            )
        }
    }

    private var averageAccuracy: Double {
        guard !progress.isEmpty else { return 0 }
        let sum = progress.map(\.overallRate).reduce(0, +)
        return sum / Double(progress.count)
    }

    var body: some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
                header

                Chart(chartData) { point in
                    BarMark(
                        x: .value(String(localized: "Звук"), point.sound),
                        y: .value(String(localized: "Точность"), point.accuracy * 100)
                    )
                    .foregroundStyle(point.tint)
                    .cornerRadius(6)
                    .annotation(position: .top, alignment: .center, spacing: 4) {
                        Text("\(Int(point.accuracy * 100))%")
                            .font(TypographyTokens.caption(11))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }
                }
                .frame(height: 200)
                .chartYScale(domain: 0...110)
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine().foregroundStyle(ColorTokens.Parent.line.opacity(0.4))
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)%")
                                    .font(TypographyTokens.caption(11))
                                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel()
                            .font(TypographyTokens.caption(11).bold())
                            .foregroundStyle(ColorTokens.Parent.ink)
                    }
                }
                .accessibilityLabel(String(localized: "Диаграмма точности по звукам"))
                .accessibilityValue(
                    chartData
                        .map { "\($0.sound): \(Int($0.accuracy * 100))%" }
                        .joined(separator: ", ")
                )

                averageRow
            }
        }
        .environment(\.circuitContext, .parent)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Точность по звукам"))
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Parent.ink)
                Text(String(localized: "За последние 30 дней"))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
            }
            Spacer()
            Image(systemName: "chart.bar.fill")
                .foregroundStyle(ColorTokens.Parent.accent)
        }
    }

    private var averageRow: some View {
        HStack(spacing: SpacingTokens.sp2) {
            Image(systemName: "checkmark.seal.fill")
                .font(TypographyTokens.caption(14))
                .foregroundStyle(ColorTokens.Semantic.success)
            Text(String(localized: "Средняя точность: \(Int(averageAccuracy * 100))%"))
                .font(TypographyTokens.body(13))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .layoutPriority(1)
            Spacer(minLength: 4)
        }
        .padding(.top, SpacingTokens.sp1)
    }

    /// Bar tint by accuracy band — green >= 80%, gold 60–79%, warning < 60%.
    static func tint(for rate: Double) -> Color {
        if rate >= 0.80 {
            return ColorTokens.Semantic.success
        } else if rate >= 0.60 {
            return ColorTokens.Brand.gold
        } else {
            return ColorTokens.Semantic.warning
        }
    }

    struct ChartPoint: Identifiable, Sendable {
        let id = UUID()
        let sound: String
        let accuracy: Double
        let tint: Color
    }
}

// MARK: - Sound Progress Card

struct SoundProgressCard: View {
    let item: ParentHomeModels.SoundProgress

    var body: some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                HStack {
                    Text(item.sound)
                        .font(TypographyTokens.kidDisplay(28))
                        .foregroundStyle(ColorTokens.Brand.primary)

                    VStack(alignment: .leading) {
                        Text(item.familyName)
                            .font(TypographyTokens.body(13))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                        Text(item.currentStage)
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Parent.ink)
                    }

                    Spacer()

                    Text("\(Int(item.overallRate * 100))%")
                        .font(TypographyTokens.headline(22))
                        .foregroundStyle(ColorTokens.Parent.accent)
                }

                HSProgressBar(value: item.overallRate, style: .parent, tint: ColorTokens.Parent.accent)
            }
        }
        .environment(\.circuitContext, .parent)
    }
}

// MARK: - Stat Card

struct ParentStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HSLiquidGlassCard(style: .tinted(color), padding: SpacingTokens.sp4) {
            VStack(spacing: SpacingTokens.sp2) {
                Image(systemName: icon)
                    .font(TypographyTokens.titleSmall(20))
                    .foregroundStyle(color)

                Text(value)
                    .font(TypographyTokens.kidDisplay(20))
                    .foregroundStyle(ColorTokens.Parent.ink)

                Text(label)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .ctaTextStyle()
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
