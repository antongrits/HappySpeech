import Charts
import OSLog
import SwiftUI

// MARK: - SessionHistoryView
//
// Parent-контур. Список сессий, сгруппированных по месяцам. Поддерживает
// фильтрацию (период + звуки), pull-to-refresh, push в детальный просмотр,
// EmptyState (нет сессий / нет результатов), toast-ошибки.
//
// VIP: View → Interactor (запросы) → Presenter (форматирование) → Display (Observable).
// Подкомпоненты: `SessionHistoryViewComponents.swift`, `SessionHistoryDetailView.swift`.

struct SessionHistoryView: View {

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    // MARK: - VIP State

    @State private var display = SessionHistoryDisplay()
    @State private var interactor: SessionHistoryInteractor?
    @State private var presenter: SessionHistoryPresenter?
    @State private var router: SessionHistoryRouter?
    @State private var bootstrapped = false

    // MARK: - Local UI State

    @State private var isFilterSheetOpen = false
    @State private var isExportSheetOpen = false
    @State private var path: [SessionDetailRoute] = []

    // Block J v18 — hero zoom transition (iOS 18+) для row → detail.
    @Namespace private var heroNamespace

    // Optional childId — оставлено для будущей привязки к репозиторию.
    private let childId: String?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SessionHistoryView")

    // MARK: - Init

