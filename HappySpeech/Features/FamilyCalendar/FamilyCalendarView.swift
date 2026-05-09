import Charts
import OSLog
import SwiftUI

// MARK: - FamilyCalendarView
//
// Семейный календарь — агрегированная активность по детям семьи.
// Parent-контур. 6 секций: ChildrenStrip, WeekStrip, GoalCards, Heatmap, Comparison, Insights.
// VIP: View → Interactor (запросы) → Presenter (форматирование) → Display.
// Подкомпоненты вынесены в `FamilyCalendarViewComponents.swift`.

struct FamilyCalendarView: View {

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - VIP State

    @State private var scene: FamilyCalendarScene?
    @State private var viewModel: FamilyCalendarViewModel = .empty

    // MARK: - Local UI State

    @State private var showDayDetail = false
    @State private var showScheduleSheet = false
    @State private var showWeekSummarySheet = false
    @State private var selectedDayForSchedule: Date?
    @State private var voiceHintText: String?

    private var weeksCount: Int {
        horizontalSizeClass == .compact ? 8 : 12
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            ColorTokens.Parent.bg.ignoresSafeArea()

            if viewModel.isLoading {
                loadingView
            } else if viewModel.isEmpty {
                emptyView
            } else {
                mainContent
            }

            // Toast
            if let toast = viewModel.toastMessage {
                HSToast(toast, type: .success)
                    .padding(.bottom, SpacingTokens.large)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(2.4))
                        withAnimation(.easeInOut(duration: 0.25)) {
                            scene?.clearToast()
                        }
                    }
            }
        }
        .navigationTitle(String(localized: "family_calendar.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if let weekStart = viewModel.weekDays.first?.date {
                        Task {
                            scene?.interactor.generateWeekSummary(request: .init(weekStart: weekStart))
                        }
                        showWeekSummarySheet = true
                    }
                } label: {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .foregroundStyle(ColorTokens.Parent.inkSoft)
                }
                .accessibilityLabel(String(localized: "family_calendar.toolbar.week_summary"))
            }
        }
        .sheet(isPresented: $showDayDetail) {
            if let detail = viewModel.selectedDayDetail {
                DayDetailSheet(
                    detail: detail,
                    onSchedule: { date in
                        selectedDayForSchedule = date
                        showDayDetail = false
                        showScheduleSheet = true
                    }
                )
            }
        }
        .sheet(isPresented: $showScheduleSheet) {
            if let children = scene.map({ _ in viewModel.children.filter { !$0.isAll } }) {
                ScheduleLessonSheet(
                    date: selectedDayForSchedule ?? Date(),
                    children: children
                ) { childId, childName, date, template, reminder in
                    Task {
                        await scene?.interactor.scheduleLesson(request: .init(
                            childId: childId,
                            childName: childName,
                            date: date,
                            lessonTemplate: template,
                            enableReminder: reminder
                        ))
                    }
                }
            }
        }
        .sheet(isPresented: $showWeekSummarySheet) {
            if let summary = viewModel.weekSummary {
                WeekSummarySheet(summary: summary)
            }
        }
        .task {
            if scene == nil {
                let newScene = FamilyCalendarScene(
                    childRepository: container.childRepository,
                    sessionRepository: container.sessionRepository,
                    notificationService: container.notificationService,
                    llmDecisionService: container.llmDecisionService,
                    coordinator: coordinator
                )
                newScene.display = self
                scene = newScene
            }
            await scene?.interactor.loadFamilyData(request: .init(parentId: ""))
        }
        .environment(\.circuitContext, .parent)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: SpacingTokens.sectionGap) {
                childrenStrip
                weekStripSection
                weekGoalSection
                heatmapSection
                if viewModel.selectedChildId == nil && viewModel.comparisonCards.count >= 2 {
                    comparisonSection
                }
                insightsSection
            }
            .padding(.horizontal, SpacingTokens.regular)
            .padding(.vertical, SpacingTokens.large)
        }
    }

    // MARK: - Loading / Empty

    private var loadingView: some View {
        VStack(spacing: SpacingTokens.medium) {
            ProgressView()
                .tint(ColorTokens.Brand.primary)
                .scaleEffect(1.4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: SpacingTokens.xxLarge) {
            LyalyaMascotView(state: .pointing, size: 140)
                .accessibilityHidden(true)
            Text(String(localized: "family_calendar.empty.title"))
                .font(TypographyTokens.title())
                .foregroundStyle(ColorTokens.Parent.ink)
                .multilineTextAlignment(.center)
            Text(String(localized: "family_calendar.empty.subtitle"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, SpacingTokens.regular)
    }

    // MARK: - Section 1: ChildrenStrip

    private var childrenStrip: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.medium) {
            CalendarSectionHeader(title: String(localized: "family_calendar.children.title"))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SpacingTokens.medium) {
                    ForEach(viewModel.children) { child in
                        ChildAvatarCard(
                            child: child,
                            isSelected: child.isAll
                                ? viewModel.selectedChildId == nil
                                : viewModel.selectedChildId == child.id
                        ) {
                            let childId = child.isAll ? nil : child.id
                            let animation: Animation = reduceMotion
                                ? .easeInOut(duration: 0.15)
                                : MotionTokens.spring
                            _ = withAnimation(animation) {
                                Task { await scene?.interactor.selectChild(request: .init(childId: childId)) }
                            }
                        }
                    }
                    AddChildCapsule {
                        scene?.router.routeToAddChild()
                    }
                }
                .padding(.horizontal, SpacingTokens.regular)
                .padding(.vertical, 4)
            }
            .padding(.horizontal, -SpacingTokens.regular)
        }
    }

    // MARK: - Section 2: WeekStrip (±2 weeks navigation)

    private var weekStripSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.medium) {
            HStack {
                CalendarSectionHeader(title: weekRangeTitle)
                Spacer()
                weekNavigationButtons
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                ForEach(viewModel.weekDays) { day in
                    WeekDayCell(day: day) {
                        Task { scene?.interactor.selectDay(request: .init(date: day.date)) }
                        showDayDetail = true
                    } onLongPress: {
                        selectedDayForSchedule = day.date
                        showScheduleSheet = true
                    }
                }
            }
            .padding(SpacingTokens.sp4)
            .background(ColorTokens.Parent.surface)
            .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card))

            // Подсказка к планированию
            Text(String(localized: "family_calendar.week.schedule_hint"))
                .font(TypographyTokens.caption())
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var weekNavigationButtons: some View {
        HStack(spacing: SpacingTokens.tiny) {
            Button {
                let animation: Animation = reduceMotion
                    ? .easeInOut(duration: 0.15)
                    : MotionTokens.page
                withAnimation(animation) {
                    scene?.interactor.changeWeek(request: .init(direction: .previous))
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(TypographyTokens.labelRounded(14))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(String(localized: "family_calendar.week.previous"))

            Button {
                let animation: Animation = reduceMotion
                    ? .easeInOut(duration: 0.15)
                    : MotionTokens.page
                withAnimation(animation) {
                    scene?.interactor.changeWeek(request: .init(direction: .next))
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(TypographyTokens.labelRounded(14))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(String(localized: "family_calendar.week.next"))
        }
    }

    private var weekRangeTitle: String {
        guard let first = viewModel.weekDays.first, let last = viewModel.weekDays.last else {
            return String(localized: "family_calendar.week.title")
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        return "\(formatter.string(from: first.date)) – \(formatter.string(from: last.date))"
    }

    // MARK: - Section 3: WeekGoalCards

    private var weekGoalSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.medium) {
            CalendarSectionHeader(title: String(localized: "family_calendar.goals.title"))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SpacingTokens.medium) {
                    ForEach(viewModel.weekGoalCards) { card in
                        WeekGoalCard(card: card)
                    }
                }
                .padding(.horizontal, SpacingTokens.regular)
                .padding(.vertical, 4)
            }
            .padding(.horizontal, -SpacingTokens.regular)
        }
    }

    // MARK: - Section 4: HeatmapView

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.medium) {
            CalendarSectionHeader(title: String(localized: "family_calendar.heatmap.title"))

            HeatmapChartView(
                entries: viewModel.heatmapEntries,
                weeksCount: weeksCount
            ) { entry in
                Task { scene?.interactor.selectDay(request: .init(date: entry.date)) }
                showDayDetail = true
            }
            .padding(SpacingTokens.sp4)
            .background(ColorTokens.Parent.surface)
            .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card))
        }
    }

    // MARK: - Section 5: ComparisonCard

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.medium) {
            CalendarSectionHeader(title: String(localized: "family_calendar.comparison.title"))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: SpacingTokens.medium) {
                    ForEach(viewModel.comparisonCards) { card in
                        ChildSummaryCard(card: card)
                    }
                }
                .padding(.horizontal, SpacingTokens.regular)
                .padding(.vertical, 4)
            }
            .padding(.horizontal, -SpacingTokens.regular)
        }
    }

    // MARK: - Section 6: InsightsList

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.medium) {
            CalendarSectionHeader(title: String(localized: "family_calendar.insights.title"))

            VStack(alignment: .leading, spacing: 0) {
                if viewModel.isLoadingInsights {
                    HStack {
                        Spacer()
                        ProgressView()
                            .frame(height: 24)
                            .tint(ColorTokens.Brand.primary)
                        Spacer()
                    }
                    .padding(SpacingTokens.sp4)
                } else {
                    VStack(alignment: .leading, spacing: SpacingTokens.medium) {
                        ForEach(Array(viewModel.insights.enumerated()), id: \.element.id) { index, insight in
                            CalendarInsightRow(insight: insight)
                                .transition(.opacity)
                                .animation(
                                    reduceMotion
                                        ? .easeInOut(duration: 0.15)
                                        : MotionTokens.spring.delay(Double(index) * 0.05),
                                    value: viewModel.insights.map(\.id)
                                )
                        }
                    }
                    .padding(SpacingTokens.sp4)
                }
            }
            .background(ColorTokens.Parent.surface)
            .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card))
        }
    }

    // MARK: - Helpers

    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date).capitalized
    }
}

