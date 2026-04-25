import SwiftUI
import OSLog

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

    private let logger = Logger(subsystem: "ru.happyspeech", category: "HomeTasksView")

    // MARK: - Init

    init(
        onDismiss: (() -> Void)? = nil,
        onOpenDetail: ((String) -> Void)? = nil
    ) {
        self.onDismiss = onDismiss
        self.onOpenDetail = onOpenDetail
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ColorTokens.Parent.bg.ignoresSafeArea()

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
        }
        .environment(\.circuitContext, .parent)
        .task { await bootstrap() }
    }

    // MARK: - Content switch

    @ViewBuilder
    private var content: some View {
        if display.isLoading && display.visibleTasks.isEmpty {
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

    // MARK: - Tasks list

    private var tasksList: some View {
        ScrollView {
            LazyVStack(spacing: SpacingTokens.listGap) {
                ForEach(Array(display.visibleTasks.enumerated()), id: \.element.id) { index, row in
                    HomeTaskCard(
                        row: row,
                        reduceMotion: reduceMotion,
                        onToggle: { handleToggle(row.id) },
                        onOpen: { handleOpen(row.id) }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(
                        reduceMotion
                            ? nil
                            : .spring(response: 0.45, dampingFraction: 0.78).delay(Double(index) * 0.03),
                        value: display.activeFilter
                    )
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.regular)
            .padding(.bottom, SpacingTokens.xxLarge)
        }
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer(minLength: SpacingTokens.xLarge)

            Text(verbatim: "🦋")
                .font(.system(size: 96))
                .accessibilityHidden(true)
                .scaleEffect(reduceMotion ? 1 : 1.05)
                .animation(
                    reduceMotion
                        ? nil
                        : .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                    value: display.isEmpty
                )

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
                String(localized: "homeTasks.empty.cta"),
                style: .secondary,
                size: .medium,
                icon: "arrow.clockwise"
            ) {
                performRefresh()
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

    private func handleToggle(_ id: String) {
        container.hapticService.selection()
        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.75)) {
            interactor?.update(.init(taskId: id))
        }
    }

    private func handleOpen(_ id: String) {
        logger.info("open detail id=\(id, privacy: .public)")
        router?.routeOpenDetail(taskId: id)
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

        let interactor = HomeTasksInteractor()
        let presenter = HomeTasksPresenter()
        let router = HomeTasksRouter()

        interactor.presenter = presenter
        presenter.display = display
        router.onDismiss = onDismiss
        router.onOpenDetail = onOpenDetail

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
                                ? Color.white.opacity(0.25)
                                : ColorTokens.Parent.line.opacity(0.5)
                        )
                    )
            }
            .foregroundStyle(isActive ? Color.white : ColorTokens.Parent.inkMuted)
            .padding(.horizontal, SpacingTokens.regular)
            .padding(.vertical, SpacingTokens.small)
            .frame(minHeight: 36)
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

/// Карточка задания в parent-стиле. Иконка-чекбокс слева, контент в центре,
/// chevron справа открывает детали.
private struct HomeTaskCard: View {

    let row: HomeTaskRow
    let reduceMotion: Bool
    let onToggle: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HSCard(style: .elevated, padding: 0) {
            HStack(alignment: .top, spacing: SpacingTokens.regular) {
                checkboxButton

                VStack(alignment: .leading, spacing: SpacingTokens.small) {
                    headerRow
                    titleAndDescription
                    metaRow
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.cardPad)
            .contentShape(Rectangle())
            .onTapGesture { onOpen() }
        }
        .opacity(row.isCompleted ? 0.7 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityHint(row.accessibilityHint)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Checkbox

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
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 44, height: 44, alignment: .topLeading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(row.isCompleted
                            ? String(localized: "homeTasks.a11y.checkboxOn")
                            : String(localized: "homeTasks.a11y.checkboxOff"))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Header (badges)

    private var headerRow: some View {
        HStack(spacing: SpacingTokens.tiny) {
            HSBadge(row.soundBadgeText, style: .filled(ColorTokens.Brand.primary))
            HSBadge(row.priorityBadgeText, style: priorityBadgeStyle)
            Spacer(minLength: 0)
        }
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
                    .font(.system(size: 12, weight: .medium))
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
}

// MARK: - Preview

#Preview("HomeTasks – Parent") {
    HomeTasksView()
        .environment(AppContainer.preview())
        .environment(\.circuitContext, .parent)
}
