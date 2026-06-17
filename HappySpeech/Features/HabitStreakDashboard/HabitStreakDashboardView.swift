import SwiftUI

// MARK: - HabitStreakDashboardView
//
// Детский экран «Мои успехи» (kid-progress класс). Редизайн по эталону
// kid-progress: тёплый hero со «спичкой» (flame) и Лялей-болельщиком,
// недельная streak-полоска (7 точек Пн–Вс из реальных дней), карточка
// тепловой карты за 12 недель + тёплая легенда. Все данные — реальные
// (HabitStreakDashboardInteractor.refresh() из SessionRepository), без выдумок.
//
// Инварианты: тёплая палитра (gold/coral) на крупных заливках, без off-palette;
// текст не обрезается (lineLimit(nil) + minimumScaleFactor); симметричные
// screenEdge-отступы; SE-safe (горизонтальный скролл heatmap); light+dark;
// Dynamic Type; VoiceOver; Reduced Motion.

struct HabitStreakDashboardView: View {

    // MARK: - Dependencies

    let childId: String

    @State private var interactor: HabitStreakDashboardInteractor?
    @Environment(AppContainer.self) private var container
    @Environment(\.exitGame) private var exitGame
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Layout constants

    private let cellSize: CGFloat = 18
    private let cellSpacing: CGFloat = 4
    /// Диаметр точки в streak-полоске (эталон: ~28pt, ровно на 4pt-сетке).
    private let dotSize: CGFloat = 28

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                HSMeshGradientBackground(palette: .kidWarm, animated: !reduceMotion)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.22 : 0.40)
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                content
            }
            .navigationTitle(Text(String(localized: "habitStreak.nav.title", defaultValue: "Мои успехи")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exitGame()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
            .task {
                if interactor == nil {
                    let new = HabitStreakDashboardInteractor(
                        childId: childId,
                        sessionRepository: container.sessionRepository
                    )
                    interactor = new
                    new.refresh()
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Content switch

    @ViewBuilder
    private var content: some View {
        if let interactor {
            ScrollView {
                VStack(spacing: SpacingTokens.sp4) {
                    heroCard(state: interactor.state)
                    weekStripCard(state: interactor.state)
                    progressSummaryCard(state: interactor.state)
                    heatMapCard(interactor: interactor)
                    if let day = interactor.state.selected {
                        detailCard(day: day)
                    }
                    cta(interactor: interactor)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
                .padding(.bottom, SpacingTokens.sp8)
            }
        } else {
            VStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .happy, size: 80)
                    .accessibilityHidden(true)
                ProgressView().controlSize(.large)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Hero streak card (эталон: flame + Ляля + cheer)

    private func heroCard(state: HabitStreakDashboardModels.ViewState) -> some View {
        let streak = state.currentStreak
        let cheer = streak > 0
            ? String(localized: "habitStreak.cheer")
            : String(localized: "habitStreak.cheer.start")

        return ZStack(alignment: .topTrailing) {
            // Тёплый радиальный glow в углу (как в эталоне).
            if !reduceMotion {
                RadialGradient(
                    colors: [ColorTokens.Overlay.highlight, .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 150
                )
                .allowsHitTesting(false)
            }

            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                // Верх: «спичка» в butter-gold плитке + число серии + статистика.
                HStack(spacing: SpacingTokens.sp3) {
                    flameTile(streak: streak)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "habitStreak.hero.title"))
                            .font(TypographyTokens.kidTitle(22))
                            .foregroundStyle(ColorTokens.Overlay.onAccent)
                            .minimumScaleFactor(0.85)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(String(localized: "habitStreak.hero.subtitle"))
                            .font(TypographyTokens.kidBody(14))
                            .foregroundStyle(ColorTokens.Overlay.onAccent.opacity(0.92))
                            .minimumScaleFactor(0.85)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                // Метрики: серия + всего минут.
                HStack(spacing: SpacingTokens.sp3) {
                    heroStat(
                        value: "\(streak)",
                        caption: String(localized: "habitStreak.streakLabel")
                    )
                    heroStat(
                        value: "\(state.totalMinutes)",
                        caption: String(localized: "habitStreak.totalLabel")
                    )
                }

                // Ляля + реплика-болельщик.
                HStack(alignment: .bottom, spacing: SpacingTokens.sp2) {
                    LyalyaMascotView(state: .celebrating, size: 54)
                        .accessibilityHidden(true)
                    cheerBubble(text: cheer)
                    Spacer(minLength: 0)
                }
            }
            .padding(SpacingTokens.cardPad)
        }
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous))
        .depthShadow(ShadowTokens.kidDepth)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(
            format: String(localized: "habitStreak.hero.a11y"),
            streak, state.totalMinutes
        )))
    }

    private func flameTile(streak: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [ColorTokens.Brand.butter, ColorTokens.Brand.gold],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 58, height: 58)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(ColorTokens.Overlay.highlight, lineWidth: 1)
                )
            Image(systemName: "flame.fill")
                .font(.system(size: 30))
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .hsSymbolEffect(.bounce, value: streak)
        }
        .accessibilityHidden(true)
    }

    private func heroStat(value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(TypographyTokens.kidDisplay(30))
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Overlay.onAccent.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, SpacingTokens.sp2)
        .padding(.horizontal, SpacingTokens.sp3)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ColorTokens.Overlay.glass)
        )
    }

    private func cheerBubble(text: String) -> some View {
        Text(text)
            .font(TypographyTokens.kidBody(14).weight(.semibold))
            .foregroundStyle(ColorTokens.Kid.ink)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, SpacingTokens.sp3)
            .padding(.vertical, SpacingTokens.sp2)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
            )
    }

    // MARK: - Weekly streak strip (эталон: 7 точек Пн–Вс)

    private func weekStripCard(state: HabitStreakDashboardModels.ViewState) -> some View {
        let week = lastSevenDays(state: state)
        let practicedCount = week.filter { $0.day.intensity > 0 }.count

        return HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.cardPad) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                HStack {
                    Text(String(localized: "habitStreak.week.title"))
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Text(String(format: String(localized: "habitStreak.week.meta"), practicedCount))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                }

                HStack(spacing: 0) {
                    ForEach(week, id: \.day.id) { item in
                        weekDot(item: item)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(
            format: String(localized: "habitStreak.week.a11y"),
            practicedCount
        )))
    }

    private func weekDot(item: WeekDayItem) -> some View {
        VStack(spacing: SpacingTokens.sp1) {
            ZStack {
                if item.isToday {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [ColorTokens.Brand.butter, ColorTokens.Brand.gold],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                } else if item.day.intensity > 0 {
                    Circle().fill(ColorTokens.Brand.primaryLo)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ColorTokens.Brand.primary)
                } else {
                    Circle()
                        .strokeBorder(
                            ColorTokens.Kid.line,
                            style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])
                        )
                        .background(Circle().fill(ColorTokens.Kid.surfaceAlt))
                    Text(verbatim: "·")
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Kid.inkSoft)
                }
            }
            .frame(width: dotSize, height: dotSize)

            Text(item.label)
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Kid.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
        }
    }

    // MARK: - Progress summary card (эталон: «Мои звуки» 3 кольца прогресса)
    //
    // Показывает три столбца с данными о сессиях за период: общий итог,
    // дни недели с практикой, среднее в минуту. Реальные данные из ViewState.
    // Структура «3 плитки» визуально соответствует 3 звуковым кольцам эталона.

    private func progressSummaryCard(state: HabitStreakDashboardModels.ViewState) -> some View {
        let practicedDays = state.days.filter { $0.intensity > 0 }.count
        let avgMinutes: Int = practicedDays > 0 ? state.totalMinutes / practicedDays : 0
        let bestDay = state.days.max(by: { $0.minutes < $1.minutes })
        let bestMinutes = bestDay?.minutes ?? 0

        return HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                HStack {
                    Text(String(localized: "habitStreak.summary.title", defaultValue: "Мои достижения"))
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }

                HStack(spacing: SpacingTokens.sp3) {
                    summaryTile(
                        value: "\(practicedDays)",
                        caption: String(localized: "habitStreak.summary.days", defaultValue: "дней занятий"),
                        tint: ColorTokens.Brand.primary
                    )
                    summaryTile(
                        value: "\(avgMinutes)",
                        caption: String(localized: "habitStreak.summary.avgMin", defaultValue: "сред. минут"),
                        tint: ColorTokens.Brand.gold
                    )
                    summaryTile(
                        value: "\(bestMinutes)",
                        caption: String(localized: "habitStreak.summary.bestMin", defaultValue: "лучший день"),
                        tint: ColorTokens.Brand.rose
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(
            format: String(localized: "habitStreak.summary.a11y",
                           defaultValue: "%lld дней занятий, в среднем %lld минут"),
            practicedDays, avgMinutes
        )))
    }

    private func summaryTile(value: String, caption: String, tint: Color) -> some View {
        VStack(spacing: SpacingTokens.sp1) {
            // Числовой индикатор
            ZStack {
                Circle()
                    .stroke(ColorTokens.Kid.line, lineWidth: 4)
                Circle()
                    .trim(from: 0, to: 1)
                    .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(value)
                    .font(TypographyTokens.headline(16).monospacedDigit())
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 64, height: 64)
            .accessibilityHidden(true)

            Text(caption)
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Heat map card

    private func heatMapCard(interactor: HabitStreakDashboardInteractor) -> some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                HStack {
                    Text(String(localized: "habitStreak.heatmap.title"))
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Text(String(localized: "habitStreak.heatmap.meta"))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: cellSpacing) {
                        ForEach(0..<HabitStreakDashboardModels.ViewState.weeks, id: \.self) { week in
                            VStack(spacing: cellSpacing) {
                                ForEach(0..<HabitStreakDashboardModels.ViewState.daysPerWeek, id: \.self) { row in
                                    let index = week * HabitStreakDashboardModels.ViewState.daysPerWeek + row
                                    if index < interactor.state.days.count {
                                        cell(day: interactor.state.days[index], interactor: interactor)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }

                legend
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func cell(
        day: HabitStreakDashboardModels.Day,
        interactor: HabitStreakDashboardInteractor
    ) -> some View {
        let isSelected = interactor.state.selected?.id == day.id
        return Button {
            hapticService.impact(.light)
            interactor.select(day)
        } label: {
            RoundedRectangle(cornerRadius: 4)
                .fill(intensityColor(day.intensity))
                .frame(width: cellSize, height: cellSize)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            isSelected ? ColorTokens.Brand.gold : Color.clear,
                            lineWidth: 2
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(
            format: String(localized: "habitStreak.day.detail.practiced"),
            day.minutes
        )))
        .accessibilityAddTraits(.isButton)
    }

    // Тёплый интенсивностный ramp (butter → coral) вместо mint — единая
    // тёплая палитра, как в эталоне kid-progress.
    private func intensityColor(_ intensity: Int) -> Color {
        switch intensity {
        case 0:  return ColorTokens.Kid.surfaceAlt
        case 1:  return ColorTokens.Brand.butter.opacity(0.55)
        case 2:  return ColorTokens.Brand.primaryLo
        case 3:  return ColorTokens.Brand.primaryHi
        default: return ColorTokens.Brand.primary
        }
    }

    private var legend: some View {
        HStack(spacing: SpacingTokens.sp2) {
            Text(String(localized: "habitStreak.legend.less"))
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
            ForEach(0..<5, id: \.self) { intensity in
                RoundedRectangle(cornerRadius: 3)
                    .fill(intensityColor(intensity))
                    .frame(width: 14, height: 14)
            }
            Text(String(localized: "habitStreak.legend.more"))
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Selected-day detail

    private func detailCard(day: HabitStreakDashboardModels.Day) -> some View {
        HSCard(style: .tinted(ColorTokens.Brand.primaryLo.opacity(0.30))) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                Text(String(
                    format: String(localized: "habitStreak.day.detail.title"),
                    day.id + 1,
                    HabitStreakDashboardModels.ViewState.totalCells
                ))
                .font(TypographyTokens.headline(15))
                .foregroundStyle(ColorTokens.Kid.ink)
                .fixedSize(horizontal: false, vertical: true)
                Text(day.minutes > 0
                    ? String(format: String(localized: "habitStreak.day.detail.practiced"), day.minutes)
                    : String(localized: "habitStreak.day.detail.empty"))
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - CTA

    private func cta(interactor: HabitStreakDashboardInteractor) -> some View {
        HSButton(
            String(localized: "habitStreak.cta.action"),
            style: .secondary,
            size: .large,
            icon: "arrow.uturn.left"
        ) {
            hapticService.impact(.light)
            interactor.clearSelection()
        }
    }

    // MARK: - Week-strip derivation (реальные данные)

    private struct WeekDayItem {
        let day: HabitStreakDashboardModels.Day
        let label: String
        let isToday: Bool
    }

    /// Последние 7 дней heat-карты (последняя ячейка — сегодня), с подписями
    /// Пн–Вс по реальной дате каждого дня. Источник — реальный `state.days`.
    private func lastSevenDays(state: HabitStreakDashboardModels.ViewState) -> [WeekDayItem] {
        let calendar = Calendar.current
        let total = HabitStreakDashboardModels.ViewState.totalCells
        let today = calendar.startOfDay(for: Date())
        let last7 = state.days.suffix(7)

        return last7.map { day in
            let daysAgo = (total - 1) - day.id
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            let weekday = calendar.component(.weekday, from: date) // 1=Sun … 7=Sat
            return WeekDayItem(
                day: day,
                label: Self.weekdayLabel(weekday),
                isToday: daysAgo == 0
            )
        }
    }

    private static func weekdayLabel(_ weekday: Int) -> String {
        switch weekday {
        case 2:  return String(localized: "habitStreak.weekday.mon")
        case 3:  return String(localized: "habitStreak.weekday.tue")
        case 4:  return String(localized: "habitStreak.weekday.wed")
        case 5:  return String(localized: "habitStreak.weekday.thu")
        case 6:  return String(localized: "habitStreak.weekday.fri")
        case 7:  return String(localized: "habitStreak.weekday.sat")
        default: return String(localized: "habitStreak.weekday.sun")
        }
    }
}

// MARK: - Preview

#Preview("HabitStreakDashboard — Light") {
    HabitStreakDashboardView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("HabitStreakDashboard — Dark") {
    HabitStreakDashboardView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
