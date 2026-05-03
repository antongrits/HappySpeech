import Charts
import OSLog
import SwiftUI

// MARK: - FamilyCalendarView
//
// Семейный календарь — агрегированная активность по детям семьи.
// Parent-контур. 6 секций: ChildrenStrip, WeekStrip, GoalCards, Heatmap, Comparison, Insights.
// VIP: View → Interactor (запросы) → Presenter (форматирование) → Display.

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
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 56))
                .foregroundStyle(ColorTokens.Parent.inkSoft)
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
            SectionHeader(title: String(localized: "family_calendar.children.title"))

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
                            withAnimation(animation) {
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
                SectionHeader(title: weekRangeTitle)
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(width: 36, height: 36)
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(width: 36, height: 36)
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
            SectionHeader(title: String(localized: "family_calendar.goals.title"))

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
            SectionHeader(title: String(localized: "family_calendar.heatmap.title"))

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
            SectionHeader(title: String(localized: "family_calendar.comparison.title"))

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
            SectionHeader(title: String(localized: "family_calendar.insights.title"))

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
                            InsightRow(insight: insight)
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

// MARK: - ChildAvatarCard

private struct ChildAvatarCard: View {
    let child: ChildAvatarViewModel
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: SpacingTokens.tiny) {
                ZStack {
                    Circle()
                        .fill(ColorTokens.Brand.primary.opacity(0.12))
                        .frame(width: 56, height: 56)
                    if child.isAll {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(ColorTokens.Brand.primary)
                    } else {
                        Text(child.initials)
                            .font(TypographyTokens.headline())
                            .foregroundStyle(ColorTokens.Brand.primary)
                    }
                }
                .overlay(
                    Circle()
                        .strokeBorder(isSelected ? ColorTokens.Brand.primary : Color.clear, lineWidth: 2)
                )

                Text(child.name)
                    .font(TypographyTokens.caption())
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: 80)
                    .multilineTextAlignment(.center)

                if child.streak > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.Brand.primary)
                        Text("\(child.streak)д")
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }
                } else {
                    Spacer().frame(height: 14)
                }
            }
            .frame(width: 80, height: 100)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(isSelected ? ColorTokens.Brand.primary.opacity(0.08) : ColorTokens.Parent.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .strokeBorder(isSelected ? ColorTokens.Brand.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            child.isAll
                ? String(localized: "family_calendar.children.all")
                : String(format: String(localized: "family_calendar.a11y.child_card"), child.name, child.streak)
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - AddChildCapsule

private struct AddChildCapsule: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: SpacingTokens.tiny) {
                ZStack {
                    Circle()
                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                        .foregroundStyle(ColorTokens.Parent.inkSoft)
                        .frame(width: 56, height: 56)
                    Image(systemName: "plus.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                }
                Text(String(localized: "family_calendar.children.add"))
                    .font(TypographyTokens.caption())
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: 80)
                    .multilineTextAlignment(.center)
                Spacer().frame(height: 14)
            }
            .frame(width: 80, height: 100)
            .background(RoundedRectangle(cornerRadius: RadiusTokens.card).fill(ColorTokens.Parent.surface))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "family_calendar.children.add"))
    }
}

// MARK: - WeekDayCell