    init(childId: String? = nil) {
        self.childId = childId
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottom) {
                // P0.5 fix v19: explicit parent bg behind gradient prevents warm KidBg
                // from bleeding through when navigating from kid circuit screens.
                ColorTokens.Parent.bg.ignoresSafeArea()
                backgroundGradient.ignoresSafeArea()

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
                if display.pendingShareURL != nil {
                    shareSheetOverlay
                }
            }
            .navigationTitle(String(localized: "sessionHistory.navTitle"))
            .navigationBarTitleDisplayMode(.large)
            // P0.5 fix v19: explicit toolbar background prevents iOS 26 Liquid Glass
            // from washing out the navigation title contrast on parent circuit.
            .toolbarBackground(ColorTokens.Parent.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar { filterToolbarItem }
            .sheet(isPresented: $isFilterSheetOpen) {
                SessionHistoryFilterSheet(
                    initialFilter: display.activeFilter,
                    onApply: { newFilter in
                        isFilterSheetOpen = false
                        interactor?.applyFilter(.init(filter: newFilter))
                    },
                    onClear: {
                        isFilterSheetOpen = false
                        interactor?.clearFilter(.init())
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $isExportSheetOpen) {
                SessionHistoryExportSheet(
                    onPDF: { interactor?.exportPDF(.init(childId: childId ?? "child")) },
                    onCSV: { interactor?.exportCSV(.init(childId: childId ?? "child")) },
                    onJSON: { interactor?.exportJSON(.init(childId: childId ?? "child")) }
                )
                .presentationDetents([.height(280)])
            }
            .navigationDestination(for: SessionDetailRoute.self) { route in
                SessionHistoryDetailView(detail: route.detail)
                    // Block J v18 — hero zoom destination (iOS 18+ matchedTransitionSource).
                    .heroDestination(id: route.detail.id, namespace: heroNamespace)
            }
        }
        .environment(\.circuitContext, .parent)
        .task { await bootstrap() }
        .onChange(of: display.pendingDetail) { _, newDetail in
            guard let detail = newDetail else { return }
            path.append(SessionDetailRoute(detail: detail))
            display.consumePendingDetail()
        }
    }

    // MARK: - Background

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                ColorTokens.Parent.bgDeep,
                ColorTokens.Parent.bg
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if display.isLoading && display.groups.isEmpty {
            // Block J v18 — skeleton shimmer вместо ProgressView spinner.
            VStack(spacing: SpacingTokens.regular) {
                ForEach(0..<5, id: \.self) { _ in
                    HSSkeletonCard()
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.regular)
            .redacted(reason: .placeholder)
            .hsShimmer(active: true)
            .accessibilityLabel(String(localized: "sessionHistory.loading"))
        } else if display.isEmpty {
            emptyStateView
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: SpacingTokens.regular, pinnedViews: []) {
                    if !display.activeSoundChips.isEmpty
                        || display.activeFilter.fromDate != nil
                        || display.activeFilter.toDate != nil {
                        activeFilterStrip
                            .padding(.top, SpacingTokens.tiny)
                    }

                    summaryCard
                        .padding(.horizontal, SpacingTokens.screenEdge)

                    if display.chartPoints().count >= 2 {
                        chartCard
                            .padding(.horizontal, SpacingTokens.screenEdge)
                    }

                    groupedSessions
                        .padding(.horizontal, SpacingTokens.screenEdge)
                }
                .padding(.bottom, SpacingTokens.xLarge)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Summary Card (Liquid Glass)

    private var summaryCard: some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.large) {
            HStack(alignment: .center, spacing: SpacingTokens.regular) {
                summaryMetric(
                    valueText: "\(display.filteredCount)",
                    captionText: String(localized: "sessionHistory.summary.sessions"),
                    color: ColorTokens.Parent.accent,
                    icon: "list.bullet.clipboard"
                )

                summaryDivider

                summaryMetric(
                    valueText: "\(display.averageAccuracyPercent())%",
                    captionText: String(localized: "sessionHistory.summary.accuracy"),
                    color: averageAccuracyColor,
                    icon: "target"
                )

                summaryDivider

                summaryMetric(
                    valueText: "\(display.totalDurationMinutes())",
                    captionText: String(localized: "sessionHistory.summary.minutes"),
                    color: ColorTokens.Brand.butter,
                    icon: "clock"
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(summaryAccessibilityLabel)
    }

    private func summaryMetric(
        valueText: String,
        captionText: String,
        color: Color,
        icon: String
    ) -> some View {
        VStack(alignment: .center, spacing: SpacingTokens.micro) {
            Image(systemName: icon)
                .font(TypographyTokens.labelRounded(14))
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(valueText)
                .font(TypographyTokens.headline(22).weight(.bold))
                .foregroundStyle(ColorTokens.Parent.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(captionText)
                .font(TypographyTokens.caption(11))
                // P0.5 fix v19: use ink (high-contrast) instead of inkMuted for
                // session summary captions. inkMuted fails WCAG AA on warm backgrounds.
                .foregroundStyle(ColorTokens.Parent.ink)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
    }

    private var summaryDivider: some View {
        Rectangle()
            .fill(ColorTokens.Parent.line)
            .frame(width: 1, height: 36)
            .accessibilityHidden(true)
    }

    private var averageAccuracyColor: Color {
        let percent = display.averageAccuracyPercent()
        if percent >= 70 { return ColorTokens.Semantic.success }
        if percent >= 50 { return ColorTokens.Semantic.warning }
        return ColorTokens.Semantic.error
    }

    private var summaryAccessibilityLabel: String {
        String(
            format: String(localized: "sessionHistory.a11y.summaryPattern"),
            display.filteredCount,
            display.averageAccuracyPercent(),
            display.totalDurationMinutes()
        )
    }

    // MARK: - Chart Card (Liquid Glass + Swift Charts)

    private var chartCard: some View {
        HSLiquidGlassCard(style: .primary, padding: SpacingTokens.large) {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                HStack(spacing: SpacingTokens.tiny) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(TypographyTokens.labelRounded(14))
                        .foregroundStyle(ColorTokens.Parent.accent)
                    Text(String(localized: "sessionHistory.chart.title"))
                        .font(TypographyTokens.caption(12).weight(.semibold))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .textCase(.uppercase)
                        .accessibilityAddTraits(.isHeader)
                }

                trendChart
                    .frame(height: 160)
                    .accessibilityLabel(String(localized: "sessionHistory.a11y.chart"))
                    .accessibilityValue(chartAccessibilityValue)
            }
        }
    }

    private var trendChart: some View {
        let points = display.chartPoints()
        return Chart(points) { point in
            AreaMark(
                x: .value("date", point.date),
                yStart: .value("zero", 0),
                yEnd: .value("accuracy", point.accuracyPercent)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        ColorTokens.Parent.accent.opacity(0.40),
                        ColorTokens.Parent.accent.opacity(0.04)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("date", point.date),
                y: .value("accuracy", point.accuracyPercent)
            )
            .foregroundStyle(ColorTokens.Parent.accent)
            .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round))
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("date", point.date),
                y: .value("accuracy", point.accuracyPercent)
            )
            .foregroundStyle(ColorTokens.Parent.surface)
            .symbolSize(28)
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                AxisGridLine()
                    .foregroundStyle(ColorTokens.Parent.line.opacity(0.6))
                AxisValueLabel {
                    if let percent = value.as(Int.self) {
                        Text("\(percent)%")
                            .font(TypographyTokens.caption(10))
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: false)
                    .font(TypographyTokens.caption(10))
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
            }
        }
    }

