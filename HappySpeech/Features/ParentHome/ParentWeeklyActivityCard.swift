import SwiftUI

// MARK: - ParentWeeklyActivityCard
//
// Эталонный (parenthome.png) центральный элемент дашборда родителя:
// 7-дневная столбчатая диаграмма минут практики (Пн–Вс) с тёплыми
// коралловыми барами, выделенным «сегодня» и плашкой «Инсайт недели»
// обычным языком. Данные реальные — `ParentHomeModels.DayStat` +
// `WeeklyInsight` из Interactor/Presenter (никаких фабрикаций во View).
//
// Пустые дни рендерятся как пунктирный «нулевой» столбик (как в эталоне).
// Если за неделю нет занятий вовсе — показываем мягкий empty-state внутри
// карточки вместо пустой диаграммы.

struct ParentWeeklyActivityCard: View {

    let weekStats: [ParentHomeModels.DayStat]
    let insight: ParentHomeModels.WeeklyInsight?

    @Environment(\.colorScheme) private var colorScheme

    private var maxMinutes: Int {
        max(weekStats.map(\.minutes).max() ?? 0, 1)
    }

    private var hasAnyActivity: Bool {
        weekStats.contains { $0.minutes > 0 }
    }

    /// Индекс «сегодня» в массиве — последний день недели (бэкенд формирует
    /// trailing-7-day окно, заканчивающееся сегодняшним днём).
    private var todayIndex: Int? {
        weekStats.indices.last
    }

    var body: some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
                header

                if weekStats.isEmpty || !hasAnyActivity {
                    emptyState
                } else {
                    chart
                }

                if let insight, !insight.summaryText.isEmpty {
                    insightBanner(insight.summaryText)
                }
            }
        }
        .environment(\.circuitContext, .parent)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "parentHome.weekly.title"))
        .accessibilityValue(a11yValue)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(String(localized: "parentHome.weekly.title"))
                .font(TypographyTokens.headline(17))
                .foregroundStyle(ColorTokens.Parent.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: SpacingTokens.sp2)
            Text(String(localized: "parentHome.weekly.meta"))
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    // MARK: - Chart

    private var chart: some View {
        HStack(alignment: .bottom, spacing: SpacingTokens.sp2) {
            ForEach(Array(weekStats.enumerated()), id: \.element.id) { index, day in
                barColumn(day: day, isToday: index == todayIndex)
            }
        }
        // Эталон parenthome_ref.png: график крупный, занимает заметную часть карточки.
        .frame(height: 160)
        .accessibilityHidden(true)
    }

    private func barColumn(day: ParentHomeModels.DayStat, isToday: Bool) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            // Подпись минут над баром (только для непустых дней).
            Text(day.minutes > 0 ? "\(day.minutes)" : " ")
                .font(TypographyTokens.caption(10).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)

            GeometryReader { geo in
                let fraction = CGFloat(day.minutes) / CGFloat(maxMinutes)
                let barHeight = max(6, geo.size.height * fraction)
                ZStack(alignment: .bottom) {
                    if day.minutes == 0 {
                        // Эталон — пустой день = пунктирный «нулевой» столбик.
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(
                                ColorTokens.Parent.inkMuted.opacity(0.35),
                                style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                            )
                            .frame(height: 8)
                            .frame(maxWidth: 22)
                    } else {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: barHeight)
                            .frame(maxWidth: 22)
                            .shadow(
                                color: isToday
                                    ? ColorTokens.Brand.primary.opacity(0.4)
                                    : .clear,
                                radius: 6, y: 3
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }

            Text(day.dayLabel)
                .font(TypographyTokens.caption(11).weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? ColorTokens.Parent.accent : ColorTokens.Parent.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Insight banner

    private func insightBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.sp2) {
            Image(systemName: "lightbulb.fill")
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Brand.lilac)
                .padding(.top, 1)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "parentHome.weekly.insight.label"))
                    .font(TypographyTokens.caption(12).weight(.bold))
                    .foregroundStyle(ColorTokens.Brand.lilac)
                Text(text)
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .fill(ColorTokens.Brand.lilac.opacity(colorScheme == .dark ? 0.16 : 0.12))
        )
    }

    // MARK: - Empty state

    private var emptyState: some View {
        HStack(spacing: SpacingTokens.sp3) {
            Image(systemName: "calendar.badge.plus")
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Parent.accent)
                .accessibilityHidden(true)
            Text(String(localized: "parentHome.weekly.empty"))
                .font(TypographyTokens.body(13))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, SpacingTokens.sp3)
    }

    private var a11yValue: String {
        guard hasAnyActivity else {
            return String(localized: "parentHome.weekly.empty")
        }
        let days = weekStats
            .map { "\($0.dayLabel) \($0.minutes)" }
            .joined(separator: ", ")
        return String(localized: "parentHome.weekly.a11y") + " " + days
    }
}

// MARK: - Preview

#Preview("Weekly Activity — Light") {
    let calendar = Calendar.current
    let stats = (0..<7).reversed().map { offset in
        ParentHomeModels.DayStat(
            date: calendar.date(byAdding: .day, value: -offset, to: Date()) ?? Date(),
            minutes: [12, 8, 15, 0, 10, 18, 14][6 - offset],
            accuracy: 0.8,
            sessionsCount: 1
        )
    }
    return ParentWeeklyActivityCard(
        weekStats: stats,
        insight: ParentHomeModels.WeeklyInsight(
            summaryText: "На выходных ребёнок занимался дольше всего. Один пропуск в четверг — попробуйте короткие занятия в будни.",
            highlights: [],
            recommendations: [],
            source: .ruleBased
        )
    )
    .padding()
    .background(ColorTokens.Parent.bg)
}

#Preview("Weekly Activity — Empty") {
    ParentWeeklyActivityCard(weekStats: [], insight: nil)
        .padding()
        .background(ColorTokens.Parent.bg)
}
