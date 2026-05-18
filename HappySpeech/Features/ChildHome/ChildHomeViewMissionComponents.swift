import OSLog
import SwiftUI

// MARK: - ChildHomeViewMissionComponents
//
// Подкомпоненты для `ChildHomeView`, относящиеся к ежедневной миссии,
// быстрой игре, тайлам действий и мини-превью карты мира.
// Извлечено из `ChildHomeViewComponents.swift` (Block K.1 v16) для
// удержания LOC ≤500. Все компоненты — `internal` внутри модуля.

// MARK: - DailyMissionDetailCard

struct ChildHomeDailyMissionDetailCard: View {

    let mission: ChildHomeModels.DailyMissionDetail
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            HSLiquidGlassCard(style: .primary, padding: SpacingTokens.cardPad) {
                VStack(spacing: SpacingTokens.sp4) {
                    topRow
                    progressBlock
                    if mission.isCompleted {
                        completedRow
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
        .tapFeedback()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(mission.title). \(mission.description). \(mission.repsCounterText)"))
        .accessibilityHint(Text(String(localized: "child.home.daily.a11y.hint")))
        .accessibilityIdentifier("childHomeDailyMissionCard")
    }

    private var topRow: some View {
        HStack(alignment: .top, spacing: SpacingTokens.sp4) {
            ChildHomeSoundLetterBadge(letter: mission.targetSound, size: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text(mission.title)
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(mission.description)
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)

            playIcon
        }
    }

    /// «Играть» — мягкий повторяющийся pulse привлекает внимание к CTA.
    /// Под Reduce Motion — статичная иконка (symbolEffect не применяется).
    @ViewBuilder
    private var playIcon: some View {
        let icon = Image(systemName: "play.circle.fill")
            .font(TypographyTokens.title(32))
            .foregroundStyle(ColorTokens.Brand.primary)
            .accessibilityHidden(true)
        if reduceMotion || mission.isCompleted {
            icon
        } else {
            icon.symbolEffect(.pulse, options: .repeating)
        }
    }

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            HStack {
                Text(String(localized: "child.home.mission.progress"))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                Spacer()
                Text(mission.repsCounterText)
                    .font(TypographyTokens.mono(13))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(
                        MotionTokens.scrollTransition(reduceMotion: reduceMotion),
                        value: mission.progress
                    )
            }

            HSProgressBar(
                value: Double(mission.progress),
                style: .kid,
                tint: ColorTokens.Brand.primary
            )
            .frame(height: 10)
        }
    }

    private var completedRow: some View {
        HStack(spacing: SpacingTokens.sp2) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(ColorTokens.Semantic.success)
                .accessibilityHidden(true)
            Text(String(localized: "child.home.mission.completed"))
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Semantic.success)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - QuickPlayCard (M8.7 — 130×160 horizontal carousel item)

struct ChildHomeQuickPlayCard: View {

    let item: ChildHomeModels.QuickPlayItem
    let action: () -> Void

    private var accentColor: Color {
        ColorTokens.color(for: item.accent)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.18))
                        .frame(width: 48, height: 48)

                    Image(systemName: item.icon)
                        .font(TypographyTokens.title(22).weight(.semibold))
                        .foregroundStyle(accentColor)
                        .accessibilityHidden(true)
                }

                Spacer(minLength: 0)

                Text(item.title)
                    .font(TypographyTokens.headline(14))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.leading)
                    .ctaTextStyle()

                // B13: difficulty stars (1…3) — визуальная подсказка сложности.
                ChildHomeDifficultyStarsView(level: item.difficulty, tint: accentColor)
            }
            .padding(SpacingTokens.sp4)
            .frame(width: 130, height: 160, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .depthShadow(for: .kid)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .strokeBorder(accentColor.opacity(0.18), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .tapFeedback()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.title)
        .accessibilityValue(Text(String.localizedStringWithFormat(
            String(localized: "child.home.quick.difficulty.a11y"),
            item.difficulty
        )))
        .accessibilityHint(String(localized: "child.home.quick.a11y.hint"))
        .accessibilityIdentifier("childHomeLessonCard")
    }
}

// MARK: - DifficultyStarsView (B13)

/// 3 звёздочки: первые `level` залиты, остальные — outline.
/// Используется в `ChildHomeQuickPlayCard` для визуализации сложности 1…3.
struct ChildHomeDifficultyStarsView: View {

    let level: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < level ? "star.fill" : "star")
                    .font(TypographyTokens.caption(10).weight(.semibold))
                    .foregroundStyle(index < level ? tint : ColorTokens.Kid.inkSoft)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - QuickActionTile (legacy 2x2 tile)
//
// S12 Block S: принимает опциональный namespace для matchedGeometryEffect
// на иконке-круге. heroId уникален для каждого тайла в сетке.
// Если namespace не передан — работает как раньше (backward compatible).

struct ChildHomeQuickActionTile: View {

