import SwiftUI
import Charts
import OSLog

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
                    summaryCardsRow
                    dailyChartSection
                    weeklyChartSection
                    llmSummarySection
                    soundsGridSection
                }
                .padding(.vertical, SpacingTokens.large)
                .padding(.bottom, SpacingTokens.xLarge)
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

            HSCard(style: .elevated, padding: SpacingTokens.regular) {
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
                            if let v = value.as(Int.self) {
                                Text("\(v)%")
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

            HSCard(style: .elevated, padding: SpacingTokens.regular) {
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
                            if let v = value.as(Int.self) {
                                Text("\(v)%")
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

            HSCard(style: .elevated, padding: SpacingTokens.cardPad) {
                HStack(alignment: .top, spacing: SpacingTokens.regular) {
                    ZStack {
                        Circle()
                            .fill(ColorTokens.Brand.lilac.opacity(0.18))
                            .frame(width: 40, height: 40)
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .semibold))
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
                .font(.system(size: 96))
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

    private func performRefresh() {
        container.hapticService.impact(.light)
        interactor?.loadDashboard(.init(childId: childId, forceReload: true))
        requestLLMSummary()
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
        display.displayLLMLoading(true)
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

        interactor.loadDashboard(.init(childId: childId, forceReload: true))
        // Запрашиваем LLM-сводку немного позже, чтобы основной UI успел отрисоваться.
        try? await Task.sleep(for: .milliseconds(150))
        requestLLMSummary()
    }
}

// MARK: - SoundDetailRoute

private struct SoundDetailRoute: Hashable {
    let detail: SoundDetailViewModel
}

// MARK: - SummaryCardView

private struct SummaryCardView: View {

    let card: SummaryCardViewModel

    var body: some View {
        HSCard(style: .elevated, padding: SpacingTokens.cardPad) {
            VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                Text(card.title)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(card.value)
                    .font(TypographyTokens.display(34))
                    .foregroundStyle(accentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityHidden(true)

                if let progress = card.progress {
                    HSProgressBar(value: progress, style: .parent, tint: accentColor)
                        .frame(height: 4)
                        .padding(.top, SpacingTokens.micro)
                } else if let caption = card.caption {
                    Text(caption)
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 160, height: 120)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(card.accessibilityLabel)
    }

    private var accentColor: Color {
        switch card.valueAccent {
        case .accent: return ColorTokens.Parent.accent
        case .butter: return ColorTokens.Brand.butter
        case .mint:   return ColorTokens.Brand.mint
        case .lilac:  return ColorTokens.Brand.lilac
        }
    }
}

// MARK: - SoundProgressCellView

private struct SoundProgressCellView: View {

    let cell: SoundProgressCellViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HSCard(style: .elevated, padding: SpacingTokens.regular) {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                HStack(alignment: .top) {
                    Text(cell.sound)
                        .font(TypographyTokens.display(28))
                        .foregroundStyle(Color(cell.familyHueName))
                        .accessibilityHidden(true)

                    Spacer()

                    Image(systemName: cell.trendIconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(trendColor)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle().fill(trendColor.opacity(0.15))
                        )
                        .accessibilityHidden(true)
                }

                Text(cell.accuracyText)
                    .font(TypographyTokens.headline(20))
                    .foregroundStyle(ColorTokens.Parent.ink)

                HSProgressBar(
                    value: cell.accuracyValue / 100,
                    style: .parent,
                    tint: Color(cell.familyHueName)
                )
                .frame(height: 4)

                Text(cell.sessionsCaption)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cell.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var trendColor: Color {
        switch cell.trend {
        case .up:     return ColorTokens.Semantic.success
        case .down:   return ColorTokens.Semantic.error
        case .stable: return ColorTokens.Parent.inkMuted
        }
    }
}

// MARK: - SoundProgressDetailView

private struct SoundProgressDetailView: View {

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
        HSCard(style: .elevated) {
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

            HSCard(style: .elevated, padding: SpacingTokens.regular) {
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
                            if let v = value.as(Int.self) {
                                Text("\(v)%")
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

private struct DetailMetric: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HSCard(style: .flat, padding: SpacingTokens.regular) {
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

// MARK: - Preview

#Preview("ProgressDashboard – Parent") {
    ProgressDashboardView()
        .environment(AppContainer.preview())
        .environment(\.circuitContext, .parent)
}