private struct WeekDayCell: View {
    let day: WeekDayViewModel
    let onTap: () -> Void
    let onLongPress: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.hapticService) private var hapticService

    private var bgColor: Color {
        if day.isToday { return ColorTokens.Brand.primary }
        if day.isFuture { return ColorTokens.Parent.surface.opacity(0.5) }
        switch day.activityLevel {
        case 1: return ColorTokens.Brand.primary.opacity(0.15)
        case 2: return ColorTokens.Brand.primary.opacity(0.35)
        case 3: return ColorTokens.Brand.primary.opacity(0.60)
        default: return ColorTokens.Parent.surface
        }
    }

    private var textColor: Color {
        day.isToday ? .white : (day.isFuture ? ColorTokens.Parent.inkSoft.opacity(0.4) : ColorTokens.Parent.ink)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(day.weekdayShort)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(day.isToday ? .white.opacity(0.8) : ColorTokens.Parent.inkMuted)
                    .minimumScaleFactor(0.7)

                Text("\(day.dayNumber)")
                    .font(TypographyTokens.caption())
                    .foregroundStyle(textColor)
                    .minimumScaleFactor(0.7)

                // Индикатор сессий и планов
                HStack(spacing: 2) {
                    if day.sessionCount > 0 {
                        Circle()
                            .fill(day.isToday ? .white : ColorTokens.Brand.primary)
                            .frame(width: 4, height: 4)
                    }
                    if day.plannedCount > 0 {
                        Circle()
                            .fill(day.isToday ? .white.opacity(0.7) : ColorTokens.Semantic.warning)
                            .frame(width: 4, height: 4)
                    }
                    if day.hasSpecialistVisit {
                        Circle()
                            .fill(day.isToday ? .white.opacity(0.7) : ColorTokens.Semantic.success)
                            .frame(width: 4, height: 4)
                    }
                    if day.sessionCount == 0 && day.plannedCount == 0 && !day.hasSpecialistVisit {
                        Spacer().frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(RoundedRectangle(cornerRadius: RadiusTokens.sm).fill(bgColor))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0.5) {
            if !reduceMotion {
                hapticService.impact(.medium)
            }
            onLongPress()
        }
        .accessibilityLabel(weekDayCellA11yLabel)
        .accessibilityHint(day.isFuture ? String(localized: "family_calendar.a11y.future_day_hint") : "")
    }

    private var weekDayCellA11yLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        let dateStr = formatter.string(from: day.date)
        var parts: [String] = [dateStr]
        if day.sessionCount > 0 {
            parts.append(String(format: String(localized: "family_calendar.a11y.sessions_count"), day.sessionCount))
        }
        if day.plannedCount > 0 {
            parts.append(String(format: String(localized: "family_calendar.a11y.plans_count"), day.plannedCount))
        }
        if day.hasSpecialistVisit {
            parts.append(String(localized: "family_calendar.a11y.specialist_visit"))
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - WeekGoalCard

private struct WeekGoalCard: View {
    let card: WeekGoalCardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            HStack(spacing: SpacingTokens.small) {
                ZStack {
                    Circle()
                        .fill(ColorTokens.Brand.primary.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Text(card.initials)
                        .font(TypographyTokens.caption())
                        .foregroundStyle(ColorTokens.Brand.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.childName)
                        .font(TypographyTokens.headline())
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(1)
                    if card.streakDays > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(ColorTokens.Brand.primary)
                            Text("\(card.streakDays)д")
                                .font(.system(size: 10))
                                .foregroundStyle(ColorTokens.Parent.inkMuted)
                        }
                    }
                }
                Spacer()
                if card.goalReached {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ColorTokens.Semantic.success)
                        .accessibilityLabel(String(localized: "family_calendar.a11y.goal_reached"))
                }
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(ColorTokens.Parent.inkSoft.opacity(0.15))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(card.goalReached ? ColorTokens.Semantic.success : ColorTokens.Brand.primary)
                            .frame(width: geo.size.width * card.progressFraction, height: 6)
                    }
                }
                .frame(height: 6)

                Text(String(format: String(localized: "family_calendar.goals.progress_format"),
                            card.sessionsAchieved, card.sessionsGoal))
                    .font(TypographyTokens.caption())
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
            }
        }
        .padding(SpacingTokens.medium)
        .frame(width: 160)
        .background(ColorTokens.Parent.surface)
        .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card))
        .shadow(color: ColorTokens.Parent.inkSoft.opacity(0.2), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: String(localized: "family_calendar.a11y.goal_card"),
                                   card.childName, card.sessionsAchieved, card.sessionsGoal))
    }
}

// MARK: - DayCell (для heatmap совместимости)

private struct DayCell: View {
    let day: CalendarDayViewModel
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var textColor: Color {
        if day.isToday { return .white }
        if !day.isCurrentMonth { return ColorTokens.Parent.inkSoft.opacity(0.4) }
        if day.isFuture { return ColorTokens.Parent.inkSoft.opacity(0.35) }
        return ColorTokens.Parent.ink
    }

    private var dotColor: Color? {
        guard !day.isFuture else { return nil }
        switch day.activityLevel {
        case 1: return ColorTokens.Brand.primary.opacity(0.35)
        case 2: return ColorTokens.Brand.primary.opacity(0.65)
        case 3, 4: return ColorTokens.Brand.primary
        default: return nil
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                ZStack {
                    if day.isToday {
                        Circle().fill(ColorTokens.Brand.primary).frame(width: 32, height: 32)
                    }
                    Text("\(day.dayNumber)")
                        .font(TypographyTokens.caption())
                        .foregroundStyle(textColor)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 32, height: 32)

                if let dot = dotColor {
                    Circle().fill(dot).frame(width: 5, height: 5)
                } else {
                    Spacer().frame(height: 5)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dayCellA11yLabel)
    }

    private var dayCellA11yLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        let dateStr = formatter.string(from: day.date)
        if day.isToday {
            return "\(dateStr): \(day.sessionCount) " + String(localized: "family_calendar.a11y.today")
        }
        return String(format: String(localized: "family_calendar.a11y.calendar_cell"), dateStr, day.sessionCount)
    }
}

