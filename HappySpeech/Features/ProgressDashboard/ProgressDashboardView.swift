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
    @Environment(\.exitToParentHome) private var exitToParentHome

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
                // Чистый тёплый статичный фон (без декоративной mesh-подложки и
                // движущейся «волны» — по требованию владельца).
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
            // Block J v18 — skeleton shimmer вместо ProgressView spinner.
            VStack(spacing: SpacingTokens.regular) {
                ForEach(0..<6, id: \.self) { _ in
                    HSSkeletonCard()
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.regular)
            .redacted(reason: .placeholder)
            .hsShimmer(active: true)
            .accessibilityLabel(String(localized: "progressDashboard.loading"))
        } else if display.isEmpty {
            emptyStateView
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.sectionGap) {
                    // E v21: 3D Ляля hero на ProgressDashboard
                    // (требование «3D героев на каждом экране»).
                    LyalyaHeroView(state: .thinking, size: 110)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .accessibilityHidden(true)
                        .padding(.top, SpacingTokens.small)
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
    //
    // Block J v18 — заменён custom PeriodChipView ряд на HSSegmentedPicker
    // (kavsoft-style capsule indicator с matchedGeometryEffect).
    // PeriodChipView оставлен в Components на случай legacy preview.

    private var periodPickerSection: some View {
        HSSegmentedPicker(
            selection: Binding(
                get: { display.selectedPeriod },
                set: { handlePeriodChange($0) }
            ),
            items: ProgressDashboardModels.TimePeriod.allCases,
            style: .underline
        ) { period in
            switch period {
            case .week:    return LocalizedStringKey("progressDashboard.period.week")
            case .month:   return LocalizedStringKey("progressDashboard.period.month")
            case .quarter: return LocalizedStringKey("progressDashboard.period.quarter")
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .environment(\.circuitContext, .parent)
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
                            iconTint: ColorTokens.Brand.gold,
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
                        .hsSymbolEffect(.pulse, value: chips.count)
                        .accessibilityHidden(true)
                    Text(title)
                        .font(TypographyTokens.headline(15))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
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
                // G.2 v17 — skeleton+shimmer вместо текстового «загрузка…»
                // Используем 2 HSSkeletonCard с .hsShimmer; Reduce Motion
                // отключает анимацию через сам HSSkeletonShimmer.
                VStack(spacing: SpacingTokens.small) {
                    HSSkeletonCard()
                    HSSkeletonCard()
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .hsShimmer(active: true)
                .accessibilityLabel(String(localized: "dashboard.insights.loading"))
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
                            // Block J v18 — kavsoft-style tilt carousel scroll transition.
                            .hsScrollEffect(.tiltCarousel)
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
                ForEach(Array(display.summaryCards.enumerated()), id: \.element.id) { index, card in
                    SummaryCardView(card: card)
                        .scrollTransition(.animated(reduceMotion ? .linear(duration: 0) : .spring(response: 0.5, dampingFraction: 0.85))) { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0)
                                .scaleEffect(phase.isIdentity ? 1 : 0.94)
                        }
                        .hsParallaxTile(factor: 0.18)
                        .zIndex(Double(display.summaryCards.count - index))
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
    }

    // MARK: - Chart data sufficiency

    /// `true`, когда точек с ненулевым значением < 2 — рисовать полноценный
    /// график бессмысленно (одна точка/всё по нулям выглядит «сломанным»).
    /// Вместо этого показываем дружелюбный плейсхолдер «данных пока мало».
    private func needsMoreData(_ values: [Double]) -> Bool {
        values.filter { $0 > 0 }.count < 2
    }

    /// Плейсхолдер внутри карточки графика при недостатке данных.
    private var chartNeedMoreDataPlaceholder: some View {
        VStack(spacing: SpacingTokens.small) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 30))
                .foregroundStyle(ColorTokens.Brand.primary.opacity(0.65))
                .accessibilityHidden(true)
            Text(String(localized: "progressDashboard.chart.needMoreData.title"))
                .font(TypographyTokens.headline(15))
                .foregroundStyle(ColorTokens.Parent.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
            Text(String(localized: "progressDashboard.chart.needMoreData.subtitle"))
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(String(localized: "progressDashboard.chart.needMoreData.title")). " +
            "\(String(localized: "progressDashboard.chart.needMoreData.subtitle"))"
        )
    }

    // MARK: - Daily chart

    private var dailyChartSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.regular) {
            sectionHeader(
                title: String(localized: "progressDashboard.section.weekly"),
                subtitle: String(localized: "progressDashboard.section.weekly.subtitle")
            )

            HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.regular) {
                if needsMoreData(display.dailyChart.map(\.value)) {
                    chartNeedMoreDataPlaceholder
                } else {
                    Chart(display.dailyChart) { point in
                        BarMark(
                            x: .value(String(localized: "progressDashboard.chart.day"), point.day),
                            y: .value(String(localized: "progressDashboard.chart.accuracy"), point.value)
                        )
                        .foregroundStyle(barColor(for: point.value))
                        .cornerRadius(6)
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
                if needsMoreData(display.weeklyChart.map(\.value)) {
                    chartNeedMoreDataPlaceholder
                } else {
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
                                .minimumScaleFactor(0.85)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(summary.bodyText)
                                .font(TypographyTokens.body(15))
                                .foregroundStyle(ColorTokens.Parent.inkMuted)
                                .lineSpacing(TypographyTokens.LineSpacing.normal)
                                .lineLimit(nil)
                                .minimumScaleFactor(0.85)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityLabel(summary.accessibilityLabel)
                            if summary.isFallback {
                                Text(String(localized: "progressDashboard.llm.fallbackBadge"))
                                    .font(TypographyTokens.caption(11))
                                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .minimumScaleFactor(0.85)
                            }
                        } else {
                            // G.2 v17 — skeleton-rows вместо «генерирую…».
                            // Симулирует 2 строки заголовка и 2 строки тела.
                            VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                                HSSkeletonRow(height: 16)
                                    .frame(maxWidth: 200)
                                HSSkeletonRow(height: 12)
                                HSSkeletonRow(height: 12)
                                    .frame(maxWidth: 240)
                            }
                            .hsShimmer(active: true)
                            .accessibilityLabel(String(localized: "progressDashboard.llm.loading"))
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
                ForEach(Array(display.soundCells.enumerated()), id: \.element.id) { index, cell in
                    Button {
                        handleOpenSound(cell.sound)
                    } label: {
                        SoundProgressCellView(cell: cell)
                    }
                    .buttonStyle(.plain)
                    .scrollTransition(.animated(reduceMotion ? .linear(duration: 0) : .spring(response: 0.55, dampingFraction: 0.85))) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0)
                            .scaleEffect(phase.isIdentity ? 1 : 0.92)
                    }
                    .hsParallaxTile(factor: 0.20)
                    .zIndex(Double(display.soundCells.count - index))
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        // Анимированный Lottie empty-state «нет данных прогресса», parent-контур.
        // CTA ведёт обратно на родительскую главную, где можно начать занятие —
        // раньше кнопка только логировала (dead-end).
        HSEmptyStateView(
            lottie: .emptyNoHistory,
            fallbackSymbol: "chart.line.uptrend.xyaxis",
            title: display.emptyTitle,
            message: display.emptyMessage,
            actionTitle: String(localized: "progressDashboard.empty.cta"),
            action: {
                container.hapticService.impact(.medium)
                logger.info("emptyState start lesson tapped")
                exitToParentHome()
            }
        )
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionHeader(title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.micro) {
            Text(title)
                .font(TypographyTokens.title(20))
                .foregroundStyle(ColorTokens.Parent.ink)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
            if let subtitle {
                Text(subtitle)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func barColor(for value: Double) -> Color {
        if value >= 70 { return ColorTokens.Brand.gold }
        if value >= 50 { return ColorTokens.Brand.primary }
        return ColorTokens.Brand.rose
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
        // Сводка собирается из реальных display-карточек (источник — Interactor/Worker).
        // Сам Interactor для LLM использует свои реальные агрегаты; здесь summary
        // передаётся для совместимости контракта Request.
        func cardValue(_ kind: SummaryCardViewModel.Kind) -> Int {
            display.summaryCards.first(where: { $0.kind == kind })
                .flatMap { Int($0.value.filter(\.isNumber)) } ?? 0
        }
        let summaryDomain = DashboardSummary(
            overallAccuracy: Float(cardValue(.accuracy)) / 100.0,
            streakDays: cardValue(.streak),
            totalMinutes: cardValue(.minutes),
            totalStars: cardValue(.stars)
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

        let worker = ProgressDashboardWorker(
            sessionRepository: container.sessionRepository,
            childRepository: container.childRepository
        )
        let interactor = ProgressDashboardInteractor(
            worker: worker,
            llmDecisionService: container.llmDecisionService,
            childRepository: container.childRepository
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
    // Сид-ребёнок с реальной историей сессий (MockSessionRepository.seeded()).
    ProgressDashboardView(childId: "preview-child-1")
        .environment(AppContainer.preview())
        .environment(\.circuitContext, .parent)
}
