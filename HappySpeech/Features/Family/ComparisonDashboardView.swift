import Charts
import SwiftUI

// MARK: - ComparisonDashboardView
//
// Parent-circuit. Показывает Swift Charts сравнение 2–3 детей:
// 1. Линейный график успешности по неделям
// 2. Grouped bar chart точности по звукам
// 3. Stacked area chart времени практики в день
//
// VIP: View → Interactor → Presenter → ViewModel (@Observable).

struct ComparisonDashboardView: View {

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - VIP

    @State private var viewModel = ComparisonDashboardViewModel()
    @State private var interactor: ComparisonDashboardInteractor?
    @State private var presenter: ComparisonDashboardPresenter?
    @State private var router: ComparisonDashboardRouter?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.hasData {
                    chartsContent
                } else {
                    emptyState
                }
            }
            .navigationTitle(String(localized: "comparison.title"))
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await bootstrap() }
    }

    // MARK: - Charts Content

    private var chartsContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpacingTokens.sectionGap) {
                // Legend
                legendSection

                // Chart 1: Weekly success rate
                weeklySuccessChart

                // Chart 2: Sound accuracy comparison
                soundAccuracyChart

                // Chart 3: Practice time per day
                practiceTimeChart

                // Summary cards per child
                summaryCardsSection
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp8)
        }
        .refreshable { await refresh() }
    }

    // MARK: - Legend

    private var legendSection: some View {
        HSLiquidGlassCard(style: .primary) {
            HStack(spacing: SpacingTokens.sp4) {
                ForEach(viewModel.children) { child in
                    HStack(spacing: SpacingTokens.sp2) {
                        Circle()
                            .fill(viewModel.chartColor(for: child.id))
                            .frame(width: 10, height: 10)
                        Text(child.name)
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(ColorTokens.Parent.ink)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: - Chart 1: Weekly Success

    private var weeklySuccessChart: some View {
        HSLiquidGlassCard(style: .primary) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
                chartHeader(
                    title: String(localized: "comparison.success_per_week"),
                    icon: "chart.line.uptrend.xyaxis"
                )

                Chart {
                    ForEach(viewModel.children) { child in
                        ForEach(child.weeklySuccess) { point in
                            LineMark(
                                x: .value(String(localized: "comparison.week"), point.weekIndex),
                                y: .value(String(localized: "comparison.success"), point.successRate * 100)
                            )
                            .foregroundStyle(viewModel.chartColor(for: child.id))
                            .symbol {
                                Circle()
                                    .fill(viewModel.chartColor(for: child.id))
                                    .frame(width: 6, height: 6)
                            }
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .foregroundStyle(by: .value(String(localized: "comparison.child"), child.name))
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 7)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(ColorTokens.Parent.line)
                        AxisValueLabel {
                            if let intVal = value.as(Int.self) {
                                Text("\(intVal)")
                                    .font(TypographyTokens.mono(10))
                                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(ColorTokens.Parent.line)
                        AxisValueLabel {
                            if let intVal = value.as(Int.self) {
                                Text("\(intVal)%")
                                    .font(TypographyTokens.mono(10))
                                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...100)
                .chartLegend(.hidden)
                .frame(height: 180)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: viewModel.children.count)
                .accessibilityLabel(String(localized: "comparison.success_per_week"))
                .accessibilityHidden(false)
            }
        }
    }

    // MARK: - Chart 2: Sound Accuracy

    private var soundAccuracyChart: some View {
        HSLiquidGlassCard(style: .primary) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
                chartHeader(
                    title: String(localized: "comparison.per_sound"),
                    icon: "waveform"
                )

                Chart {
                    ForEach(viewModel.children) { child in
                        ForEach(child.soundAccuracy) { point in
                            BarMark(
                                x: .value(String(localized: "comparison.sound"), point.sound),
                                y: .value(String(localized: "comparison.accuracy"), point.accuracy * 100)
                            )
                            .foregroundStyle(viewModel.chartColor(for: child.id))
                            .foregroundStyle(by: .value(String(localized: "comparison.child"), child.name))
                            .position(by: .value(String(localized: "comparison.child"), child.name))
                            .cornerRadius(3)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(TypographyTokens.mono(11))
                                    .foregroundStyle(ColorTokens.Parent.ink)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 50, 100]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(ColorTokens.Parent.line)
                        AxisValueLabel {
                            if let intVal = value.as(Int.self) {
                                Text("\(intVal)%")
                                    .font(TypographyTokens.mono(10))
                                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...100)
                .chartLegend(.hidden)
                .frame(height: 180)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: viewModel.children.count)
                .accessibilityLabel(String(localized: "comparison.per_sound"))
            }
        }
    }

    // MARK: - Chart 3: Practice Time

    private var practiceTimeChart: some View {
        HSLiquidGlassCard(style: .primary) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
                chartHeader(
                    title: String(localized: "comparison.practice_time"),
                    icon: "clock.fill"
                )

                Chart {
                    ForEach(viewModel.children) { child in
                        ForEach(child.dailyPracticeMinutes) { point in
                            AreaMark(
                                x: .value(String(localized: "comparison.day"), point.dayIndex),
                                y: .value(String(localized: "comparison.minutes"), point.minutes)
                            )
                            .foregroundStyle(
                                viewModel.chartColor(for: child.id).opacity(0.3)
                            )
                            .foregroundStyle(by: .value(String(localized: "comparison.child"), child.name))

                            LineMark(
                                x: .value(String(localized: "comparison.day"), point.dayIndex),
                                y: .value(String(localized: "comparison.minutes"), point.minutes)
                            )
                            .foregroundStyle(viewModel.chartColor(for: child.id))
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                            .foregroundStyle(by: .value(String(localized: "comparison.child"), child.name))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let intVal = value.as(Int.self) {
                                let dayNames = [
                                    String(localized: "day.mon"), String(localized: "day.tue"),
                                    String(localized: "day.wed"), String(localized: "day.thu"),
                                    String(localized: "day.fri"), String(localized: "day.sat"),
                                    String(localized: "day.sun")
                                ]
                                let idx = (intVal - 1) % 7
                                Text(dayNames[idx])
                                    .font(TypographyTokens.mono(10))
                                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(ColorTokens.Parent.line)
                        AxisValueLabel {
                            if let doubleVal = value.as(Double.self) {
                                Text(String(format: "%.0f мин", doubleVal))
                                    .font(TypographyTokens.mono(10))
                                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                            }
                        }
                    }
                }
                .chartLegend(.hidden)
                .frame(height: 160)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: viewModel.children.count)
                .accessibilityLabel(String(localized: "comparison.practice_time"))
            }
        }
    }

    // MARK: - Summary Cards

    private var summaryCardsSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ForEach(viewModel.children) { child in
                childSummaryCard(child)
            }
        }
    }

    private func childSummaryCard(_ child: ComparisonDashboard.ChildComparisonData) -> some View {
        HSLiquidGlassCard(style: .tinted(viewModel.chartColor(for: child.id))) {
            HStack(spacing: SpacingTokens.sp4) {
                VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                    Text(child.name)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Parent.ink)

                    HStack(spacing: SpacingTokens.sp3) {
                        Label("\(child.currentStreak) \(String(localized: "streak.days.short"))",
                              systemImage: "flame.fill")
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(.orange)

                        Label("\(child.totalMinutes) \(String(localized: "minutes.short"))",
                              systemImage: "clock.fill")
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }
                }

                Spacer()

                Circle()
                    .fill(viewModel.chartColor(for: child.id))
                    .frame(width: 12, height: 12)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(buildSummaryA11yLabel(child))
    }

    private func buildSummaryA11yLabel(_ child: ComparisonDashboard.ChildComparisonData) -> String {
        let streakStr = String(localized: "streak.days.short")
        let minutesStr = String(localized: "minutes.short")
        return "\(child.name), \(child.currentStreak) \(streakStr), \(child.totalMinutes) \(minutesStr)"
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HSEmptyState(
            icon: "chart.xyaxis.line",
            title: String(localized: "comparison.empty.title"),
            message: String(localized: "comparison.empty.message"),
            actionTitle: nil
        ) {}
    }

    // MARK: - Helpers

    private func chartHeader(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(TypographyTokens.headline(15))
            .foregroundStyle(ColorTokens.Parent.ink)
    }

    // MARK: - VIP Bootstrap

    private func bootstrap() async {
        if interactor == nil {
            let presenter = ComparisonDashboardPresenter()
            let interactor = ComparisonDashboardInteractor(
                childRepository: container.childRepository,
                sessionRepository: container.sessionRepository
            )
            let router = ComparisonDashboardRouter(coordinator: coordinator)
            presenter.viewModel = viewModel
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = router
        }
        await refresh()
    }

    private func refresh() async {
        await interactor?.load(ComparisonDashboard.LoadRequest(childIds: []))
    }
}

// MARK: - Preview

#Preview("Comparison Dashboard") {
    ComparisonDashboardView()
        .environment(AppContainer.preview())
        .environment(AppCoordinator())
}
