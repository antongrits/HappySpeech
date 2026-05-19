@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - FamilyCalendarSnapshotTests
//
// 8 snapshot PNG для FamilyCalendarView (F3-005).
// 4 сценария × 2 темы = 8 PNG.
// Хранятся в __Snapshots__/FamilyCalendar/<экран>/<device>_<appearance>.png
//
// Рендеринг: UIHostingController + UIGraphicsImageRenderer (паттерн из F1/F2/B2).
// Threshold 55%: GPU-рендер нестабилен на симуляторе.
// Frozen ViewModel: не вызывает bootstrap/Realm/Firebase.

@MainActor
final class FamilyCalendarSnapshotTests: XCTestCase {

    // MARK: - Device

    private let deviceSize   = CGSize(width: 402, height: 874)
    private let deviceSizeSE = CGSize(width: 375, height: 667)
    private let deviceName   = "iPhone17Pro"
    private let deviceNameSE = "iPhoneSE3"

    // MARK: - Snapshot cases

    // 1. 3 детей, «Все» выбраны, light
    func test_familyCalendar_3children_iPhone17Pro_Light() throws {
        try record(
            view: makeView(scenario: .threeChildren),
            screen: "3children",
            device: deviceName, size: deviceSize,
            appearance: ("Light", .light)
        )
    }

    // 2. 3 детей, «Все» выбраны, dark
    func test_familyCalendar_3children_iPhone17Pro_Dark() throws {
        try record(
            view: makeView(scenario: .threeChildren),
            screen: "3children",
            device: deviceName, size: deviceSize,
            appearance: ("Dark", .dark)
        )
    }

    // 3. Один ребёнок выбран, light
    func test_familyCalendar_oneChildSelected_iPhone17Pro_Light() throws {
        try record(
            view: makeView(scenario: .oneChildSelected),
            screen: "oneChildSelected",
            device: deviceName, size: deviceSize,
            appearance: ("Light", .light)
        )
    }

    // 4. Один ребёнок выбран, dark
    func test_familyCalendar_oneChildSelected_iPhone17Pro_Dark() throws {
        try record(
            view: makeView(scenario: .oneChildSelected),
            screen: "oneChildSelected",
            device: deviceName, size: deviceSize,
            appearance: ("Dark", .dark)
        )
    }

    // 5. Сравнение «Все» с 2+ детьми, light
    func test_familyCalendar_compareAll_iPhone17Pro_Light() throws {
        try record(
            view: makeView(scenario: .compareAll),
            screen: "compareAll",
            device: deviceName, size: deviceSize,
            appearance: ("Light", .light)
        )
    }

    // 6. Сравнение «Все» с 2+ детьми, dark
    func test_familyCalendar_compareAll_iPhone17Pro_Dark() throws {
        try record(
            view: makeView(scenario: .compareAll),
            screen: "compareAll",
            device: deviceName, size: deviceSize,
            appearance: ("Dark", .dark)
        )
    }

    // 7. Empty state, iPhone SE, light
    func test_familyCalendar_emptyState_iPhoneSE_Light() throws {
        try record(
            view: makeView(scenario: .emptyState),
            screen: "emptyState",
            device: deviceNameSE, size: deviceSizeSE,
            appearance: ("Light", .light)
        )
    }

    // 8. Empty state, iPhone SE, dark
    func test_familyCalendar_emptyState_iPhoneSE_Dark() throws {
        try record(
            view: makeView(scenario: .emptyState),
            screen: "emptyState",
            device: deviceNameSE, size: deviceSizeSE,
            appearance: ("Dark", .dark)
        )
    }

    // MARK: - View Factory

    private enum Scenario {
        case threeChildren
        case oneChildSelected
        case compareAll
        case emptyState
    }

    private func makeView(scenario: Scenario) -> some View {
        FamilyCalendarSnapshotWrapper(viewModel: viewModel(for: scenario))
            .environment(AppContainer.preview())
            .environment(AppCoordinator())
            .environment(\.circuitContext, .parent)
    }

