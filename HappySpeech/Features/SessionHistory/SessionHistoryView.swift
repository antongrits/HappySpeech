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
            HSLoadingView(message: String(localized: "sessionHistory.loading"))
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
                .foregroundStyle(ColorTokens.Parent.inkMuted)
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

                                if index < group.rows.count - 1 {
                                    Divider()
                                        .background(ColorTokens.Parent.line)
                                        .padding(.leading, SpacingTokens.regular + 40 + SpacingTokens.regular)
                                }
                            }
                        }
                    }
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
        let isFilterEmpty = display.emptyKind == .noResultsForFilter
        VStack(spacing: SpacingTokens.large) {
            Spacer(minLength: SpacingTokens.xLarge)

            Text(verbatim: isFilterEmpty ? "🔎" : "📅")
                .font(.system(size: 96)) // emoji key graphic — skip TypographyTokens
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
                isFilterEmpty
                    ? String(localized: "sessionHistory.empty.cta.clear")
                    : String(localized: "sessionHistory.empty.cta.start"),
                style: .primary,
                size: .medium,
                icon: isFilterEmpty ? "arrow.clockwise" : "play.fill"
            ) {
                if isFilterEmpty {
                    interactor?.clearFilter(.init())
                } else {
                    handleStartLesson()
                }
            }
            .frame(maxWidth: 280)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(display.emptyTitle). \(display.emptyMessage)")
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

// MARK: - SessionDetailRoute

private struct SessionDetailRoute: Hashable {
    let detail: SessionDetailViewModel
}

// MARK: - SessionHistoryRowContent

private struct SessionHistoryRowContent: View {

    let row: SessionHistoryRowViewModel

    var body: some View {
        HStack(spacing: SpacingTokens.regular) {
            // Дата-плитка
            VStack(spacing: 2) {
                Text(row.dayNumber)
                    .font(TypographyTokens.mono(15).weight(.bold))
                    .foregroundStyle(ColorTokens.Parent.ink)
                Text(row.monthAbbr)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
            }
            .frame(width: 40, alignment: .center)

            // Цветной dot — тип игры
            Circle()
                .fill(Color(row.gameAccentColorName))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text(row.title)
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)

                Text(row.metaLine)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
            }

            Spacer(minLength: SpacingTokens.tiny)

            SessionHistoryScoreBadge(text: row.scoreText, tier: row.scoreTier)

            Image(systemName: "chevron.right")
                .font(TypographyTokens.labelRounded(13))
                .foregroundStyle(ColorTokens.Parent.inkSoft)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 56)
        .padding(.vertical, SpacingTokens.tiny)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityHint(row.accessibilityHint)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - SessionHistoryFilterChipBadge

private struct SessionHistoryFilterChipBadge: View {
    let label: String
    let icon: String