// MARK: - HeatmapChartView

private struct HeatmapChartView: View {
    let entries: [HeatmapEntryViewModel]
    let weeksCount: Int
    let onTapEntry: (HeatmapEntryViewModel) -> Void

    private func heatColor(_ count: Int) -> Color {
        switch count {
        case 0:     return ColorTokens.Parent.surface
        case 1:     return ColorTokens.Brand.primary.opacity(0.15)
        case 2...3: return ColorTokens.Brand.primary.opacity(0.35)
        case 4...6: return ColorTokens.Brand.primary.opacity(0.60)
        default:    return ColorTokens.Brand.primary
        }
    }

    var body: some View {
        Chart(entries) { entry in
            RectangleMark(
                x: .value(String(localized: "family_calendar.heatmap.week_label"), entry.weekIndex),
                y: .value(String(localized: "family_calendar.heatmap.day_label"), entry.weekday)
            )
            .foregroundStyle(heatColor(entry.sessionCount))
            .cornerRadius(3)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0))
                AxisValueLabel {
                    if let idx = value.as(Int.self) {
                        let label = idx == weeksCount - 1
                            ? String(localized: "family_calendar.heatmap.now")
                            : "-\(weeksCount - 1 - idx)н"
                        Text(label)
                            .font(TypographyTokens.caption())
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0))
                AxisValueLabel {
                    if let day = value.as(Int.self) {
                        Text(weekdayShort(day))
                            .font(TypographyTokens.caption())
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }
                }
            }
        }
        .frame(height: 120)
        .chartOverlay { proxy in
            GeometryReader { _ in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        if let (weekIdx, dayIdx) = proxy.value(at: location, as: (Int, Int).self),
                           let entry = entries.first(where: { $0.weekIndex == weekIdx && $0.weekday == dayIdx }) {
                            onTapEntry(entry)
                        }
                    }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "family_calendar.heatmap.title"))
    }

    private func weekdayShort(_ index: Int) -> String {
        let keys = [
            "family_calendar.heatmap.day_mon",
            "family_calendar.heatmap.day_tue",
            "family_calendar.heatmap.day_wed",
            "family_calendar.heatmap.day_thu",
            "family_calendar.heatmap.day_fri",
            "family_calendar.heatmap.day_sat",
            "family_calendar.heatmap.day_sun"
        ]
        guard index >= 0 && index < keys.count else { return "" }
        return String(localized: String.LocalizationValue(keys[index]))
    }
}

// MARK: - ChildSummaryCard

private struct ChildSummaryCard: View {
    let card: ChildSummaryViewModel

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var cardWidth: CGFloat { horizontalSizeClass == .compact ? 140 : 160 }
    private var cardHeight: CGFloat { horizontalSizeClass == .compact ? 180 : 200 }

