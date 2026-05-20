import Charts
import SwiftUI

// MARK: - FamilyCalendarViewComponents
//
// Подкомпоненты для `FamilyCalendarView`. Все структуры — `internal`.
// Sheet-компоненты вынесены в `FamilyCalendarViewSheets.swift`.

// MARK: - ChildAvatarCard

struct ChildAvatarCard: View {
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
                            .font(TypographyTokens.titleSmall(22))
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
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .frame(width: 88)
                    .multilineTextAlignment(.center)

                if child.streak > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(TypographyTokens.caption(10))
                            .foregroundStyle(ColorTokens.Brand.primary)
                        Text("\(child.streak)д")
                            .font(TypographyTokens.caption(10))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }
                } else {
                    Spacer().frame(height: 14)
                }
            }
            .frame(width: 96, height: 116)
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

struct AddChildCapsule: View {
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
                        .font(TypographyTokens.title(24))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                }
                Text(String(localized: "family_calendar.children.add"))
                    .font(TypographyTokens.caption())
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .frame(width: 88)
                    .multilineTextAlignment(.center)
                Spacer().frame(height: 14)
            }
            .frame(width: 96, height: 116)
            .background(RoundedRectangle(cornerRadius: RadiusTokens.card).fill(ColorTokens.Parent.surface))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "family_calendar.children.add"))
    }
}

// MARK: - WeekDayCell

struct WeekDayCell: View {
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
                    .font(TypographyTokens.caption(9))
                    .foregroundStyle(day.isToday ? .white.opacity(0.8) : ColorTokens.Parent.inkMuted)
                    .minimumScaleFactor(0.7)

                Text("\(day.dayNumber)")
                    .font(TypographyTokens.caption())
                    .foregroundStyle(textColor)
                    .minimumScaleFactor(0.7)

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

struct WeekGoalCard: View {
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
                                .font(TypographyTokens.caption(10))
                                .foregroundStyle(ColorTokens.Brand.primary)
                            Text("\(card.streakDays)д")
                                .font(TypographyTokens.caption(10))
                                .foregroundStyle(ColorTokens.Parent.inkMuted)
                        }
                    }
                }
                Spacer()
                if card.goalReached {
                    Image(systemName: "checkmark.circle.fill")
                        .font(TypographyTokens.titleSmall(20))
                        .foregroundStyle(ColorTokens.Semantic.success)
                        .accessibilityLabel(String(localized: "family_calendar.a11y.goal_reached"))
                }
            }

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
        .depthShadow(ShadowTokens.parentDepth)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: String(localized: "family_calendar.a11y.goal_card"),
                                   card.childName, card.sessionsAchieved, card.sessionsGoal))
    }
}

// MARK: - DayCell

struct DayCell: View {
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

struct HeatmapChartView: View {
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

struct ChildSummaryCard: View {
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
                    .font(TypographyTokens.caption(12))
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
        .depthShadow(ShadowTokens.parentDepth)
    }
}

// MARK: - CalendarInsightRow

struct CalendarInsightRow: View {
    let insight: InsightItemViewModel

    var body: some View {
        HStack(spacing: SpacingTokens.medium) {
            Image(systemName: insight.iconName)
                .font(TypographyTokens.titleSmall(20))
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

// MARK: - CalendarSectionHeader

struct CalendarSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(TypographyTokens.title())
            .foregroundStyle(ColorTokens.Parent.ink)
            .accessibilityAddTraits(.isHeader)
    }
}
