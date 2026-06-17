import OSLog
import SwiftUI

// MARK: - HomeTasksView
//
// Parent-контур. Список заданий, выданных логопедом или сгенерированных
// планировщиком после сессии. Поддерживает фильтрацию (все/активные/выполненные),
// pull-to-refresh, переключение «выполнено», EmptyState, toast-уведомления.
//
// VIP: View → Interactor (запросы) → Presenter (форматирование) → Display (Observable).

struct HomeTasksView: View {

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - VIP State

    @State private var display = HomeTasksDisplay()
    @State private var interactor: HomeTasksInteractor?
    @State private var presenter: HomeTasksPresenter?
    @State private var router: HomeTasksRouter?
    @State private var bootstrapped = false
    /// Гейт показа алерта о просроченных: становится `true` спустя короткую
    /// задержку после загрузки списка, чтобы prompt не перекрывал контент
    /// сразу при открытии (сначала виден список — потом мягкое напоминание).
    @State private var overduePromptReady = false

    // MARK: - Optional callbacks (для встраивания в Coordinator-flow)

    private let onDismiss: (() -> Void)?
    private let onOpenDetail: ((String) -> Void)?
    private let onStartGame: ((_ exerciseType: String, _ targetSound: String) -> Void)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "HomeTasksView")

    // MARK: - Init

    init(
        onDismiss: (() -> Void)? = nil,
        onOpenDetail: ((String) -> Void)? = nil,
        onStartGame: ((_ exerciseType: String, _ targetSound: String) -> Void)? = nil
    ) {
        self.onDismiss = onDismiss
        self.onOpenDetail = onOpenDetail
        self.onStartGame = onStartGame
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Parent-контур: спокойный однотонный холст #F0EFF6 (light) /
                // #181820 (dark) — соответствует эталону «Задания на дом».
                // Без кремового butter-оверлея (off-palette на крупной заливке).
                ColorTokens.Parent.bg
                    .ignoresSafeArea()

                content
                    .refreshable { performRefresh() }

                if let toast = display.toastMessage {
                    HSToast(toast, type: .success)
                        .padding(.bottom, SpacingTokens.large)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task {
                            try? await Task.sleep(for: .seconds(2.2))
                            withAnimation(.easeInOut(duration: 0.25)) {
                                display.clearToast()
                            }
                        }
                }
            }
            .navigationTitle(String(localized: "homeTasks.navTitle"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarBadge }
            .alert(
                String(localized: "homeTasks.overdue.alert.title"),
                isPresented: overduePromptBinding,
                actions: { overdueAlertActions },
                message: { Text(String(localized: "homeTasks.overdue.alert.message")) }
            )
            .sheet(item: Binding(
                get: { display.detailViewModel },
                set: { if $0 == nil { display.dismissDetailSheet() } }
            )) { detail in
                HomeTaskDetailSheet(
                    viewModel: detail,
                    reduceMotion: reduceMotion,
                    onToggle: { handleToggle(detail.id) },
                    onStart: { handleStart(detail.id) },
                    onScheduleReminder: { handleScheduleReminder(detail.id) },
                    onDismiss: { display.dismissDetailSheet() }
                )
                .presentationDetents([.large, .fraction(0.75)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(RadiusTokens.xl)
            }
        }
        .environment(\.circuitContext, .parent)
        .task { await bootstrap() }
        // Задержка показа алерта о просроченных: список рендерится первым,
        // напоминание всплывает спустя ~1.5с — не перекрывая контент сразу.
        .onChange(of: display.pendingOverduePrompt) { _, pending in
            scheduleOverduePromptGate(pending: pending)
        }
        .onChange(of: display.isLoading) { _, loading in
            if !loading { scheduleOverduePromptGate(pending: display.pendingOverduePrompt) }
        }
    }

    /// Открывает гейт показа overdue-алерта спустя короткую задержку, чтобы
    /// список заданий успел отобразиться до появления напоминания.
    private func scheduleOverduePromptGate(pending: Bool) {
        guard pending, !display.isLoading else {
            overduePromptReady = false
            return
        }
        guard !overduePromptReady else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            if display.pendingOverduePrompt && !display.isLoading {
                overduePromptReady = true
            }
        }
    }

    /// Двусторонний binding для `.alert` — гасит prompt через
    /// `display.dismissOverduePrompt()` при отказе пользователя.
    /// Алерт не показывается пока контент не загружен (isLoading == true),
    /// чтобы не перекрывать список на холодном запуске.
    private var overduePromptBinding: Binding<Bool> {
        Binding(
            get: {
                display.pendingOverduePrompt
                    && display.overdueCount > 0
                    && !display.isLoading
                    && overduePromptReady
            },
            set: { newValue in
                if !newValue {
                    display.dismissOverduePrompt()
                }
            }
        )
    }

    @ViewBuilder
    private var overdueAlertActions: some View {
        Button(String(localized: "homeTasks.overdue.alert.notify")) {
            handleNotifyOverdue()
        }
        Button(
            String(localized: "homeTasks.overdue.alert.later"),
            role: .cancel
        ) {
            display.dismissOverduePrompt()
        }
    }

    // MARK: - Content switch

    @ViewBuilder
    private var content: some View {
        if display.isLoading && display.sections.isEmpty {
            // Block J v18 — skeleton shimmer вместо ProgressView spinner.
            VStack(spacing: SpacingTokens.regular) {
                ForEach(0..<4, id: \.self) { _ in
                    HSSkeletonCard()
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.regular)
            .redacted(reason: .placeholder)
            .hsShimmer(active: true)
            .accessibilityLabel(String(localized: "homeTasks.loading"))
        } else {
            VStack(spacing: 0) {
                if !display.isEmpty {
                    summaryPill
                }
                weekStripView
                filterChipsBar
                if display.isEmpty {
                    emptyStateView
                } else {
                    tasksList
                }
            }
        }
    }

    // MARK: - Summary pill

    /// Сводная «таблетка» под заголовком — точно по эталону:
    /// коралловый кружок-счётчик слева + "N на сегодня" + разделитель + "✓ N выполнено".
    private var summaryPill: some View {
        let todayCount = display.activeCount
        let done = display.completedCount

        return HStack(spacing: SpacingTokens.small) {
            // Coral circle with today count
            Text("\(todayCount)")
                .font(TypographyTokens.mono(13).weight(.bold))
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .frame(width: 32, height: 32)
                .background(Circle().fill(ColorTokens.Brand.primary))
                .accessibilityHidden(true)

            Text(String(
                format: String(localized: "homeTasks.summary.total"),
                display.activeCount + display.completedCount
            ))
            .font(TypographyTokens.body(14))
            .foregroundStyle(ColorTokens.Parent.ink)
            .fixedSize(horizontal: false, vertical: true)
            .minimumScaleFactor(0.85)
            .lineLimit(1)

            if done > 0 {
                Text("·")
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .accessibilityHidden(true)
                HStack(spacing: SpacingTokens.micro) {
                    Image(systemName: "checkmark")
                        .font(TypographyTokens.caption(11).weight(.bold))
                    Text(String(
                        format: String(localized: "homeTasks.summary.done"),
                        done
                    ))
                    .font(TypographyTokens.body(13).weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                    .lineLimit(1)
                }
                .foregroundStyle(ColorTokens.Semantic.success)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, SpacingTokens.regular)
        .padding(.vertical, SpacingTokens.small)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.sm).fill(ColorTokens.Parent.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.sm)
                .strokeBorder(ColorTokens.Parent.line, lineWidth: 1)
        )
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.regular)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            format: String(localized: "homeTasks.summary.a11y"),
            display.activeCount + display.completedCount,
            done
        ))
    }

    // MARK: - Week strip

    /// Горизонтальный дневной пикер — 7 дней текущей недели.
    /// Активный день подсвечен коралловым. Соответствует эталону.
    private var weekStripView: some View {
        let weekdaySymbols = Calendar.current.shortStandaloneWeekdaySymbols
        // Build 7 days: Mon..Sun of current week
        let startOfWeek: Date = {
            var comps = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
            comps.weekday = 2 // Monday
            return Calendar.current.date(from: comps) ?? Date()
        }()
        let days: [(Int, String, Bool)] = (0..<7).compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: startOfWeek) else { return nil }
            let dayNum = Calendar.current.component(.day, from: date)
            let abbr = String(weekdaySymbols[offset].prefix(2)).uppercased()
            let isToday = Calendar.current.isDateInToday(date)
            return (dayNum, abbr, isToday)
        }

        return HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, entry in
                let (day, abbr, isToday) = entry
                VStack(spacing: SpacingTokens.micro) {
                    Text(abbr)
                        .font(TypographyTokens.caption(10).weight(.medium))
                        .foregroundStyle(isToday ? ColorTokens.Brand.primary : ColorTokens.Parent.inkMuted)
                    Text("\(day)")
                        .font(TypographyTokens.body(15).weight(isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? ColorTokens.Overlay.onAccent : ColorTokens.Parent.ink)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle().fill(isToday ? ColorTokens.Brand.primary : Color.clear)
                        )
                }
                .frame(maxWidth: .infinity)
                .accessibilityLabel(isToday
                    ? String(localized: "homeTasks.weekstrip.today", defaultValue: "Сегодня") + " \(day)"
                    : "\(abbr) \(day)")
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.vertical, SpacingTokens.small)
        .background(ColorTokens.Parent.surface)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.5)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarBadge: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if display.activeCount > 0 {
                HSBadge(
                    "\(display.activeCount)",
                    style: .filled(ColorTokens.Brand.gold)
                )
                .accessibilityLabel(String(
                    format: String(localized: "homeTasks.a11y.activeCount"),
                    display.activeCount
                ))
            }
        }
    }

    // MARK: - Filter chips

    private var filterChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.tiny) {
                ForEach(TaskFilter.allCases, id: \.self) { filter in
                    HomeTaskFilterChip(
                        title: filter.displayName,
                        count: counter(for: filter),
                        isActive: display.activeFilter == filter
                    ) {
                        handleFilterChange(filter)
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.vertical, SpacingTokens.small)
        }
        .background(ColorTokens.Parent.bg)
    }

    private func counter(for filter: TaskFilter) -> Int {
        switch filter {
        case .all:       return display.totalCount
        case .active:    return display.activeCount
        case .completed: return display.completedCount
        }
    }

    // MARK: - Tasks list (sectioned)

    private var tasksList: some View {
        ScrollView {
            LazyVStack(spacing: SpacingTokens.large, pinnedViews: []) {
                ForEach(display.sections) { section in
                    sectionView(section)
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.regular)
            .padding(.bottom, SpacingTokens.xxLarge)
            .animation(
                reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82),
                value: display.sections.map(\.id)
            )
        }
    }

    /// Заголовок секции + список карточек на «жидком стекле».
    /// Каждая карточка — `HSLiquidGlassCard(.elevated)`, чтобы карточки
    /// просматривались на фоне градиента.
    @ViewBuilder
    private func sectionView(_ section: HomeTaskSection) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            HStack(spacing: SpacingTokens.tiny) {
                Text(section.title)
                    .font(TypographyTokens.headline())
                    .foregroundStyle(ColorTokens.Parent.ink)
                if section.kind == .overdue, display.overdueCount > 0 {
                    HSBadge(
                        "\(display.overdueCount)",
                        style: .filled(ColorTokens.Semantic.error)
                    )
                    .accessibilityHidden(true)
                }
                Spacer(minLength: 0)
                // Count of tasks in this section — matches reference right-aligned count
                Text(String(
                    format: String(localized: "homeTasks.section.countFormat", defaultValue: "%lld задания"),
                    section.rows.count
                ))
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .accessibilityHidden(true)
            }
            .padding(.horizontal, SpacingTokens.tiny)
            .accessibilityAddTraits(.isHeader)

            VStack(spacing: SpacingTokens.listGap) {
                ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                    HomeTaskCard(
                        row: row,
                        reduceMotion: reduceMotion,
                        onToggle: { handleToggle(row.id) },
                        onOpen: { handleOpen(row.id) },
                        onStart: { handleStart(row.id) }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    // Block J v18 — kavsoft-style tilt carousel scroll transition.
                    .hsScrollEffect(.tiltCarousel)
                    .scrollTransition(.animated(reduceMotion ? .linear(duration: 0) : .spring(response: 0.5, dampingFraction: 0.85))) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0)
                            .scaleEffect(phase.isIdentity ? 1 : 0.94)
                    }
                    .hsParallaxTile(factor: 0.22)
                    .zIndex(Double(section.rows.count - index))
                }
            }
        }
    }

    // MARK: - Empty state

    /// G.1 v17 — HSEmptyStateView (mascot=celebrating, parent-контур).
    /// Маскот в celebrating-состоянии: «всё выполнено» — позитивная нота.
    private var emptyStateView: some View {
        HSEmptyStateView(
            mascot: .celebrating,
            title: display.emptyTitle,
            subtitle: display.emptyMessage,
            actionTitle: String(localized: "homeTasks.empty.cta"),
            action: { performRefresh() }
        )
    }

    // MARK: - Actions

    private func handleToggle(_ id: String) {
        container.hapticService.selection()
        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.75)) {
            interactor?.update(.init(taskId: id))
        }
    }

    private func handleOpen(_ id: String) {
        logger.info("open detail id=\(id, privacy: .public)")
        interactor?.fetchDetail(.init(taskId: id))
    }

    private func handleScheduleReminder(_ id: String) {
        container.hapticService.impact(.light)
        interactor?.scheduleReminder(.init(taskId: id))
    }

    private func handleStart(_ id: String) {
        container.hapticService.impact(.medium)
        interactor?.startTask(.init(taskId: id))
    }

    private func handleNotifyOverdue() {
        container.hapticService.impact(.light)
        interactor?.requestOverdueReminder(.init())
    }

    private func handleFilterChange(_ filter: TaskFilter) {
        guard display.activeFilter != filter else { return }
        container.hapticService.selection()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            interactor?.changeFilter(.init(filter: filter))
        }
    }

    private func performRefresh() {
        container.hapticService.impact(.light)
        interactor?.refresh(.init())
    }

    // MARK: - Bootstrap

    @MainActor
    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        let interactor = HomeTasksInteractor(
            notificationService: container.notificationService
        )
        let presenter = HomeTasksPresenter()
        let router = HomeTasksRouter()

        interactor.presenter = presenter
        interactor.gameRouter = router
        presenter.display = display
        router.onDismiss = onDismiss
        router.onOpenDetail = onOpenDetail
        router.onStartGame = onStartGame

        self.interactor = interactor
        self.presenter = presenter
        self.router = router

        interactor.fetch(.init(forceReload: true))
    }
}