    let title: String
    let icon: String
    let color: Color
    var heroId: String? = nil
    var namespace: Namespace.ID? = nil
    var reduceMotion: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: SpacingTokens.sp2) {
                iconCircle

                Text(title)
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .ctaTextStyle()
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.vertical, SpacingTokens.sp4)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .depthShadow(for: .kid)
            )
        }
        .buttonStyle(.plain)
        .tapFeedback()
        .accessibilityLabel(title)
    }

    // S12: icon circle с опциональным matchedGeometryEffect.
    @ViewBuilder
    private var iconCircle: some View {
        let base = Image(systemName: icon)
            .font(TypographyTokens.title(26))
            .foregroundStyle(color)
            .frame(width: 56, height: 56)
            .background(Circle().fill(color.opacity(0.12)))
            .accessibilityHidden(true)

        if !reduceMotion, let heroId, let namespace {
            base.matchedGeometryEffect(id: heroId, in: namespace)
        } else {
            base
        }
    }
}

// MARK: - WorldMapMiniPreview

struct ChildHomeWorldMapMiniPreview: View {

    let zones: [ChildHomeModels.WorldZonePreview]
    let onZoneTap: (ChildHomeModels.WorldZonePreview) -> Void

    var body: some View {
        HSLiquidGlassCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                ForEach(zones) { zone in
                    Button {
                        onZoneTap(zone)
                    } label: {
                        ChildHomeWorldZoneBubble(zone: zone)
                    }
                    .buttonStyle(.plain)
                    .tapFeedback()
                    .accessibilityLabel(Text(String.localizedStringWithFormat(
                        String(localized: "child.home.world.zone.a11y"),
                        zone.sound, zone.progressPercent
                    )))
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct ChildHomeWorldZoneBubble: View {

    let zone: ChildHomeModels.WorldZonePreview

    private var familyColor: Color {
        ColorTokens.SoundFamilyColors.hue(for: zone.family)
    }

    var body: some View {
        VStack(spacing: SpacingTokens.sp2) {
            ZStack {
                // Прогресс показывается через увеличение opacity заливки —
                // визуальная метафора «зона светится сильнее по мере прогресса».
                Circle()
                    .fill(familyColor.opacity(0.18))
                    .frame(width: 52, height: 52)

                Circle()
                    .fill(familyColor.opacity(0.10 + zone.progress * 0.55))
                    .frame(width: 48, height: 48)

                Image(systemName: zone.emoji)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(familyColor)
                    .accessibilityHidden(true)
            }
            .frame(width: 56, height: 56)

            Text(zone.sound)
                .font(TypographyTokens.caption(12).weight(.bold))
                .foregroundStyle(familyColor)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - MissionTimerLabel (B13 — TimelineView, обновляется раз в минуту)

/// Метка «Осталось N ч M мин» — компактный таймер до конца дня (полночь).
/// Использует `TimelineView(.periodic(...))`, обновление раз в 60 с — без Timer.publish.
struct ChildHomeMissionTimerLabel: View {

    /// Текущее время для расчёта (по умолчанию — `.now`, но можно передать
    /// для тестов / Preview'ев).
    let now: Date

    init(now: Date = Date()) {
        self.now = now
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let remaining = Self.timeUntilMidnight(from: context.date)
            HStack(spacing: 4) {
                Image(systemName: "hourglass")
                    .font(TypographyTokens.caption(11).weight(.semibold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .accessibilityHidden(true)

                Text(Self.formatRemaining(remaining))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, SpacingTokens.sp2)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(ColorTokens.Brand.primary.opacity(0.10))
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(Self.a11y(for: remaining)))
        }
    }

    // MARK: - Time math (внутренняя)

    private static func timeUntilMidnight(from date: Date) -> (hours: Int, minutes: Int) {
        let calendar = Calendar.current
        guard let startOfTomorrow = calendar.nextDate(
            after: date,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) else {
            return (0, 0)
        }
        let interval = max(0, startOfTomorrow.timeIntervalSince(date))
        let totalMinutes = Int(interval / 60)
        return (totalMinutes / 60, totalMinutes % 60)
    }

    private static func formatRemaining(_ remaining: (hours: Int, minutes: Int)) -> String {
        let prefix = String(localized: "child.home.time_left")
        if remaining.hours == 0 {
            let minutesFormat = String(localized: "child.home.time.minutes.format")
            let minutesText = String.localizedStringWithFormat(minutesFormat, remaining.minutes)
            return "\(prefix) \(minutesText)"
        }
        let hoursFormat = String(localized: "child.home.time.hours.format")
        let minutesFormat = String(localized: "child.home.time.minutes.short.format")
        let hoursText = String.localizedStringWithFormat(hoursFormat, remaining.hours)
        let minutesText = String.localizedStringWithFormat(minutesFormat, remaining.minutes)
        return "\(prefix) \(hoursText) \(minutesText)"
    }

    private static func a11y(for remaining: (hours: Int, minutes: Int)) -> String {
        let format = String(localized: "child.home.time.a11y")
        return String.localizedStringWithFormat(format, remaining.hours, remaining.minutes)
    }
}