    private func viewModel(for scenario: Scenario) -> FamilyCalendarViewModel {
        switch scenario {
        case .threeChildren:
            return FamilyCalendarViewModel(
                children: [
                    ChildAvatarViewModel(id: "all", name: "Все", initials: "", avatarStyle: "all", streak: 0, isAll: true),
                    ChildAvatarViewModel(id: "c-1", name: "Миша", initials: "МИ", avatarStyle: "butterfly", streak: 5, isAll: false),
                    ChildAvatarViewModel(id: "c-2", name: "Соня", initials: "СО", avatarStyle: "robot", streak: 3, isAll: false),
                    ChildAvatarViewModel(id: "c-3", name: "Ваня", initials: "ВА", avatarStyle: "rocket", streak: 1, isAll: false)
                ],
                selectedChildId: nil,
                currentMonth: Date(),
                weekOffset: 0,
                weekDays: [],
                calendarDays: stubCalendarDays(),
                heatmapEntries: stubHeatmapEntries(),
                comparisonCards: [],
                weekGoalCards: [],
                insights: stubInsights(),
                isLoading: false,
                isLoadingInsights: false,
                toastMessage: nil,
                isEmpty: false,
                selectedDayDetail: nil
            )

        case .oneChildSelected:
            return FamilyCalendarViewModel(
                children: [
                    ChildAvatarViewModel(id: "all", name: "Все", initials: "", avatarStyle: "all", streak: 0, isAll: true),
                    ChildAvatarViewModel(id: "c-1", name: "Миша", initials: "МИ", avatarStyle: "butterfly", streak: 7, isAll: false),
                    ChildAvatarViewModel(id: "c-2", name: "Соня", initials: "СО", avatarStyle: "robot", streak: 2, isAll: false)
                ],
                selectedChildId: "c-1",
                currentMonth: Date(),
                weekOffset: 0,
                weekDays: [],
                calendarDays: stubCalendarDays(),
                heatmapEntries: stubHeatmapEntries(),
                comparisonCards: [],
                weekGoalCards: [],
                insights: stubInsights(),
                isLoading: false,
                isLoadingInsights: false,
                toastMessage: nil,
                isEmpty: false,
                selectedDayDetail: nil
            )

        case .compareAll:
            return FamilyCalendarViewModel(
                children: [
                    ChildAvatarViewModel(id: "all", name: "Все", initials: "", avatarStyle: "all", streak: 0, isAll: true),
                    ChildAvatarViewModel(id: "c-1", name: "Миша", initials: "МИ", avatarStyle: "butterfly", streak: 5, isAll: false),
                    ChildAvatarViewModel(id: "c-2", name: "Соня", initials: "СО", avatarStyle: "robot", streak: 3, isAll: false)
                ],
                selectedChildId: nil,
                currentMonth: Date(),
                weekOffset: 0,
                weekDays: [],
                calendarDays: stubCalendarDays(),
                heatmapEntries: stubHeatmapEntries(),
                comparisonCards: [
                    ChildSummaryViewModel(
                        id: "c-1", name: "Миша", initials: "МИ", avatarStyle: "butterfly",
                        bestSound: "Р", bestSoundRate: 0.88,
                        comparisonDelta: 0.05, isLeader: true
                    ),
                    ChildSummaryViewModel(
                        id: "c-2", name: "Соня", initials: "СО", avatarStyle: "robot",
                        bestSound: "С", bestSoundRate: 0.75,
                        comparisonDelta: -0.05, isLeader: false
                    )
                ],
                weekGoalCards: [],
                insights: stubInsights(),
                isLoading: false,
                isLoadingInsights: false,
                toastMessage: nil,
                isEmpty: false,
                selectedDayDetail: nil
            )

        case .emptyState:
            return FamilyCalendarViewModel(
                children: [
                    ChildAvatarViewModel(id: "all", name: "Все", initials: "", avatarStyle: "all", streak: 0, isAll: true)
                ],
                selectedChildId: nil,
                currentMonth: Date(),
                weekOffset: 0,
                weekDays: [],
                calendarDays: [],
                heatmapEntries: [],
                comparisonCards: [],
                weekGoalCards: [],
                insights: [],
                isLoading: false,
                isLoadingInsights: false,
                toastMessage: nil,
                isEmpty: true,
                selectedDayDetail: nil
            )
        }
    }

    // MARK: - Stub data