    var body: some View {
        HStack(spacing: SpacingTokens.micro) {
            Image(systemName: icon)
                .font(TypographyTokens.caption(10))
            Text(label)
                .font(TypographyTokens.caption(12).weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(ColorTokens.Parent.accent)
        .padding(.horizontal, SpacingTokens.small)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(ColorTokens.Parent.accent.opacity(0.12))
        )
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Filter Sheet

private struct SessionHistoryFilterSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let initialFilter: SessionHistoryFilter
    let onApply: (SessionHistoryFilter) -> Void
    let onClear: () -> Void

    @State private var fromDate: Date?
    @State private var toDate: Date?
    @State private var selectedSounds: Set<String> = []
    @State private var selectedScoreRange: SessionHistoryFilter.ScoreRange = .all
    @State private var datePeriod: DatePeriodChoice = .all

    private let allSounds: [String] = ["С", "З", "Ц", "Ш", "Ж", "Ч", "Щ", "Р", "Л", "К", "Г", "Х"]

    enum DatePeriodChoice: String, CaseIterable, Identifiable {
        case week, month, quarter, all
        var id: String { rawValue }

        var label: String {
            switch self {
            case .week:    return String(localized: "sessionHistory.filter.period.week")
            case .month:   return String(localized: "sessionHistory.filter.period.month")
            case .quarter: return String(localized: "sessionHistory.filter.period.quarter")
            case .all:     return String(localized: "sessionHistory.filter.period.all")
            }
        }

        var daysBack: Int? {
            switch self {
            case .week:    return 7
            case .month:   return 30
            case .quarter: return 90
            case .all:     return nil
            }
        }
    }

    init(
        initialFilter: SessionHistoryFilter,
        onApply: @escaping (SessionHistoryFilter) -> Void,
        onClear: @escaping () -> Void
    ) {
        self.initialFilter = initialFilter
        self.onApply = onApply
        self.onClear = onClear
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.large) {
                    Text(String(localized: "sessionHistory.filter.title"))
                        .font(TypographyTokens.headline(20))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .padding(.top, SpacingTokens.tiny)

                    periodSection
                    customDateSection
                    soundsSection
                    scoreRangeSection

                    Spacer(minLength: SpacingTokens.large)

                    applyAndClearButtons
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.xLarge)
            }
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
            .navigationTitle(String(localized: "sessionHistory.filter.navTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "sessionHistory.filter.close")) {
                        dismiss()
                    }
                    .accessibilityLabel(String(localized: "sessionHistory.filter.close"))
                }
            }
        }
        .onAppear {
            fromDate = initialFilter.fromDate
            toDate = initialFilter.toDate
            selectedSounds = initialFilter.sounds
            selectedScoreRange = initialFilter.scoreRange
        }
    }

    // MARK: Period

    private var periodSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
            Text(String(localized: "sessionHistory.filter.periodHeader"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SpacingTokens.tiny) {
                    ForEach(DatePeriodChoice.allCases) { period in
                        SessionFilterChipButton(
                            title: period.label,
                            isSelected: datePeriod == period
                        ) {
                            datePeriod = period
                            applyPeriod(period)
                        }
                    }
                }
            }
        }
    }

    private func applyPeriod(_ period: DatePeriodChoice) {
        guard let days = period.daysBack else {
            fromDate = nil
            toDate = nil
            return
        }
        let calendar = Calendar.current
        let now = Date()
        toDate = now
        fromDate = calendar.date(byAdding: .day, value: -days, to: now)
    }

    // MARK: Custom date

    private var customDateSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Text(String(localized: "sessionHistory.filter.dateHeader"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)

            HStack(spacing: SpacingTokens.regular) {
                DateFieldButton(
                    title: String(localized: "sessionHistory.filter.from"),
                    date: fromDate
                ) { newDate in
                    fromDate = newDate
                    datePeriod = .all
                }
                DateFieldButton(
                    title: String(localized: "sessionHistory.filter.to"),
                    date: toDate
                ) { newDate in
                    toDate = newDate
                    datePeriod = .all
                }
            }
        }
    }

    // MARK: Sounds

    private var soundsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Text(String(localized: "sessionHistory.filter.soundsHeader"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.tiny), count: 4),
                spacing: SpacingTokens.tiny
            ) {
                ForEach(allSounds, id: \.self) { sound in
                    SessionFilterChipButton(
                        title: sound,
                        isSelected: selectedSounds.contains(sound)
                    ) {
                        toggleSound(sound)
                    }
                }
            }
        }
    }

    private func toggleSound(_ sound: String) {
        if selectedSounds.contains(sound) {
            selectedSounds.remove(sound)
        } else {
            selectedSounds.insert(sound)
        }
    }

    // MARK: Score range

    private var scoreRangeSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Text(String(localized: "sessionHistory.filter.scoreHeader"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)
            HStack(spacing: SpacingTokens.tiny) {
                ForEach(SessionHistoryFilter.ScoreRange.allCases, id: \.rawValue) { range in
                    SessionFilterChipButton(
                        title: scoreLabelShort(range),
                        isSelected: selectedScoreRange == range
                    ) {
                        selectedScoreRange = range
                    }
                }
            }
        }
    }

    private func scoreLabelShort(_ range: SessionHistoryFilter.ScoreRange) -> String {
        switch range {
        case .all:    return String(localized: "sessionHistory.filter.period.all")
        case .high:   return String(localized: "sessionHistory.filter.scoreHigh")
        case .medium: return String(localized: "sessionHistory.filter.scoreMedium")
        case .low:    return String(localized: "sessionHistory.filter.scoreLow")
        }
    }

    // MARK: Buttons

    private var applyAndClearButtons: some View {
        VStack(spacing: SpacingTokens.small) {
            HSButton(
                String(localized: "sessionHistory.filter.apply"),
                style: .primary,
                size: .large,
                icon: "checkmark"
            ) {
                let filter = SessionHistoryFilter(
                    fromDate: fromDate,
                    toDate: toDate,
                    sounds: selectedSounds,
                    gameTypes: [],
                    scoreRange: selectedScoreRange
                )
                onApply(filter)
            }
            HSButton(
                String(localized: "sessionHistory.filter.clear"),
                style: .ghost,
                size: .medium,
                icon: "trash"
            ) {
                fromDate = nil
                toDate = nil
                selectedSounds = []
                selectedScoreRange = .all
                datePeriod = .all
                onClear()
            }
        }
    }
}

