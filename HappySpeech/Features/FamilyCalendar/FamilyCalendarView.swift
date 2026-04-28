import Charts
import OSLog
import SwiftUI

// MARK: - FamilyCalendarView
//
// Семейный календарь — агрегированная активность по детям семьи.
// Parent-контур. 5 секций: ChildrenStrip, MonthCalendar, Heatmap, Comparison, Insights.
// VIP: View → Interactor (запросы) → Presenter (форматирование) → Display.

struct FamilyCalendarView: View {

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - VIP State (ViewModel + Scene)

    @State private var scene: FamilyCalendarScene?
    @State private var viewModel: FamilyCalendarViewModel = .empty

    // MARK: - Local UI State

    @State private var showDayDetail = false
    @State private var isNextMonth = false

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
                HSToast(toast, type: .error)
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
                    // Зарезервировано для фильтра (F3 scope)
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundStyle(ColorTokens.Parent.inkSoft)
                }
                .accessibilityLabel(String(localized: "family_calendar.filter.label"))
            }
        }
        .sheet(isPresented: $showDayDetail) {
            if let detail = viewModel.selectedDayDetail {
                DayDetailSheet(detail: detail)
            }
        }
        .task {
            if scene == nil {
                let newScene = FamilyCalendarScene(
                    childRepository: container.childRepository,
                    sessionRepository: container.sessionRepository,
                    llmDecisionService: container.llmDecisionService,
                    coordinator: coordinator
                )
                newScene.display = self
                scene = newScene
            }
            await scene?.interactor.loadFamilyData(
                request: .init(parentId: "")
            )
        }
        .environment(\.circuitContext, .parent)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: SpacingTokens.sectionGap) {
                childrenStrip
                monthCalendarSection
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

    // MARK: - Section 2: MonthCalendar

    private var monthCalendarSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.medium) {
            SectionHeader(title: String(localized: "family_calendar.month.label"))

            VStack(spacing: SpacingTokens.medium) {
                // Month navigation header
                monthNavigationHeader

                // Weekday labels
                weekdayLabels

                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                    ForEach(viewModel.calendarDays) { dayVM in
                        DayCell(day: dayVM) {
                            Task { scene?.interactor.selectDay(request: .init(date: dayVM.date)) }
                            showDayDetail = true
                        }
                    }
                }
            }
            .padding(SpacingTokens.sp4)
            .background(ColorTokens.Parent.surface)
            .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card))
        }
    }

    private var monthNavigationHeader: some View {
        HStack {
            Button {
                let animation: Animation = reduceMotion
                    ? .easeInOut(duration: 0.15)
                    : MotionTokens.page
                isNextMonth = false
                withAnimation(animation) {
                    scene?.interactor.changeMonth(request: .init(direction: .previous))
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(String(localized: "family_calendar.month.previous"))

            Spacer()

            Text(monthYearString(viewModel.currentMonth))
                .font(TypographyTokens.headline())
                .foregroundStyle(ColorTokens.Parent.ink)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Button {
                let animation: Animation = reduceMotion
                    ? .easeInOut(duration: 0.15)
                    : MotionTokens.page
                isNextMonth = true
                withAnimation(animation) {
                    scene?.interactor.changeMonth(request: .init(direction: .next))
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(String(localized: "family_calendar.month.next"))
        }
    }

    private var weekdayLabels: some View {
        let days = [
            String(localized: "family_calendar.heatmap.day_mon"),
            String(localized: "family_calendar.heatmap.day_tue"),
            String(localized: "family_calendar.heatmap.day_wed"),
            String(localized: "family_calendar.heatmap.day_thu"),
            String(localized: "family_calendar.heatmap.day_fri"),
            String(localized: "family_calendar.heatmap.day_sat"),
            String(localized: "family_calendar.heatmap.day_sun")
        ]
        return HStack {
            ForEach(days, id: \.self) { day in
                Text(day)
                    .font(TypographyTokens.caption())
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Section 3: HeatmapView

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

    // MARK: - Section 4: ComparisonCard

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

            HSButton(String(localized: "family_calendar.cta.compare_all"), style: .secondary) {
                // Зарезервировано для drill-down экрана
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
    }

    // MARK: - Section 5: InsightsList

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
        llmDecisionService: (any LLMDecisionServiceProtocol)?,
        coordinator: AppCoordinator
    ) {
        let presenter = FamilyCalendarPresenter()
        let interactor = FamilyCalendarInteractor(
            childRepository: childRepository,
            sessionRepository: sessionRepository,
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
                        .strokeBorder(
                            isSelected ? ColorTokens.Brand.primary : Color.clear,
                            lineWidth: 2
                        )
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
                    .fill(isSelected
                          ? ColorTokens.Brand.primary.opacity(0.08)
                          : ColorTokens.Parent.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .strokeBorder(
                        isSelected ? ColorTokens.Brand.primary : Color.clear,
                        lineWidth: 2
                    )
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
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Parent.surface)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "family_calendar.children.add"))
    }
}

// MARK: - DayCell

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
                        Circle()
                            .fill(ColorTokens.Brand.primary)
                            .frame(width: 32, height: 32)
                    }
                    Text("\(day.dayNumber)")
                        .font(TypographyTokens.caption())
                        .foregroundStyle(textColor)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 32, height: 32)

                if let dot = dotColor {
                    Circle()
                        .fill(dot)
                        .frame(width: 5, height: 5)
                } else {
                    Spacer().frame(height: 5)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(1.0)
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
            GeometryReader { geo in
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

    private var cardWidth: CGFloat {
        horizontalSizeClass == .compact ? 140 : 160
    }
    private var cardHeight: CGFloat {
        horizontalSizeClass == .compact ? 180 : 200
    }

    var body: some View {
        VStack(spacing: SpacingTokens.medium) {
            // Avatar
            ZStack {
                Circle()
                    .fill(ColorTokens.Brand.primary.opacity(0.12))
                    .frame(width: 56, height: 56)
                Text(card.initials)
                    .font(TypographyTokens.headline())
                    .foregroundStyle(ColorTokens.Brand.primary)
            }

            // Name
            Text(card.name)
                .font(TypographyTokens.headline())
                .foregroundStyle(ColorTokens.Parent.ink)
                .lineLimit(1)

            // Best sound
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.Brand.gold)
                Text("\(card.bestSound) (\(Int(card.bestSoundRate * 100))%)")
                    .font(TypographyTokens.caption())
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(1)
            }

            // Comparison delta
            if let delta = card.comparisonDelta {
                let pct = Int(abs(delta) * 100)
                let sound = card.bestSound
                let text = String(
                    format: String(localized: "family_calendar.comparison.format"),
                    card.name,
                    sound,
                    pct
                )
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

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: SpacingTokens.medium) {
                if detail.isEmpty {
                    Text(String(localized: "family_calendar.detail.empty"))
                        .font(TypographyTokens.body())
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .multilineTextAlignment(.center)
                } else {
                    List(detail.sessionItems) { item in
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
                                .foregroundStyle(
                                    item.accuracyPercent >= 70
                                    ? ColorTokens.Semantic.success
                                    : ColorTokens.Semantic.warning
                                )
                        }
                        .listRowBackground(ColorTokens.Parent.surface)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(ColorTokens.Parent.bg)
                }
            }
            .navigationTitle(detail.dateText)
            .navigationBarTitleDisplayMode(.inline)
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
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