    private var chartAccessibilityValue: String {
        let points = display.chartPoints()
        guard !points.isEmpty else { return "" }
        let last = Int(points.last?.accuracyPercent ?? 0)
        let first = Int(points.first?.accuracyPercent ?? 0)
        return String(
            format: String(localized: "sessionHistory.a11y.chartTrendPattern"),
            points.count,
            first,
            last
        )
    }

    // MARK: - Grouped sessions (Liquid Glass cards)

    private var groupedSessions: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.regular) {
            ForEach(display.groups) { group in
                VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                    Text(group.monthTitle)
                        .font(TypographyTokens.caption(12).weight(.semibold))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .textCase(.uppercase)
                        .padding(.horizontal, SpacingTokens.tiny)
                        .accessibilityAddTraits(.isHeader)

                    HSLiquidGlassCard(style: .primary, padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(group.rows.enumerated()), id: \.element.id) { index, row in
                                Button {
                                    handleOpen(row.id)
                                } label: {
                                    SessionHistoryRowContent(row: row)
                                        .padding(.horizontal, SpacingTokens.regular)
                                        .padding(.vertical, SpacingTokens.small)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                // Block J v18 — hero zoom source (iOS 18+).
                                .heroSource(id: row.id, namespace: heroNamespace)

                                if index < group.rows.count - 1 {
                                    Divider()
                                        .background(ColorTokens.Parent.line)
                                        .padding(.leading, SpacingTokens.regular + 40 + SpacingTokens.regular)
                                }
                            }
                        }
                    }
                    // Block J v18 — kavsoft-style tilt carousel scroll transition.
                    .hsScrollEffect(.tiltCarousel)
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var filterToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: SpacingTokens.tiny) {
                Button {
                    isExportSheetOpen = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(TypographyTokens.subtitle(17))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(String(localized: "sessionHistory.a11y.openExport"))

                Button {
                    isFilterSheetOpen = true
                } label: {
                    Image(systemName: display.activeFilter.isActive
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                        .font(TypographyTokens.subtitle(18))
                        .foregroundStyle(display.activeFilter.isActive
                                         ? ColorTokens.Parent.accent
                                         : ColorTokens.Parent.inkMuted)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(String(localized: "sessionHistory.a11y.openFilter"))
                .accessibilityValue(display.activeFilter.isActive
                                    ? String(localized: "sessionHistory.a11y.filterActive")
                                    : String(localized: "sessionHistory.a11y.filterInactive"))
            }
        }
    }

    // MARK: - Active filter strip (chips)

    private var activeFilterStrip: some View {
        HStack(spacing: SpacingTokens.tiny) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SpacingTokens.tiny) {
                    if let from = display.activeFilter.fromDate, let to = display.activeFilter.toDate {
                        SessionHistoryFilterChipBadge(
                            label: dateRangeLabel(from: from, to: to),
                            icon: "calendar"
                        )
                    } else if let from = display.activeFilter.fromDate {
                        SessionHistoryFilterChipBadge(
                            label: dateSingleLabel(from),
                            icon: "calendar"
                        )
                    }
                    ForEach(display.activeSoundChips, id: \.self) { sound in
                        SessionHistoryFilterChipBadge(label: sound, icon: "speaker.wave.2")
                    }
                    if display.activeFilter.scoreRange != .all {
                        SessionHistoryFilterChipBadge(
                            label: scoreRangeLabel(display.activeFilter.scoreRange),
                            icon: "target"
                        )
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
            }

            Button {
                interactor?.clearFilter(.init())
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(TypographyTokens.headline(18))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .frame(width: 44, height: 44)
            }
            .padding(.trailing, SpacingTokens.tiny)
            .accessibilityLabel(String(localized: "sessionHistory.a11y.clearFilter"))
        }
        .padding(.vertical, SpacingTokens.tiny)
        .background(ColorTokens.Parent.bg)
    }

    private func scoreRangeLabel(_ range: SessionHistoryFilter.ScoreRange) -> String {
        switch range {
        case .all:    return ""
        case .high:   return String(localized: "sessionHistory.filter.scoreHigh")
        case .medium: return String(localized: "sessionHistory.filter.scoreMedium")
        case .low:    return String(localized: "sessionHistory.filter.scoreLow")
        }
    }

    @ViewBuilder
    private var shareSheetOverlay: some View {
        Color.clear
            .sheet(item: Binding(
                get: { display.pendingShareURL.map(SessionHistoryShareItem.init) },
                set: { _ in display.consumePendingShareURL() }
            )) { item in
                SessionHistoryShareSheet(url: item.url)
                    .ignoresSafeArea()
            }
    }

    // MARK: - Empty

    @ViewBuilder
    private var emptyStateView: some View {
        // G.1 v17 — унифицированный empty-state через HSEmptyStateView (mascot-вариант).
        // Маскот выражает контекст: thinking — фильтр пуст, explaining — нет сессий.
        let isFilterEmpty = display.emptyKind == .noResultsForFilter
        HSEmptyStateView(
            mascot: isFilterEmpty ? .thinking : .explaining,
            title: display.emptyTitle,
            subtitle: display.emptyMessage,
            actionTitle: isFilterEmpty
                ? String(localized: "sessionHistory.empty.cta.clear")
                : String(localized: "sessionHistory.empty.cta.start"),
            action: {
                if isFilterEmpty {
                    interactor?.clearFilter(.init())
                } else {
                    handleStartLesson()
                }
            }
        )
    }

    // MARK: - Actions

    private func handleOpen(_ id: String) {
        container.hapticService.selection()
        logger.info("openSession id=\(id, privacy: .public)")
        interactor?.openSession(.init(id: id))
    }

    private func performRefresh() {
        container.hapticService.impact(.light)
        interactor?.loadHistory(.init(forceReload: true))
    }

    private func handleStartLesson() {
        container.hapticService.impact(.medium)
        logger.info("emptyState start lesson tapped")
        // На M8 будет роутинг в LessonPlayer.
    }

    // MARK: - Formatting helpers

    private func dateRangeLabel(from: Date, to: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        return "\(formatter.string(from: from)) – \(formatter.string(from: to))"
    }

    private func dateSingleLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    // MARK: - Bootstrap

    @MainActor
    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        let interactor = SessionHistoryInteractor()
        let presenter = SessionHistoryPresenter()
        let router = SessionHistoryRouter()

        interactor.presenter = presenter
        presenter.display = display

        self.interactor = interactor
        self.presenter = presenter
        self.router = router

        interactor.loadHistory(.init(forceReload: true))
    }
}

// MARK: - Preview

#Preview("SessionHistory – Parent") {
    SessionHistoryView()
        .environment(AppContainer.preview())
        .environment(\.circuitContext, .parent)
}
