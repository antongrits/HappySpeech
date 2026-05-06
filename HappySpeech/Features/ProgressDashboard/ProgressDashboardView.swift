import Charts
import OSLog
import SwiftUI

// MARK: - ProgressDashboardView
//
// Parent-контур. Дашборд прогресса ребёнка: 4 summary-карточки, bar chart
// (success rate за 7 дней), line chart (точность по 4 неделям), AI-сводка
// от LLM (с фолбэком на статичный текст), грид звуков 2 колонки с трендами.
//
// VIP: View → Interactor (запросы) → Presenter (форматирование) → Display.

struct ProgressDashboardView: View {

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - VIP State

    @State private var display = ProgressDashboardDisplay()
    @State private var interactor: ProgressDashboardInteractor?
    @State private var presenter: ProgressDashboardPresenter?
    @State private var router: ProgressDashboardRouter?
    @State private var bootstrapped = false

    // MARK: - Local UI

    @State private var path: [SoundDetailRoute] = []

    private let childId: String
    private let logger = Logger(subsystem: "ru.happyspeech", category: "ProgressDashboardView")

    // MARK: - Init

    init(childId: String = "child-default") {
        self.childId = childId
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottom) {
                ColorTokens.Parent.bg.ignoresSafeArea()

                content
                    .refreshable { performRefresh() }

                if let toast = display.toastMessage {
                    HSToast(toast, type: .error)
                        .padding(.bottom, SpacingTokens.large)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task {
                            try? await Task.sleep(for: .seconds(2.4))
                            withAnimation(.easeInOut(duration: 0.25)) {
                                display.clearToast()
                            }
                        }
                }
            }
            .navigationTitle(String(localized: "progressDashboard.navTitle"))
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: SoundDetailRoute.self) { route in
                SoundProgressDetailView(detail: route.detail)
            }
        }
        .environment(\.circuitContext, .parent)
        .task { await bootstrap() }
        .onChange(of: display.pendingSoundDetail) { _, newDetail in
            guard let detail = newDetail else { return }
            path.append(SoundDetailRoute(detail: detail))
            display.consumePendingDetail()
        }
    }

    // MARK: - Content switch

    @ViewBuilder
    private var content: some View {
        if display.isLoading && display.summaryCards.isEmpty {
            HSLoadingView(message: String(localized: "progressDashboard.loading"))
        } else if display.isEmpty {
            emptyStateView
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.sectionGap) {
                    periodPickerSection
                    summaryCardsRow
                    dailyChartSection
                    weeklyChartSection
                    highlightsSection
                    insightsSectionView
                    llmSummarySection
                    recommendationsSection
                    soundsGridSection
                }
                .padding(.vertical, SpacingTokens.large)
                .padding(.bottom, SpacingTokens.xLarge)
            }
        }
    }

    // MARK: - Period picker

    private var periodPickerSection: some View {
        HSLiquidGlassCard(style: .primary, padding: SpacingTokens.tiny) {
            HStack(spacing: SpacingTokens.tiny) {
                ForEach(display.periodOptions) { option in
                    PeriodChipView(option: option) {
                        handlePeriodChange(option.period)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Highlights (top performers / needs work)

    @ViewBuilder
    private var highlightsSection: some View {
        if !display.topPerformers.isEmpty || !display.needsWork.isEmpty {
            VStack(alignment: .leading, spacing: SpacingTokens.regular) {
                sectionHeader(
                    title: String(localized: "progressDashboard.section.highlights"),
                    subtitle: String(localized: "progressDashboard.section.highlights.subtitle")
                )

                VStack(alignment: .leading, spacing: SpacingTokens.regular) {
                    if !display.topPerformers.isEmpty {
                        highlightsCard(
                            title: String(localized: "progressDashboard.top"),
                            iconName: "star.fill",
                            iconTint: ColorTokens.Semantic.success,
                            chips: display.topPerformers
                        )
                    }
                    if !display.needsWork.isEmpty {
                        highlightsCard(
                            title: String(localized: "progressDashboard.work"),
                            iconName: "exclamationmark.triangle.fill",
                            iconTint: ColorTokens.Semantic.warning,
                            chips: display.needsWork
                        )
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
            }
        }
    }

    @ViewBuilder
    private func highlightsCard(
        title: String,
        iconName: String,
        iconTint: Color,
        chips: [SoundChipViewModel]
    ) -> some View {
        HSLiquidGlassCard(style: .tinted(iconTint), padding: SpacingTokens.cardPad) {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                HStack(spacing: SpacingTokens.tiny) {
                    Image(systemName: iconName)
                        .font(TypographyTokens.labelRounded(14))
                        .foregroundStyle(iconTint)
                        .accessibilityHidden(true)
                    Text(title)
                        .font(TypographyTokens.headline(15))
                        .foregroundStyle(ColorTokens.Parent.ink)
                }

                FlowChipsRow(chips: chips)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Insights

    @ViewBuilder
    private var insightsSectionView: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.regular) {
            sectionHeader(
                title: String(localized: "dashboard.insights.title"),
                subtitle: nil
            )

            if display.isInsightsLoading {
                HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.cardPad) {
                    Text(String(localized: "dashboard.insights.loading"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
            } else if display.insightCards.isEmpty {
                HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.cardPad) {
                    Text(String(localized: "dashboard.insights.empty"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
            } else {
                VStack(alignment: .leading, spacing: SpacingTokens.small) {
                    ForEach(display.insightCards) { card in
                        ParentInsightCard(card: card)
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
            }
        }
    }

    // MARK: - Recommendations

    @ViewBuilder
    private var recommendationsSection: some View {
        if !display.recommendations.isEmpty {
            VStack(alignment: .leading, spacing: SpacingTokens.regular) {
                sectionHeader(
                    title: String(localized: "progressDashboard.recommendations.title"),
                    subtitle: String(localized: "progressDashboard.recommendations.subtitle")
                )

                HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.cardPad) {
                    VStack(alignment: .leading, spacing: SpacingTokens.regular) {
                        ForEach(display.recommendations) { item in
                            RecommendationRowView(item: item)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
            }
        }
    }

    // MARK: - Summary cards (horizontal scroll)

    private var summaryCardsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.regular) {
                ForEach(display.summaryCards) { card in
                    SummaryCardView(card: card)
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
    }

    // MARK: - Daily chart

    private var dailyChartSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.regular) {
            sectionHeader(
                title: String(localized: "progressDashboard.section.weekly"),
                subtitle: String(localized: "progressDashboard.section.weekly.subtitle")
            )

            HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.regular) {
                Chart(display.dailyChart) { point in
                    BarMark(
                        x: .value(String(localized: "progressDashboard.chart.day"), point.day),
                        y: .value(String(localized: "progressDashboard.chart.accuracy"), point.value)
                    )
                    .foregroundStyle(barColor(for: point.value))
                    .cornerRadius(6)
                    .annotation(position: .top, alignment: .center, spacing: 2) {
                        Text("\(Int(point.value))")
                            .font(TypographyTokens.mono(10))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                            .accessibilityHidden(true)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)%")
                                    .font(TypographyTokens.caption(12))
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
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }
                }
                .frame(height: 180)
                .accessibilityLabel(String(localized: "progressDashboard.a11y.dailyChart"))
                .accessibilityValue(dailyChartAccessibilityValue)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
    }

    private var dailyChartAccessibilityValue: String {
        display.dailyChart
            .map { "\($0.day): \(Int($0.value))%" }
            .joined(separator: ", ")
    }

    // MARK: - Weekly chart

    private var weeklyChartSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.regular) {
            sectionHeader(
                title: String(localized: "progressDashboard.section.monthly"),
                subtitle: String(localized: "progressDashboard.section.monthly.subtitle")
            )

            HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.regular) {
                Chart(display.weeklyChart) { point in
                    LineMark(
                        x: .value(String(localized: "progressDashboard.chart.week"), point.label),
                        y: .value(String(localized: "progressDashboard.chart.accuracy"), point.value)
                    )
                    .foregroundStyle(ColorTokens.Parent.accent)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                    .symbol(.circle)

                    AreaMark(
                        x: .value(String(localized: "progressDashboard.chart.week"), point.label),
                        y: .value(String(localized: "progressDashboard.chart.accuracy"), point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                ColorTokens.Parent.accent.opacity(0.18),
                                ColorTokens.Parent.accent.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)%")
                                    .font(TypographyTokens.caption(12))
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
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }
                }
                .frame(height: 180)
                .accessibilityLabel(String(localized: "progressDashboard.a11y.weeklyChart"))
                .accessibilityValue(weeklyChartAccessibilityValue)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
    }

    private var weeklyChartAccessibilityValue: String {
        display.weeklyChart
            .map { "\($0.label): \(Int($0.value))%" }
            .joined(separator: ", ")
    }

    // MARK: - LLM Summary

    private var llmSummarySection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.regular) {
            sectionHeader(
                title: String(localized: "progressDashboard.section.recommendation"),
                subtitle: nil
            )

            HSLiquidGlassCard(style: .tinted(ColorTokens.Brand.lilac), padding: SpacingTokens.cardPad) {
                HStack(alignment: .top, spacing: SpacingTokens.regular) {
                    ZStack {
                        Circle()
                            .fill(ColorTokens.Brand.lilac.opacity(0.18))
                            .frame(width: 40, height: 40)
                        Image(systemName: "sparkles")
                            .font(TypographyTokens.subtitle(18))
                            .foregroundStyle(ColorTokens.Brand.lilac)
                            .symbolEffect(.pulse, options: .repeating, isActive: display.isLLMLoading && !reduceMotion)
                    }

                    VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                        if let summary = display.llmSummary {
                            Text(summary.title)
                                .font(TypographyTokens.headline(17))
                                .foregroundStyle(ColorTokens.Parent.ink)
                            Text(summary.bodyText)
                                .font(TypographyTokens.body(15))
                                .foregroundStyle(ColorTokens.Parent.inkMuted)
                                .lineSpacing(TypographyTokens.LineSpacing.normal)
                                .lineLimit(nil)
                                .accessibilityLabel(summary.accessibilityLabel)
                            if summary.isFallback {
                                Text(String(localized: "progressDashboard.llm.fallbackBadge"))
                                    .font(TypographyTokens.caption(11))
                                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                            }
                        } else {
                            Text(String(localized: "progressDashboard.llm.loading"))
                                .font(TypographyTokens.body(14))
                                .foregroundStyle(ColorTokens.Parent.inkMuted)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
    }

    // MARK: - Sounds grid

    private var soundsGridSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.regular) {
            sectionHeader(
                title: String(localized: "progressDashboard.section.sounds"),
                subtitle: String(localized: "progressDashboard.section.sounds.subtitle")
            )

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: SpacingTokens.regular),
                    GridItem(.flexible(), spacing: SpacingTokens.regular)
                ],
                spacing: SpacingTokens.regular
            ) {
                ForEach(display.soundCells) { cell in
                    Button {
                        handleOpenSound(cell.sound)
                    } label: {
                        SoundProgressCellView(cell: cell)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer(minLength: SpacingTokens.xLarge)

            Text(verbatim: "📊")
                .font(TypographyTokens.kidDisplay(96)) // emoji key graphic — skip TypographyTokens
                .accessibilityHidden(true)

            VStack(spacing: SpacingTokens.small) {
                Text(display.emptyTitle)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)

                Text(display.emptyMessage)
                    .font(TypographyTokens.body())
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, SpacingTokens.large)
            }

            HSButton(
                String(localized: "progressDashboard.empty.cta"),
                style: .primary,
                size: .medium,
                icon: "play.fill"
            ) {
                container.hapticService.impact(.medium)
                logger.info("emptyState start lesson tapped")
            }
            .frame(maxWidth: 280)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(display.emptyTitle). \(display.emptyMessage)")
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionHeader(title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.micro) {
            Text(title)
                .font(TypographyTokens.title(20))
                .foregroundStyle(ColorTokens.Parent.ink)
            if let subtitle {
                Text(subtitle)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func barColor(for value: Double) -> Color {
        if value >= 70 { return ColorTokens.Semantic.success }
        if value >= 50 { return ColorTokens.Semantic.warning }
        return ColorTokens.Semantic.error
    }

    // MARK: - Actions

    private func handleOpenSound(_ sound: String) {
        container.hapticService.selection()
        logger.info("openSound \(sound, privacy: .public)")
        interactor?.loadSoundDetail(.init(sound: sound))
    }

    private func handlePeriodChange(_ period: ProgressDashboardModels.TimePeriod) {
        guard period != display.selectedPeriod else { return }
        container.hapticService.selection()
        logger.info("changePeriod \(period.rawValue, privacy: .public)")
        interactor?.changePeriod(.init(childId: childId, period: period))
    }

    private func performRefresh() {
        container.hapticService.impact(.light)
        interactor?.loadDashboard(.init(
            childId: childId,
            forceReload: true,
            period: display.selectedPeriod
        ))
        requestLLMSummary()
        requestInsights()
    }

    private func requestInsights() {
        let sounds = display.soundCells.map { cell in
            SoundProgress(
                sound: cell.sound,
                accuracy: Float(cell.accuracyValue / 100.0),
                sessions: 0,
                trend: cell.trend
            )
        }
        let streak = display.summaryCards.first(where: { $0.kind == .streak })
            .flatMap { Int($0.value) } ?? 0
        interactor?.loadInsights(.init(
            childName: container.themeManager.selectedTheme.displayName,
            sounds: sounds,
            streakDays: streak
        ))
    }

    private func requestLLMSummary() {
        let summaryDomain = DashboardSummary(
            overallAccuracy: 0.78,
            streakDays: 5,
            totalMinutes: 127,
            totalStars: 24
        )
        let topSound = display.soundCells.first.map { cell in
            SoundProgress(
                sound: cell.sound,
                accuracy: Float(cell.accuracyValue / 100.0),
                sessions: 0,
                trend: cell.trend
            )
        }
        interactor?.requestLLMSummary(.init(
            childName: container.themeManager.selectedTheme.displayName,
            summary: summaryDomain,
            topSound: topSound
        ))
    }

    // MARK: - Bootstrap

    @MainActor
    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        let interactor = ProgressDashboardInteractor(
            llmDecisionService: container.llmDecisionService
        )
        let presenter = ProgressDashboardPresenter()
        let router = ProgressDashboardRouter()

        interactor.presenter = presenter
        presenter.display = display

        self.interactor = interactor
        self.presenter = presenter
        self.router = router

        interactor.loadDashboard(.init(childId: childId, forceReload: true, period: .week))
        // Запрашиваем LLM-сводку и insights немного позже, чтобы основной UI успел отрисоваться.
        try? await Task.sleep(for: .milliseconds(150))
        requestLLMSummary()
        requestInsights()
    }
}


// MARK: - Preview

#Preview("ProgressDashboard – Parent") {
    ProgressDashboardView()
        .environment(AppContainer.preview())
        .environment(\.circuitContext, .parent)
}