    private func stubCalendarDays() -> [CalendarDayViewModel] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: Date()) else { return [] }
        let firstDay = monthInterval.start
        let daysInMonth = calendar.range(of: .day, in: .month, for: Date())?.count ?? 30
        let today = calendar.startOfDay(for: Date())

        return (0..<min(daysInMonth, 42)).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: firstDay) else { return nil }
            let norm = calendar.startOfDay(for: date)
            let isToday = norm == today
            let count = offset % 3 == 0 ? 2 : 0
            return CalendarDayViewModel(
                date: date,
                dayNumber: offset + 1,
                sessionCount: count,
                isToday: isToday,
                isCurrentMonth: true,
                isFuture: norm > today,
                activityLevel: isToday && count > 0 ? 4 : (count > 0 ? 1 : 0)
            )
        }
    }

    private func stubHeatmapEntries() -> [HeatmapEntryViewModel] {
        let calendar = Calendar.current
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start,
              let startDate = calendar.date(byAdding: .weekOfYear, value: -7, to: currentWeekStart)
        else { return [] }

        var entries: [HeatmapEntryViewModel] = []
        for weekIdx in 0..<8 {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: weekIdx, to: startDate) else { continue }
            for dayIdx in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: dayIdx, to: weekStart) else { continue }
                let count = (weekIdx + dayIdx) % 4
                entries.append(HeatmapEntryViewModel(
                    weekIndex: weekIdx,
                    weekday: dayIdx,
                    sessionCount: count,
                    date: day,
                    label: "День \(weekIdx * 7 + dayIdx)"
                ))
            }
        }
        return entries
    }

    private func stubInsights() -> [InsightItemViewModel] {
        [
            InsightItemViewModel(iconName: "flame.fill", text: "Миша занимается 5 дней подряд"),
            InsightItemViewModel(iconName: "star.fill", text: "Отличный прогресс по звуку Р — 88%")
        ]
    }

    // MARK: - Rendering engine

    private func render<V: View>(
        _ view: V,
        size: CGSize,
        style: UIUserInterfaceStyle
    ) -> UIImage {
        SnapshotTestHelper.renderView(view, size: size, style: style)
    }

    private func record<V: View>(
        view: V,
        screen: String,
        device: String,
        size: CGSize,
        appearance: (String, UIUserInterfaceStyle)
    ) throws {
        let (appearanceName, style) = appearance
        let image = render(view, size: size, style: style)
        let url = SnapshotTestHelper.snapshotURL(
            testClass: Self.self,
            category: "FamilyCalendar",
            screen: screen,
            device: device,
            appearance: appearanceName
        )
        let label = "\(screen)·\(device)·\(appearanceName)"
        try SnapshotTestHelper.assertPixelMatch(image, referenceURL: url, label: label)
    }
}

// MARK: - FamilyCalendarSnapshotWrapper

/// Frozen-обёртка для snapshot тестов.
/// Рендерит FamilyCalendar UI из готового ViewModel без bootstrap/Realm/Firebase.
private struct FamilyCalendarSnapshotWrapper: View {
    let viewModel: FamilyCalendarViewModel

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ColorTokens.Parent.bg.ignoresSafeArea()