// MARK: - HomeTaskFilterChip

/// Локальный chip-компонент для фильтров. В DesignSystem не выносим — будет в M7.3.
private struct HomeTaskFilterChip: View {

    let title: String
    let count: Int
    let isActive: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.micro) {
                Text(title)
                    .font(TypographyTokens.body(14).weight(.semibold))
                Text("\(count)")
                    .font(TypographyTokens.mono(12))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(
                            isActive
                                ? ColorTokens.Overlay.highlight
                                : ColorTokens.Parent.line.opacity(0.5)
                        )
                    )
            }
            .foregroundStyle(isActive ? ColorTokens.Overlay.onAccent : ColorTokens.Parent.inkMuted)
            .padding(.horizontal, SpacingTokens.regular)
            .padding(.vertical, SpacingTokens.small)
            .frame(minHeight: 44)
            .background(
                Capsule()
                    .fill(isActive ? ColorTokens.Parent.accent : ColorTokens.Parent.surface)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isActive ? Color.clear : ColorTokens.Parent.line,
                        lineWidth: 1
                    )
            )
            .scaleEffect(isPressed && !reduceMotion ? 0.96 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(
            reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.75),
            value: isPressed
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel(title)
        .accessibilityValue("\(count)")
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - HomeTaskCard

/// Карточка задания в parent-стиле, на «жидком стекле».
/// Слева — чекбокс «выполнено», в центре — заголовок/подзаголовок/мета,
/// снизу — кнопка «Начать»/«Продолжить»/«Повторить» (открывает шаблон игры).
/// Тап по карточке без кнопок — открыть детали.
private struct HomeTaskCard: View {

    let row: HomeTaskRow
    let reduceMotion: Bool
    let onToggle: () -> Void
    let onOpen: () -> Void
    let onStart: () -> Void

    var body: some View {
        // Reference: single row card — icon circle left, title+meta centre, status/CTA right.
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.regular) {
            HStack(alignment: .center, spacing: SpacingTokens.regular) {
                exerciseIcon
                centerContent
                trailingAction
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture { onOpen() }
        .opacity(row.isCompleted ? 0.72 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityHint(row.accessibilityHint)
    }

    // MARK: Left icon (exercise type in coral circle)

    private var exerciseIcon: some View {
        Image(systemName: exerciseSymbol)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .frame(width: 44, height: 44)
            .background(Circle().fill(ColorTokens.Brand.primary))
            .accessibilityHidden(true)
    }

    private var exerciseSymbol: String {
        switch row.exerciseType {
        case "breathing":              return "wind"
        case "articulation-imitation": return "mouth.fill"
        case "bingo":                  return "checkmark.square.fill"
        case "listen-and-choose":      return "ear.fill"
        case "sorting":                return "arrow.up.arrow.down.square.fill"
        case "story-completion":       return "book.fill"
        case "repeat-after-model":     return "mic.fill"
        case "minimal-pairs":          return "equal.square.fill"
        default:                       return "gamecontroller.fill"
        }
    }

    // MARK: Centre content (title + meta)

    private var centerContent: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.micro) {
            Text(row.title)
                .font(TypographyTokens.headline(15))
                .foregroundStyle(ColorTokens.Parent.ink)
                .strikethrough(row.isCompleted, color: ColorTokens.Parent.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
                .lineLimit(2)

            HStack(spacing: SpacingTokens.micro) {
                if !row.subtitle.isEmpty {
                    Text(row.subtitle)
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Parent.inkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                if let due = row.dueDateText {
                    if !row.subtitle.isEmpty {
                        Text("·")
                            .font(TypographyTokens.caption(11))
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                            .accessibilityHidden(true)
                    }
                    Image(systemName: row.isOverdue ? "exclamationmark.circle.fill" : "calendar")
                        .font(TypographyTokens.caption(10))
                        .foregroundStyle(row.isOverdue ? ColorTokens.Semantic.error : ColorTokens.Parent.inkSoft)
                        .accessibilityHidden(true)
                    Text(due)
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(row.isOverdue ? ColorTokens.Semantic.error : ColorTokens.Parent.inkSoft)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Trailing — status badge or start CTA

    @ViewBuilder
    private var trailingAction: some View {
        if row.isCompleted {
            // "Выполнено" badge — green pill (reference)
            HStack(spacing: SpacingTokens.micro) {
                Image(systemName: "checkmark")
                    .font(TypographyTokens.caption(10).weight(.bold))
                Text(row.startButtonTitle)
                    .font(TypographyTokens.caption(11).weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(ColorTokens.Semantic.success)
            .padding(.horizontal, SpacingTokens.small)
            .padding(.vertical, SpacingTokens.micro)
            .background(
                Capsule().fill(ColorTokens.Semantic.success.opacity(0.12))
            )
        } else {
            Button(action: onStart) {
                Text(row.startButtonTitle)
                    .font(TypographyTokens.body(13).weight(.semibold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, SpacingTokens.small)
                    .padding(.vertical, SpacingTokens.tiny)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.xs)
                            .fill(ColorTokens.Brand.primary.opacity(0.10))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(row.startButtonTitle)
            .accessibilityHint(String(localized: "homeTasks.a11y.startHint"))
        }
    }
}

// HomeTaskDetailSheet вынесен в HomeTaskDetailSheet.swift

// MARK: - Preview

#Preview("HomeTasks – Parent") {
    HomeTasksView()
        .environment(AppContainer.preview())
        .environment(\.circuitContext, .parent)
}