// MARK: - FamilyCalendarDisplayLogic

extension FamilyCalendarView: FamilyCalendarDisplayLogic {

    @MainActor
    func displayFamilyData(viewModel: FamilyCalendarViewModel) {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.15) : MotionTokens.spring) {
            self.viewModel = viewModel
        }
    }

    @MainActor
    func displayError(message: String) {
        viewModel.toastMessage = message
    }

    @MainActor
    func displayInsights(insights: [InsightItemViewModel]) {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.15) : MotionTokens.spring) {
            viewModel.insights = insights
            viewModel.isLoadingInsights = false
        }
    }

    @MainActor
    func displayDayDetail(viewModel: DayDetailViewModel) {
        self.viewModel.selectedDayDetail = viewModel
    }

    @MainActor
    func displayLoadingState(isLoading: Bool) {
        viewModel.isLoading = isLoading
    }

    @MainActor
    func displayInsightsLoading(isLoading: Bool) {
        viewModel.isLoadingInsights = isLoading
    }

    @MainActor
    func displayClearToast() {
        viewModel.toastMessage = nil
    }

    @MainActor
    func displayLessonScheduled(voiceHint: String) {
        voiceHintText = voiceHint
    }

    @MainActor
    func displayWeekSummary(viewModel: WeekSummaryViewModel) {
        self.viewModel.weekSummary = viewModel
    }

    @MainActor
    func displayToast(message: String) {
        withAnimation(.easeInOut(duration: 0.25)) {
            viewModel.toastMessage = message
        }
    }
}

// MARK: - FamilyCalendarScene (VIP container)

@MainActor
final class FamilyCalendarScene {
    let interactor: FamilyCalendarInteractor
    let presenter: FamilyCalendarPresenter
    let router: FamilyCalendarRouter

    var display: (any FamilyCalendarDisplayLogic)? {
        didSet { presenter.display = display }
    }

    init(
        childRepository: any ChildRepository,
        sessionRepository: any SessionRepository,
        notificationService: (any NotificationService)?,
        llmDecisionService: (any LLMDecisionServiceProtocol)?,
        coordinator: AppCoordinator
    ) {
        let presenter = FamilyCalendarPresenter()
        let interactor = FamilyCalendarInteractor(
            childRepository: childRepository,
            sessionRepository: sessionRepository,
            notificationService: notificationService,
            llmDecisionService: llmDecisionService
        )
        let router = FamilyCalendarRouter()
        router.coordinator = coordinator
        interactor.presenter = presenter
        interactor.router = router
        self.presenter = presenter
        self.interactor = interactor
        self.router = router
    }

    func clearToast() {
        display?.displayClearToast()
    }
}

// MARK: - Preview

#Preview("Family Calendar") {
    NavigationStack {
        FamilyCalendarView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
    }
}
