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
                backgroundGradient
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
            .sheet(isPresented: Binding(
                get: { display.isDetailSheetPresented },
                set: { if !$0 { display.dismissDetailSheet() } }
            )) {
                if let detail = display.detailViewModel {
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
        }
        .environment(\.circuitContext, .parent)
        .task { await bootstrap() }
    }

    // MARK: - Background

    /// Мягкий тёплый градиент через токены DesignSystem — `Brand.butter`
    /// (тёплый жёлтый) → `Parent.bg` (нейтральный фон). Соответствует
    /// родительскому контуру, но добавляет «домашнее» настроение для секции
    /// заданий.
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                ColorTokens.Brand.butter.opacity(0.35),
                ColorTokens.Parent.bg
            ],
            startPoint: .top,
            endPoint: .center
        )
    }

    /// Двусторонний binding для `.alert` — гасит prompt через
    /// `display.dismissOverduePrompt()` при отказе пользователя.
    private var overduePromptBinding: Binding<Bool> {
        Binding(
            get: { display.pendingOverduePrompt && display.overdueCount > 0 },
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
            HSLoadingView(message: String(localized: "homeTasks.loading"))
        } else {
            VStack(spacing: 0) {
                filterChipsBar
                if display.isEmpty {
                    emptyStateView
                } else {
                    tasksList
                }
            }
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
            }
            .padding(.horizontal, SpacingTokens.tiny)
            .accessibilityAddTraits(.isHeader)

            VStack(spacing: SpacingTokens.listGap) {
                ForEach(section.rows) { row in
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
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.cardPad) {
            VStack(alignment: .leading, spacing: SpacingTokens.regular) {
                topRow
                titleAndDescription
                metaRow
                startButton
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture { onOpen() }
        .opacity(row.isCompleted ? 0.75 : 1.0)
        .overlay(alignment: .topTrailing) {
            if row.isStarted, !row.isCompleted {
                inProgressIndicator
                    .padding(SpacingTokens.tiny)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityHint(row.accessibilityHint)
    }

    // MARK: Top row (checkbox + badges)

    private var topRow: some View {
        HStack(alignment: .top, spacing: SpacingTokens.regular) {
            checkboxButton
            VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                HStack(spacing: SpacingTokens.tiny) {
                    HSBadge(row.soundBadgeText, style: .filled(ColorTokens.Brand.primary))
                    HSBadge(row.priorityBadgeText, style: priorityBadgeStyle)
                    Spacer(minLength: 0)
                }
                if !row.subtitle.isEmpty {
                    Text(row.subtitle)
                        .font(TypographyTokens.caption())
                        .foregroundStyle(ColorTokens.Parent.inkSoft)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
            }
        }
    }

    private var checkboxButton: some View {
        Button(action: onToggle) {
            ZStack {
                Circle()
                    .fill(row.isCompleted ? ColorTokens.Semantic.success : Color.clear)
                    .frame(width: 28, height: 28)
                Circle()
                    .strokeBorder(
                        row.isCompleted
                            ? ColorTokens.Semantic.success
                            : ColorTokens.Parent.line,
                        lineWidth: 2
                    )
                    .frame(width: 28, height: 28)
                if row.isCompleted {
                    Image(systemName: "checkmark")
                        .font(TypographyTokens.caption(14))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                }
            }
            .frame(width: 44, height: 44, alignment: .topLeading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(row.isCompleted
                            ? String(localized: "homeTasks.a11y.checkboxOn")
                            : String(localized: "homeTasks.a11y.checkboxOff"))
        .accessibilityHint(row.isCompleted
                           ? String(localized: "homeTasks.a11y.hintReopen")
                           : String(localized: "homeTasks.a11y.hintComplete"))
        .accessibilityAddTraits(.isButton)
    }

    private var priorityBadgeStyle: HSBadge.BadgeStyle {
        switch row.priority {
        case .high:   return .outlined(ColorTokens.Semantic.error)
        case .medium: return .outlined(ColorTokens.Semantic.warning)
        case .low:    return .neutral
        }
    }

    // MARK: Title + description

    private var titleAndDescription: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.micro) {
            Text(row.title)
                .font(TypographyTokens.headline())
                .foregroundStyle(ColorTokens.Parent.ink)
                .strikethrough(row.isCompleted, color: ColorTokens.Parent.inkSoft)
                .lineLimit(2)
                .minimumScaleFactor(0.9)

            Text(row.description)
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineLimit(3)
                .lineSpacing(3)
        }
    }

    // MARK: Meta (due date)

    @ViewBuilder
    private var metaRow: some View {
        if let due = row.dueDateText {
            HStack(spacing: SpacingTokens.micro) {
                Image(systemName: row.isOverdue ? "exclamationmark.circle.fill" : "calendar")
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(row.isOverdue
                                     ? ColorTokens.Semantic.error
                                     : ColorTokens.Parent.inkSoft)
                Text(due)
                    .font(TypographyTokens.caption())
                    .foregroundStyle(row.isOverdue
                                     ? ColorTokens.Semantic.error
                                     : ColorTokens.Parent.inkSoft)
            }
            .accessibilityLabel(due)
        }
    }

    // MARK: Start button

    @ViewBuilder
    private var startButton: some View {
        if !row.isCompleted {
            HSButton(
                row.startButtonTitle,
                style: .primary,
                size: .medium,
                icon: "play.fill"
            ) {
                onStart()
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel(row.startButtonTitle)
            .accessibilityHint(String(localized: "homeTasks.a11y.startHint"))
        } else {
            HSButton(
                row.startButtonTitle,
                style: .secondary,
                size: .medium,
                icon: "arrow.clockwise"
            ) {
                onStart()
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel(row.startButtonTitle)
            .accessibilityHint(String(localized: "homeTasks.a11y.repeatHint"))
        }
    }

    // MARK: In-progress indicator

    private var inProgressIndicator: some View {
        HStack(spacing: SpacingTokens.micro) {
            Circle()
                .fill(ColorTokens.Brand.gold)
                .frame(width: 6, height: 6)
            Text(String(localized: "homeTasks.indicator.inProgress"))
                .font(TypographyTokens.caption())
                .foregroundStyle(ColorTokens.Brand.gold)
        }
        .padding(.horizontal, SpacingTokens.tiny)
        .padding(.vertical, 2)
        .background(
            Capsule().fill(ColorTokens.Brand.gold.opacity(0.15))
        )
    }
}

// HomeTaskDetailSheet вынесен в HomeTaskDetailSheet.swift

// MARK: - Preview

#Preview("HomeTasks – Parent") {
    HomeTasksView()
        .environment(AppContainer.preview())
        .environment(\.circuitContext, .parent)
}