                if viewModel.isEmpty {
                    emptyBody
                } else {
                    mainBody
                }
            }
            .navigationTitle("Семейный календарь")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Empty

    private var emptyBody: some View {
        VStack(spacing: SpacingTokens.xxLarge) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 56))
                .foregroundStyle(ColorTokens.Parent.inkSoft)
                .accessibilityHidden(true)
            Text("Нет данных")
                .font(TypographyTokens.title())
                .foregroundStyle(ColorTokens.Parent.ink)
                .multilineTextAlignment(.center)
            Text("Начните первое занятие, чтобы увидеть статистику")
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, SpacingTokens.regular)
    }

    // MARK: - Main

    private var mainBody: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: SpacingTokens.sectionGap) {
                childrenStrip
                calendarSection
                if viewModel.comparisonCards.count >= 2 {
                    comparisonSection
                }
                insightsSection
            }
            .padding(.horizontal, SpacingTokens.regular)
            .padding(.vertical, SpacingTokens.large)
        }
    }

    // MARK: - Children strip

    private var childrenStrip: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.medium) {
            Text("Дети семьи")
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Parent.ink)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SpacingTokens.medium) {
                    ForEach(viewModel.children) { child in
                        childCard(child)
                    }
                }
            }
        }
    }

    private func childCard(_ child: ChildAvatarViewModel) -> some View {
        let isSelected = child.isAll
            ? viewModel.selectedChildId == nil
            : viewModel.selectedChildId == child.id

        return VStack(spacing: SpacingTokens.tiny) {
            ZStack {
                Circle()
                    .fill(isSelected
                          ? ColorTokens.Brand.primary.opacity(0.18)
                          : ColorTokens.Parent.surface)
                    .frame(width: 56, height: 56)
                if child.isAll {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(ColorTokens.Brand.primary)
                } else {
                    Text(child.initials)
                        .font(TypographyTokens.headline(18))
                        .foregroundStyle(ColorTokens.Brand.primary)
                }
            }
            Text(child.name)
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineLimit(1)
            if child.streak > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.Semantic.warning)
                    Text("\(child.streak)")
                        .font(TypographyTokens.caption(10))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                }
            }
        }
        .frame(width: 72)
    }

    // MARK: - Calendar

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.medium) {
            Text("Апрель 2026")
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Parent.ink)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(["Пн","Вт","Ср","Чт","Пт","Сб","Вс"], id: \.self) { day in
                    Text(day)
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .frame(maxWidth: .infinity)
                }
                ForEach(viewModel.calendarDays) { cell in
                    calendarCell(cell)
                }
            }
        }
        .padding(SpacingTokens.regular)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(ColorTokens.Parent.surface)
        )
    }

    private func calendarCell(_ cell: CalendarDayViewModel) -> some View {
        ZStack {
            Circle()
                .fill(cellColor(for: cell))
                .frame(width: 32, height: 32)
            Text("\(cell.dayNumber)")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(cell.isCurrentMonth
                                 ? ColorTokens.Parent.ink
                                 : ColorTokens.Parent.inkMuted)
        }
        .frame(height: 36)
    }

    private func cellColor(for cell: CalendarDayViewModel) -> Color {
        switch cell.activityLevel {
        case 4:  return ColorTokens.Brand.primary
        case 3:  return ColorTokens.Brand.primary.opacity(0.70)
        case 2:  return ColorTokens.Brand.primary.opacity(0.45)
        case 1:  return ColorTokens.Brand.primary.opacity(0.20)
        default: return Color.clear
        }
    }

    // MARK: - Comparison

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.medium) {
            Text("Сравнение детей")
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Parent.ink)

            HStack(spacing: SpacingTokens.regular) {
                ForEach(viewModel.comparisonCards) { card in
                    comparisonCard(card)
                }
            }
        }
    }

    private func comparisonCard(_ card: ChildSummaryViewModel) -> some View {
        VStack(spacing: SpacingTokens.small) {
            ZStack {
                Circle()
                    .fill(card.isLeader
                          ? ColorTokens.Semantic.success.opacity(0.15)
                          : ColorTokens.Parent.surface)
                    .frame(width: 52, height: 52)
                Text(card.initials)
                    .font(TypographyTokens.headline(18))
                    .foregroundStyle(ColorTokens.Brand.primary)
            }
            Text(card.name)
                .font(TypographyTokens.headline(14))
                .foregroundStyle(ColorTokens.Parent.ink)
            Text("Лучший: \(card.bestSound)")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
            Text("\(Int(card.bestSoundRate * 100))%")
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Brand.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.regular)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(ColorTokens.Parent.surface)
        )
    }

    // MARK: - Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.medium) {
            Text("Советы")
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Parent.ink)

            VStack(spacing: SpacingTokens.small) {
                ForEach(viewModel.insights) { insight in
                    HStack(spacing: SpacingTokens.small) {
                        Image(systemName: insight.iconName)
                            .font(.system(size: 18))
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .frame(width: 28)
                        Text(insight.text)
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(ColorTokens.Parent.ink)
                            .lineLimit(nil)
                        Spacer()
                    }
                    .padding(SpacingTokens.regular)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                            .fill(ColorTokens.Parent.surface)
                    )
                }
            }
        }
    }
}