// MARK: - SessionFilterChipButton

private struct SessionFilterChipButton: View {

    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TypographyTokens.body(14).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(isSelected ? Color.white : ColorTokens.Parent.ink)
                .padding(.horizontal, SpacingTokens.regular)
                .padding(.vertical, SpacingTokens.small)
                .frame(minHeight: 44)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule().fill(
                        isSelected
                            ? ColorTokens.Parent.accent
                            : ColorTokens.Parent.surface
                    )
                )
                .overlay(
                    Capsule().strokeBorder(
                        isSelected ? Color.clear : ColorTokens.Parent.line,
                        lineWidth: 1
                    )
                )
                .scaleEffect(isPressed && !reduceMotion ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.75), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - DateFieldButton

private struct DateFieldButton: View {

    let title: String
    let date: Date?
    let onPick: (Date?) -> Void

    @State private var showPicker = false
    @State private var pickerDate: Date = Date()

    var body: some View {
        Button {
            pickerDate = date ?? Date()
            showPicker = true
        } label: {
            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text(title)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                Text(date.map(formatted) ?? String(localized: "sessionHistory.filter.notSet"))
                    .font(TypographyTokens.body(15).weight(.semibold))
                    .foregroundStyle(date == nil ? ColorTokens.Parent.inkMuted : ColorTokens.Parent.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(SpacingTokens.regular)
            .frame(minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .fill(ColorTokens.Parent.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .strokeBorder(ColorTokens.Parent.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(date.map(formatted) ?? String(localized: "sessionHistory.filter.notSet"))")
        .sheet(isPresented: $showPicker) {
            VStack {
                DatePicker(
                    title,
                    selection: $pickerDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                .accessibilityHint(String(localized: "sessionHistory.filter.datePicker.hint"))

                HStack(spacing: SpacingTokens.regular) {
                    HSButton(
                        String(localized: "sessionHistory.filter.notSet"),
                        style: .ghost,
                        size: .medium
                    ) {
                        onPick(nil)
                        showPicker = false
                    }
                    HSButton(
                        String(localized: "sessionHistory.filter.confirm"),
                        style: .primary,
                        size: .medium
                    ) {
                        onPick(pickerDate)
                        showPicker = false
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.large)
            }
            .presentationDetents([.medium])
        }
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - SessionHistoryDetailView

private struct SessionHistoryDetailView: View {

    let detail: SessionDetailViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var noteText: String = ""
    @State private var isEditingNote: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sectionGap) {
                headerCard
                metricsRow
                if detail.hasAudioRecording {
                    audioRow
                }
                attemptsSection
                parentNoteSection
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.vertical, SpacingTokens.large)
        }
        .background(ColorTokens.Parent.bg.ignoresSafeArea())
        .navigationTitle(detail.titleLine)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .onAppear {
            noteText = detail.parentNote ?? ""
        }
    }

    // MARK: Audio row

    private var audioRow: some View {
        HSCard(style: .flat, padding: SpacingTokens.regular) {
            HStack(spacing: SpacingTokens.regular) {
                Image(systemName: "waveform")
                    .font(TypographyTokens.titleSmall(20))
                    .foregroundStyle(ColorTokens.Parent.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "sessionHistory.detail.audioTitle"))
                        .font(TypographyTokens.body(15).weight(.semibold))
                        .foregroundStyle(ColorTokens.Parent.ink)
                    Text(String(localized: "sessionHistory.detail.audioSubtitle"))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(TypographyTokens.display(32))
                    .foregroundStyle(ColorTokens.Parent.accent)
                    .frame(width: 44, height: 44)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "sessionHistory.detail.audio.a11y"))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Parent note

    private var parentNoteSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            HStack {
                Text(String(localized: "sessionHistory.detail.noteTitle"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Parent.ink)
                Spacer()
                if !noteText.isEmpty {
                    Button {
                        isEditingNote = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(TypographyTokens.subtitle(16))
                            .foregroundStyle(ColorTokens.Parent.accent)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(String(localized: "sessionHistory.detail.noteEdit"))
                }
            }

            if noteText.isEmpty {
                Button {
                    isEditingNote = true
                } label: {
                    HStack(spacing: SpacingTokens.small) {
                        Image(systemName: "plus.circle")
                            .font(TypographyTokens.headline(18))
                            .foregroundStyle(ColorTokens.Parent.accent)
                        Text(String(localized: "sessionHistory.detail.noteAdd"))
                            .font(TypographyTokens.body(15))
                            .foregroundStyle(ColorTokens.Parent.accent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SpacingTokens.regular)
                    .frame(minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.md)
                            .strokeBorder(ColorTokens.Parent.accent.opacity(0.4), lineWidth: 1.5, antialiased: true)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "sessionHistory.detail.noteAdd"))
            } else {
                HSCard(style: .flat, padding: SpacingTokens.regular) {
                    Text(noteText)
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "sessionHistory.detail.noteA11yPrefix") + noteText)
            }
        }
        .sheet(isPresented: $isEditingNote) {
            SessionHistoryNoteEditorSheet(initialText: noteText) { saved in
                noteText = saved
                isEditingNote = false
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: Header

    private var headerCard: some View {
        HSCard(style: .elevated) {
            HStack(alignment: .top, spacing: SpacingTokens.regular) {
                VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                    Text(detail.titleLine)
                        .font(TypographyTokens.headline(20))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(detail.dateLine)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(2)
                }
                Spacer()
                Text("\(detail.scorePercent)%")
                    .font(TypographyTokens.display(36))
                    .foregroundStyle(scoreColor)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(detail.accessibilityHeader)
    }

    // MARK: Metrics — 3 карточки

    private var metricsRow: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.regular) {
            Text(String(localized: "sessionHistory.detail.metricsTitle"))
                .font(TypographyTokens.title(20))
                .foregroundStyle(ColorTokens.Parent.ink)

            HStack(spacing: SpacingTokens.regular) {
                SessionHistoryMetricCard(
                    title: String(localized: "sessionHistory.detail.metric.accuracy"),
                    value: "\(detail.scorePercent)%",
                    color: scoreColor,
                    icon: "target"
                )
                SessionHistoryMetricCard(
                    title: String(localized: "sessionHistory.detail.metric.attempts"),
                    value: "\(detail.attemptsCount)",
                    color: ColorTokens.Parent.accent,
                    icon: "list.number"
                )
                SessionHistoryMetricCard(
                    title: String(localized: "sessionHistory.detail.metric.duration"),
                    value: detail.durationText,
                    color: ColorTokens.Brand.butter,
                    icon: "clock"
                )
            }
        }
    }

    // MARK: Attempts list

    private var attemptsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.regular) {
            Text(String(localized: "sessionHistory.detail.attemptsTitle"))
                .font(TypographyTokens.title(20))
                .foregroundStyle(ColorTokens.Parent.ink)

            VStack(spacing: SpacingTokens.tiny) {
                ForEach(detail.attemptRows) { attempt in
                    SessionHistoryAttemptRowCard(row: attempt)
                }
            }
        }
    }

    private var scoreColor: Color {
        switch detail.scoreTier {
        case .excellent: return ColorTokens.Semantic.success
        case .ok:        return ColorTokens.Semantic.warning
        case .low:       return ColorTokens.Semantic.error
        }
    }
}

// MARK: - Preview

#Preview("SessionHistory – Parent") {
    SessionHistoryView()
        .environment(AppContainer.preview())
        .environment(\.circuitContext, .parent)
}
