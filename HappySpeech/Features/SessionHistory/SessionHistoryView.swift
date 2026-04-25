import SwiftUI
import OSLog

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

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if display.isLoading && display.groups.isEmpty {
            HSLoadingView(message: String(localized: "sessionHistory.loading"))
        } else if display.isEmpty {
            emptyStateView
        } else {
            VStack(spacing: 0) {
                if !display.activeSoundChips.isEmpty || display.activeFilter.fromDate != nil || display.activeFilter.toDate != nil {
                    activeFilterStrip
                }
                sessionList
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var filterToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                isFilterSheetOpen = true
            } label: {
                Image(systemName: display.activeFilter.isActive
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
                    .font(.system(size: 18, weight: .semibold))
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
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
            }

            Button {
                interactor?.clearFilter(.init())
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .frame(width: 44, height: 44)
            }
            .padding(.trailing, SpacingTokens.tiny)
            .accessibilityLabel(String(localized: "sessionHistory.a11y.clearFilter"))
        }
        .padding(.vertical, SpacingTokens.tiny)
        .background(ColorTokens.Parent.bg)
    }

    // MARK: - Session list

    private var sessionList: some View {
        List {
            ForEach(display.groups) { group in
                Section {
                    ForEach(group.rows) { row in
                        Button {
                            handleOpen(row.id)
                        } label: {
                            SessionHistoryRowContent(row: row)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(ColorTokens.Parent.surface)
                        .listRowSeparatorTint(ColorTokens.Parent.line)
                    }
                } header: {
                    Text(group.monthTitle)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .textCase(.uppercase)
                        .accessibilityAddTraits(.isHeader)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ColorTokens.Parent.bg)
    }

    // MARK: - Empty

    @ViewBuilder
    private var emptyStateView: some View {
        let isFilterEmpty = display.emptyKind == .noResultsForFilter
        VStack(spacing: SpacingTokens.large) {
            Spacer(minLength: SpacingTokens.xLarge)

            Text(verbatim: isFilterEmpty ? "🔎" : "📅")
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

            ScoreBadge(text: row.scoreText, tier: row.scoreTier)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
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

// MARK: - ScoreBadge

private struct ScoreBadge: View {
    let text: String
    let tier: ScoreTier

    var body: some View {
        Text(text)
            .font(TypographyTokens.mono(13).weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, SpacingTokens.small)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(color)
            )
            .accessibilityHidden(true)
    }

    private var color: Color {
        switch tier {
        case .excellent: return ColorTokens.Semantic.success
        case .ok:        return ColorTokens.Semantic.warning
        case .low:       return ColorTokens.Semantic.error
        }
    }
}

// MARK: - SessionHistoryFilterChipBadge

private struct SessionHistoryFilterChipBadge: View {
    let label: String
    let icon: String

    var body: some View {
        HStack(spacing: SpacingTokens.micro) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
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
    }
}

// MARK: - Filter Sheet

private struct SessionHistoryFilterSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let initialFilter: SessionFilter
    let onApply: (SessionFilter) -> Void
    let onClear: () -> Void

    @State private var fromDate: Date?
    @State private var toDate: Date?
    @State private var selectedSounds: Set<String> = []
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
        initialFilter: SessionFilter,
        onApply: @escaping (SessionFilter) -> Void,
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

    // MARK: Buttons

    private var applyAndClearButtons: some View {
        VStack(spacing: SpacingTokens.small) {
            HSButton(
                String(localized: "sessionHistory.filter.apply"),
                style: .primary,
                size: .large,
                icon: "checkmark"
            ) {
                let filter = SessionFilter(
                    fromDate: fromDate,
                    toDate: toDate,
                    sounds: selectedSounds
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sectionGap) {
                headerCard
                metricsRow
                attemptsSection
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.vertical, SpacingTokens.large)
        }
        .background(ColorTokens.Parent.bg.ignoresSafeArea())
        .navigationTitle(detail.titleLine)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
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
                MetricCard(
                    title: String(localized: "sessionHistory.detail.metric.accuracy"),
                    value: "\(detail.scorePercent)%",
                    color: scoreColor,
                    icon: "target"
                )
                MetricCard(
                    title: String(localized: "sessionHistory.detail.metric.attempts"),
                    value: "\(detail.attemptsCount)",
                    color: ColorTokens.Parent.accent,
                    icon: "list.number"
                )
                MetricCard(
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
                    AttemptRowCard(row: attempt)
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

// MARK: - MetricCard

private struct MetricCard: View {

    let title: String
    let value: String
    let color: Color
    let icon: String

    var body: some View {
        HSCard(style: .flat, padding: SpacingTokens.regular) {
            VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                Text(value)
                    .font(TypographyTokens.headline(20))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(title)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - AttemptRowCard

private struct AttemptRowCard: View {
    let row: AttemptDetailRowViewModel

    var body: some View {
        HSCard(style: .flat, padding: SpacingTokens.regular) {
            HStack(spacing: SpacingTokens.regular) {
                Text("#\(row.index)")
                    .font(TypographyTokens.mono(13))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .frame(width: 28, alignment: .leading)

                Text(row.word)
                    .font(TypographyTokens.body(15).weight(.semibold))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: SpacingTokens.tiny)

                Text(row.durationText)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkSoft)

                ScoreBadge(text: "\(row.scorePercent)%", tier: row.scoreTier)

                Image(systemName: row.isCorrect ? "checkmark.circle.fill" : "xmark.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(row.isCorrect
                                     ? ColorTokens.Semantic.success
                                     : ColorTokens.Semantic.error)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.accessibilityLabel)
    }
}

// MARK: - Preview

#Preview("SessionHistory – Parent") {
    SessionHistoryView()
        .environment(AppContainer.preview())
        .environment(\.circuitContext, .parent)
}
