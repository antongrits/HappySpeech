import Charts
import SwiftUI

// MARK: - FluencyDiaryParentView
//
// Parent-only screen. Shows dysfluency trend chart and session history.
// Accessed via Parent Dashboard → «История речи» → «Дневник плавности».

struct FluencyDiaryParentView: View {

    @Environment(AppContainer.self) private var container
    @State private var sessions: [FluencySessionViewModel] = []
    @State private var chartData: [ChartPoint] = []
    @State private var isLoading: Bool = true
    private let normalThreshold: Float = 5.0

    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.sp6) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if sessions.isEmpty {
                    // BUG-012: Lyalya в empty state вместо SF Symbol book
                    VStack(spacing: SpacingTokens.sp4) {
                        LyalyaMascotView(state: .encouraging, size: 80)
                            .accessibilityHidden(true)
                        Text(String(localized: "fluency_diary.empty.title"))
                            .font(TypographyTokens.headline(18))
                            .foregroundStyle(ColorTokens.Parent.ink)
                            .multilineTextAlignment(.center)
                        Text(String(localized: "fluency_diary.empty.message"))
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, SpacingTokens.sp4)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "\(String(localized: "fluency_diary.empty.title")). \(String(localized: "fluency_diary.empty.message"))"
                    )
                } else {
                    chartSection
                    historySection
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.vertical, SpacingTokens.sp5)
        }
        .background(ColorTokens.Parent.bg.ignoresSafeArea())
        .navigationTitle(String(localized: "Дневник плавности"))
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.circuitContext, .parent)
        .task { await loadData() }
    }

    // MARK: - Chart

    private var chartSection: some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
                chartHeader
                diaryChart
                legendRow
            }
        }
    }

    private var chartHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(localized: "Спотыканий на 100 слогов"))
                .font(TypographyTokens.headline(17))
                .foregroundStyle(ColorTokens.Parent.ink)
            Text(String(localized: "За последние 4 недели"))
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
        }
    }

    private var diaryChart: some View {
        Chart {
            // Reference line at norm ≤5
            RuleMark(y: .value("Норма", 5))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .foregroundStyle(ColorTokens.Semantic.warning)
                .annotation(position: .trailing, alignment: .leading) {
                    Text(String(localized: "Норма ≤5"))
                        .font(TypographyTokens.caption(10))
                        .foregroundStyle(ColorTokens.Semantic.warning)
                }

            ForEach(chartData) { point in
                LineMark(
                    x: .value("Дата", point.date),
                    y: .value(String(localized: "stuttering.diary.metric.format"), Double(point.rate))
                )
                .foregroundStyle(ColorTokens.Brand.primary)
                .lineStyle(StrokeStyle(lineWidth: 2))

                PointMark(
                    x: .value("Дата", point.date),
                    y: .value(String(localized: "stuttering.diary.metric.format"), Double(point.rate))
                )
                .foregroundStyle(ColorTokens.Brand.primary)
                .symbolSize(36)
            }
        }
        .frame(height: 200)
        .chartYScale(domain: 0...max(30, (chartData.map(\.rate).max().map { Double($0) } ?? 30) + 5))
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisValueLabel(format: .dateTime.day().month())
                    .font(TypographyTokens.caption(10))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                AxisGridLine().foregroundStyle(ColorTokens.Parent.line.opacity(0.3))
            }
        }
        .chartYAxis {
            AxisMarks(values: [0, 5, 10, 20, 30]) { value in
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("\(v)")
                            .font(TypographyTokens.caption(10))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }
                }
                AxisGridLine().foregroundStyle(ColorTokens.Parent.line.opacity(0.3))
            }
        }
        .accessibilityLabel(String(localized: "График спотыканий по датам"))
    }

    private var legendRow: some View {
        HStack(spacing: SpacingTokens.sp4) {
            Label(
                String(localized: "stuttering.diary.metric.normal"),
                systemImage: "checkmark.circle.fill"
            )
            .font(TypographyTokens.caption(12))
            .foregroundStyle(ColorTokens.Semantic.success)

            Label(
                String(localized: "stuttering.diary.metric.elevated"),
                systemImage: "exclamationmark.circle.fill"
            )
            .font(TypographyTokens.caption(12))
            .foregroundStyle(ColorTokens.Semantic.warning)
        }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            Text(String(localized: "История сессий"))
                .font(TypographyTokens.headline(17))
                .foregroundStyle(ColorTokens.Parent.ink)

            ForEach(sessions) { session in
                DiarySessionRow(session: session)
            }
        }
    }

    // MARK: - Data loading

    private func loadData() async {
        isLoading = true
        let worker = DiaryStorageWorker(realmActor: container.realmActor)
        let rawSessions = await worker.fetchSessions(limit: 28)

        let calendar = Calendar.current
        let now = Date()
        let fourWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -4, to: now) ?? now

        let filtered = rawSessions.filter { $0.date >= fourWeeksAgo }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none

        sessions = rawSessions.map { data in
            let isNormal = data.rate <= normalThreshold
            return FluencySessionViewModel(
                id: data.id,
                dateText: dateFormatter.string(from: data.date),
                rateText: String(format: "%.1f", data.rate),
                isNormal: isNormal,
                statusSymbol: isNormal ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
            )
        }

        chartData = filtered.map { data in
            ChartPoint(date: data.date, rate: data.rate)
        }.sorted(by: { $0.date < $1.date })

        isLoading = false
    }
}

// MARK: - DiarySessionRow

private struct DiarySessionRow: View {
    let session: FluencySessionViewModel

    var body: some View {
        HSCard(style: .flat, padding: SpacingTokens.sp3) {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: session.statusSymbol)
                    .font(TypographyTokens.headline(20))
                    .foregroundStyle(
                        session.isNormal
                            ? ColorTokens.Semantic.success
                            : ColorTokens.Semantic.warning
                    )
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.dateText)
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Parent.ink)
                    Text(
                        session.isNormal
                            ? String(localized: "stuttering.diary.metric.normal")
                            : String(localized: "stuttering.diary.metric.elevated")
                    )
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                }

                Spacer()

                Text(String(format: String(localized: "stuttering.diary.metric.format"), Int(Float(session.rateText) ?? 0)))
                    .font(TypographyTokens.mono(13))
                    .foregroundStyle(
                        session.isNormal
                            ? ColorTokens.Semantic.success
                            : ColorTokens.Semantic.warning
                    )
            }
        }
        .environment(\.circuitContext, .parent)
    }
}

// MARK: - Preview

#Preview("FluencyDiaryParentView") {
    NavigationStack {
        FluencyDiaryParentView()
    }
    .environment(\.circuitContext, .parent)
}