    var body: some View {
        VStack(spacing: SpacingTokens.medium) {
            ZStack {
                Circle()
                    .fill(ColorTokens.Brand.primary.opacity(0.12))
                    .frame(width: 56, height: 56)
                Text(card.initials)
                    .font(TypographyTokens.headline())
                    .foregroundStyle(ColorTokens.Brand.primary)
            }
            Text(card.name)
                .font(TypographyTokens.headline())
                .foregroundStyle(ColorTokens.Parent.ink)
                .lineLimit(1)
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.Brand.gold)
                Text("\(card.bestSound) (\(Int(card.bestSoundRate * 100))%)")
                    .font(TypographyTokens.caption())
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(1)
            }
            if let delta = card.comparisonDelta {
                let pct = Int(abs(delta) * 100)
                let text = String(format: String(localized: "family_calendar.comparison.format"),
                                  card.name, card.bestSound, pct)
                Text(text)
                    .font(TypographyTokens.caption())
                    .foregroundStyle(delta >= 0 ? ColorTokens.Semantic.success : ColorTokens.Semantic.error)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(SpacingTokens.medium)
        .frame(width: cardWidth, height: cardHeight)
        .background(ColorTokens.Parent.surface)
        .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card))
        .shadow(color: ColorTokens.Parent.inkSoft.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

// MARK: - InsightRow

private struct InsightRow: View {
    let insight: InsightItemViewModel

    var body: some View {
        HStack(spacing: SpacingTokens.medium) {
            Image(systemName: insight.iconName)
                .font(.system(size: 20))
                .foregroundStyle(ColorTokens.Brand.primary)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(insight.text)
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Parent.ink)
                .lineLimit(nil)
                .ctaTextStyle()
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - SectionHeader

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(TypographyTokens.title())
            .foregroundStyle(ColorTokens.Parent.ink)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - DayDetailSheet

private struct DayDetailSheet: View {
    let detail: DayDetailViewModel
    let onSchedule: (Date) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.large) {
                    if detail.isEmpty {
                        Text(String(localized: "family_calendar.detail.empty"))
                            .font(TypographyTokens.body())
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(SpacingTokens.large)
                    }

                    // Прошедшие сессии
                    if !detail.sessionItems.isEmpty {
                        VStack(alignment: .leading, spacing: SpacingTokens.small) {
                            Text(String(localized: "family_calendar.detail.sessions_header"))
                                .font(TypographyTokens.headline())
                                .foregroundStyle(ColorTokens.Parent.ink)
                                .accessibilityAddTraits(.isHeader)

                            ForEach(detail.sessionItems) { item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.childName)
                                            .font(TypographyTokens.headline())
                                            .foregroundStyle(ColorTokens.Parent.ink)
                                        Text(String(format: String(localized: "family_calendar.detail.day_format"),
                                                    item.childName, item.sessionCount, item.accuracyPercent))
                                            .font(TypographyTokens.body())
                                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                                    }
                                    Spacer()
                                    Text("\(item.accuracyPercent)%")
                                        .font(TypographyTokens.headline())
                                        .foregroundStyle(item.accuracyPercent >= 70
                                            ? ColorTokens.Semantic.success : ColorTokens.Semantic.warning)
                                }
                                .padding(SpacingTokens.medium)
                                .background(ColorTokens.Parent.surface)
                                .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card))
                            }
                        }
                        .padding(.horizontal, SpacingTokens.regular)
                    }

                    // Запланированные уроки
                    if !detail.dayPlans.isEmpty {
                        VStack(alignment: .leading, spacing: SpacingTokens.small) {
                            Text(String(localized: "family_calendar.detail.plans_header"))
                                .font(TypographyTokens.headline())
                                .foregroundStyle(ColorTokens.Parent.ink)
                                .accessibilityAddTraits(.isHeader)

                            ForEach(detail.dayPlans) { plan in
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .foregroundStyle(ColorTokens.Semantic.warning)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(plan.childName)
                                            .font(TypographyTokens.headline())
                                            .foregroundStyle(ColorTokens.Parent.ink)
                                        Text("\(plan.lessonTemplate) • \(plan.timeText)")
                                            .font(TypographyTokens.caption())
                                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                                    }
                                    Spacer()
                                }
                                .padding(SpacingTokens.medium)
                                .background(ColorTokens.Semantic.warning.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card))
                            }
                        }
                        .padding(.horizontal, SpacingTokens.regular)
                    }

                    // Визит к специалисту
                    if let visit = detail.specialistVisit {
                        VStack(alignment: .leading, spacing: SpacingTokens.small) {
                            Text(String(localized: "family_calendar.detail.visit_header"))
                                .font(TypographyTokens.headline())
                                .foregroundStyle(ColorTokens.Parent.ink)
                                .accessibilityAddTraits(.isHeader)

                            HStack {
                                Image(systemName: "stethoscope")
                                    .foregroundStyle(ColorTokens.Semantic.success)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(visit.specialistName)
                                        .font(TypographyTokens.headline())
                                        .foregroundStyle(ColorTokens.Parent.ink)
                                    if !visit.notes.isEmpty {
                                        Text(visit.notes)
                                            .font(TypographyTokens.caption())
                                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                                    }
                                }
                                Spacer()
                            }
                            .padding(SpacingTokens.medium)
                            .background(ColorTokens.Semantic.success.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card))
                        }
                        .padding(.horizontal, SpacingTokens.regular)
                    }

                    // Кнопка добавить урок
                    HSButton(String(localized: "family_calendar.detail.schedule_button"), style: .secondary) {
                        onSchedule(detail.date)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .padding(.horizontal, SpacingTokens.regular)
                }
                .padding(.vertical, SpacingTokens.large)
            }
            .navigationTitle(detail.dateText)
            .navigationBarTitleDisplayMode(.inline)
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - ScheduleLessonSheet

