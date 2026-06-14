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
    @Environment(\.horizontalSizeClass) private var hSizeClass

    // Adaptive chart height: regular = 180/160, compact = 140/120.
    private var chartHeightLarge: CGFloat { hSizeClass == .regular ? 180 : 140 }
    private var chartHeightSmall: CGFloat { hSizeClass == .regular ? 160 : 120 }

    // MARK: - VIP

    @State private var viewModel = ComparisonDashboardViewModel()
    @State private var interactor: ComparisonDashboardInteractor?
    @State private var presenter: ComparisonDashboardPresenter?
    @State private var router: ComparisonDashboardRouter?

    // Snapshot-only: при `true` `.task`-bootstrap пропускается, чтобы
    // предзаготовленный `viewModel` не перетёрся async-загрузкой и снимок
    // ловил settled-кадр (graphs/empty), а не `ProgressView`.
    private let skipBootstrapForSnapshot: Bool

    // MARK: - Init

    init() {
        self.skipBootstrapForSnapshot = false
    }

    #if DEBUG
    /// Preview/snapshot-only init: инжектит уже-загруженный `viewModel` и
    /// отключает async-bootstrap, чтобы рендерить детерминированный settled-кадр
    /// (без `ProgressView`). Прод-путь (`init()`) не затрагивается.
    init(previewState viewModel: ComparisonDashboardViewModel) {
        self._viewModel = State(initialValue: viewModel)
        self.skipBootstrapForSnapshot = true
    }
    #endif

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()

                HSMeshGradientBackground(palette: .calm, animated: false)
                    .ignoresSafeArea()
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.hasData {
                    chartsContent
                } else {
                    emptyState
                }
            }
            // v32 P1 — Ляля празднует прогресс детей: corner-pin 56pt, topTrailing.
            .overlay(alignment: .topTrailing) {
                LyalyaMascotView(state: .celebrating, size: 56)
                    .padding(.top, SpacingTokens.regular)
                    .padding(.trailing, SpacingTokens.screenEdge)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
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
        .scrollBounceBehavior(.basedOnSize)
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
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.85)
                    }
                }
                Spacer(minLength: 0)
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
                .frame(height: chartHeightLarge)
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
                .frame(height: chartHeightLarge)
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
                                // v23 fix: Swift `%` для отрицательных возвращает
                                // отрицательный результат, поэтому intVal=0 → -1 →
                                // index out of range. Нормализуем через `(_ + 7) % 7`
                                // и страхуемся `indices.contains`.
                                let idx = ((intVal - 1) % 7 + 7) % 7
                                if dayNames.indices.contains(idx) {
                                    Text(dayNames[idx])
                                        .font(TypographyTokens.mono(10))
                                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                                }
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
                .frame(height: chartHeightSmall)
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
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)

                    HStack(spacing: SpacingTokens.sp3) {
                        Label("\(child.currentStreak) \(String(localized: "streak.days.short"))",
                              systemImage: "flame.fill")
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Brand.gold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Label("\(child.totalMinutes) \(String(localized: "minutes.short"))",
                              systemImage: "clock.fill")
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }

                Spacer(minLength: SpacingTokens.tiny)

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
        VStack(spacing: SpacingTokens.medium) {
            LyalyaMascotView(state: .thinking, size: 140)
                .accessibilityHidden(true)
            Text(String(localized: "comparison.empty.title"))
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Parent.ink)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
            Text(String(localized: "comparison.empty.message"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, SpacingTokens.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, SpacingTokens.screenEdge)
    }

    // MARK: - Helpers

    private func chartHeader(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(TypographyTokens.headline(15))
            .foregroundStyle(ColorTokens.Parent.ink)
    }

    // MARK: - VIP Bootstrap

    private func bootstrap() async {
        #if DEBUG
        if skipBootstrapForSnapshot { return }
        #endif
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

#if DEBUG
// MARK: Preview data

private extension ComparisonDashboardViewModel {
    /// Статичные данные для Preview/snapshot: два ребёнка, loaded-state, без
    /// async-bootstrap. Используется `init(previewState:)` — спиннер не
    /// отображается.
    static func previewLoaded() -> ComparisonDashboardViewModel {
        let vm = ComparisonDashboardViewModel()
        vm.isLoading = false
        vm.children = [
            ComparisonDashboard.ChildComparisonData(
                id: "c1",
                name: "Маша",
                colorTheme: "primary",
                avatarStyle: "fox",
                weeklySuccess: (1...7).map {
                    .init(weekLabel: "Нед. \($0)", weekIndex: $0,
                          successRate: min(1.0, 0.55 + 0.04 * Double($0 - 1)))
                },
                soundAccuracy: [
                    .init(sound: "С", accuracy: 0.82),
                    .init(sound: "Ш", accuracy: 0.66),
                    .init(sound: "Р", accuracy: 0.48),
                    .init(sound: "Л", accuracy: 0.74)
                ],
                dailyPracticeMinutes: zip(1...7, [8.0, 12, 6, 15, 10, 14, 9]).map {
                    .init(dayLabel: "Д\($0.0)", dayIndex: $0.0, minutes: $0.1)
                },
                currentStreak: 12,
                totalMinutes: 184
            ),
            ComparisonDashboard.ChildComparisonData(
                id: "c2",
                name: "Петя",
                colorTheme: "sky",
                avatarStyle: "bear",
                weeklySuccess: (1...7).map {
                    .init(weekLabel: "Нед. \($0)", weekIndex: $0,
                          successRate: min(1.0, 0.42 + 0.05 * Double($0 - 1)))
                },
                soundAccuracy: [
                    .init(sound: "С", accuracy: 0.70),
                    .init(sound: "Ш", accuracy: 0.55),
                    .init(sound: "Р", accuracy: 0.61),
                    .init(sound: "Л", accuracy: 0.58)
                ],
                dailyPracticeMinutes: zip(1...7, [5.0, 9, 11, 7, 13, 6, 12]).map {
                    .init(dayLabel: "Д\($0.0)", dayIndex: $0.0, minutes: $0.1)
                },
                currentStreak: 7,
                totalMinutes: 142
            )
        ]
        return vm
    }
}

#Preview("Comparison Dashboard — Loaded") {
    ComparisonDashboardView(previewState: .previewLoaded())
        .environment(AppContainer.preview())
        .environment(AppCoordinator())
}

#Preview("Comparison Dashboard — Dark") {
    ComparisonDashboardView(previewState: .previewLoaded())
        .environment(AppContainer.preview())
        .environment(AppCoordinator())
        .preferredColorScheme(.dark)
}
#endif