private struct ScheduleLessonSheet: View {
    let date: Date
    let children: [ChildAvatarViewModel]
    let onConfirm: (String, String, Date, String, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedChildIdx = 0
    @State private var selectedTemplate = "repeat-after-model"
    @State private var reminderEnabled = true
    @State private var selectedTime: Date

    private let templates = [
        "repeat-after-model",
        "listen-and-choose",
        "drag-and-match",
        "sound-hunter",
        "articulation-imitation"
    ]

    init(date: Date, children: [ChildAvatarViewModel], onConfirm: @escaping (String, String, Date, String, Bool) -> Void) {
        self.date = date
        self.children = children
        self.onConfirm = onConfirm
        _selectedTime = State(initialValue: date)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "family_calendar.schedule.child_section")) {
                    if !children.isEmpty {
                        Picker(String(localized: "family_calendar.schedule.child_picker"), selection: $selectedChildIdx) {
                            ForEach(0..<children.count, id: \.self) { idx in
                                Text(children[idx].name).tag(idx)
                            }
                        }
                        .pickerStyle(.menu)
                    } else {
                        Text(String(localized: "family_calendar.schedule.no_children"))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }
                }

                Section(String(localized: "family_calendar.schedule.template_section")) {
                    Picker(String(localized: "family_calendar.schedule.template_picker"), selection: $selectedTemplate) {
                        ForEach(templates, id: \.self) { tpl in
                            Text(tpl).tag(tpl)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(String(localized: "family_calendar.schedule.time_section")) {
                    DatePicker(
                        String(localized: "family_calendar.schedule.time_label"),
                        selection: $selectedTime,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .environment(\.locale, Locale(identifier: "ru_RU"))
                }

                Section {
                    Toggle(String(localized: "family_calendar.schedule.reminder_toggle"), isOn: $reminderEnabled)
                }
            }
            .scrollContentBackground(.hidden)
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
            .navigationTitle(String(localized: "family_calendar.schedule.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "common.cancel")) { dismiss() }
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "common.save")) {
                        guard !children.isEmpty else { return }
                        let child = children[selectedChildIdx]
                        onConfirm(child.id, child.name, selectedTime, selectedTemplate, reminderEnabled)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .disabled(children.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - WeekSummarySheet

private struct WeekSummarySheet: View {
    let summary: WeekSummaryViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.large) {
                    // Заголовок с итогами
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(summary.weekRangeText)
                                .font(TypographyTokens.caption())
                                .foregroundStyle(ColorTokens.Parent.inkMuted)
                            Text(String(format: String(localized: "family_calendar.week_summary.total_sessions"),
                                        summary.familyTotalSessions))
                                .font(TypographyTokens.headline())
                                .foregroundStyle(ColorTokens.Parent.ink)
                        }
                        Spacer()
                        if summary.allGoalsReached {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(ColorTokens.Brand.gold)
                                .accessibilityLabel(String(localized: "family_calendar.week_summary.all_goals_reached"))
                        }
                    }
                    .padding(.horizontal, SpacingTokens.regular)

                    // Строки по детям
                    VStack(spacing: SpacingTokens.small) {
                        ForEach(summary.childRows) { row in
                            WeekSummaryRow(row: row)
                        }
                    }
                    .padding(.horizontal, SpacingTokens.regular)
                }
                .padding(.vertical, SpacingTokens.large)
            }
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
            .navigationTitle(String(localized: "family_calendar.week_summary.title"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct WeekSummaryRow: View {
    let row: WeekSummaryRowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            HStack {
                ZStack {
                    Circle()
                        .fill(ColorTokens.Brand.primary.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Text(row.initials)
                        .font(TypographyTokens.caption())
                        .foregroundStyle(ColorTokens.Brand.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.childName)
                        .font(TypographyTokens.headline())
                        .foregroundStyle(ColorTokens.Parent.ink)
                    Text("\(row.sessionsText) • \(row.durationText) • \(row.accuracyPercent)%")
                        .font(TypographyTokens.caption())
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(nil)
                }
                Spacer()
                if row.goalReached {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(ColorTokens.Semantic.success)
                        .accessibilityLabel(String(localized: "family_calendar.a11y.goal_reached"))
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ColorTokens.Parent.inkSoft.opacity(0.15))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(row.goalReached ? ColorTokens.Semantic.success : ColorTokens.Brand.primary)
                        .frame(width: geo.size.width * row.progressFraction, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(SpacingTokens.medium)
        .background(ColorTokens.Parent.surface)
        .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card))
        .accessibilityElement(children: .combine)
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
