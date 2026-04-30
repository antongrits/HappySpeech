import OSLog
import SwiftUI

// MARK: - ChildHomeViewComponents
//
// Подкомпоненты для `ChildHomeView`. Все компоненты — `internal` внутри
// модуля HappySpeech (не `private`), чтобы быть доступными из
// `ChildHomeView.swift`. Каждый — самодостаточный view без бизнес-логики.

// MARK: - CloudDecoration

struct ChildHomeCloudDecoration: View {

    private struct CloudSpec {
        let width: CGFloat
        let height: CGFloat
        let offsetX: CGFloat
        let offsetY: CGFloat
        let blur: CGFloat
        let opacity: Double
    }

    private static let specs: [CloudSpec] = [
        .init(width: 140, height: 70, offsetX: -90, offsetY: 80, blur: 22, opacity: 0.6),
        .init(width: 100, height: 50, offsetX: 110, offsetY: 110, blur: 18, opacity: 0.45),
        .init(width: 80, height: 40, offsetX: -40, offsetY: 200, blur: 16, opacity: 0.35)
    ]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(0..<Self.specs.count, id: \.self) { index in
                cloud(spec: Self.specs[index])
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .offset(x: phase)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                phase = 12
            }
        }
    }

    private func cloud(spec: CloudSpec) -> some View {
        Ellipse()
            .fill(Color.white.opacity(spec.opacity))
            .frame(width: spec.width, height: spec.height)
            .blur(radius: spec.blur)
            .offset(x: spec.offsetX, y: spec.offsetY)
            .accessibilityHidden(true)
    }
}

// MARK: - ReactiveMascot

struct ChildHomeReactiveMascot: View {

    let mood: MascotMood
    let reduceMotion: Bool

    @State private var bobOffset: CGFloat = 0

    var body: some View {
        // HSMascotView сам управляет внутренней анимацией крыльев / Rive.
        // Для Home добавляем мягкое «парение» сверху (если ReduceMotion = off).
        HSMascotView(mood: mood, size: 140)
            .offset(y: bobOffset)
            .onAppear { startBobbing() }
            .onChange(of: mood) { _, _ in startBobbing() }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "child.home.mascot.a11y"))
    }

    private func startBobbing() {
        guard !reduceMotion else {
            bobOffset = 0
            return
        }
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            bobOffset = -6
        }
    }
}

// MARK: - MascotBubble

struct ChildHomeMascotBubble: View {

    let text: String

    var body: some View {
        Text(text)
            .font(TypographyTokens.body(14))
            .foregroundStyle(ColorTokens.Kid.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, SpacingTokens.sp4)
            .padding(.vertical, SpacingTokens.sp3)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .kidTileShadow()
            )
            .padding(.horizontal, SpacingTokens.sp6)
    }
}

// MARK: - StreakBadge (with optional pulse ring)

struct ChildHomeStreakBadge: View {

    let streak: Int
    let isHot: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.55

    var body: some View {
        ZStack {
            if isHot {
                Circle()
                    .stroke(ColorTokens.Semantic.warning.opacity(pulseOpacity), lineWidth: 2)
                    .scaleEffect(pulse)
                    .frame(width: 60, height: 60)
                    .onAppear { startPulse() }
                    .accessibilityHidden(true)
            }

            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(TypographyTokens.caption(14))
                    .foregroundStyle(ColorTokens.Semantic.warning)
                    .accessibilityHidden(true)

                Text("\(streak)")
                    .font(TypographyTokens.caption(14).weight(.bold))
                    .foregroundStyle(ColorTokens.Semantic.warning)
            }
            .padding(.horizontal, SpacingTokens.sp3)
            .padding(.vertical, SpacingTokens.sp2)
            .background(Capsule().fill(ColorTokens.Semantic.warning.opacity(0.12)))
        }
        .accessibilityLabel(Text(String.localizedStringWithFormat(
            String(localized: "child.home.streak.a11y"),
            streak
        )))
    }

    private func startPulse() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            pulse = 1.25
            pulseOpacity = 0.0
        }
    }
}

// MARK: - SoundLetterBadge

struct ChildHomeSoundLetterBadge: View {

    let letter: String
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .fill(ColorTokens.Brand.primary.opacity(0.15))

            Text(letter)
                .font(.system(size: size * 0.5, weight: .black, design: .rounded))
                .foregroundStyle(ColorTokens.Brand.primary)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - DailyMissionDetailCard

struct ChildHomeDailyMissionDetailCard: View {

    let mission: ChildHomeModels.DailyMissionDetail
    let onTap: () -> Void

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

            Image(systemName: "play.circle.fill")
                .font(TypographyTokens.title(32))
                .foregroundStyle(ColorTokens.Brand.primary)
                .accessibilityHidden(true)
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
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
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
                    .kidCardShadow()
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
                    .kidCardShadow()
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

                Text(zone.emoji)
                    .font(TypographyTokens.title(22))
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

// MARK: - SoundProgressRow

struct ChildHomeSoundProgressRow: View {

    let item: ChildHomeModels.SoundProgressItem

    private var familyColor: Color {
        ColorTokens.SoundFamilyColors.hue(for: item.accent)
    }

    var body: some View {
        HSCard(style: .flat) {
            HStack(spacing: SpacingTokens.sp3) {
                Text(item.sound)
                    .font(TypographyTokens.title(22).weight(.black))
                    .foregroundStyle(familyColor)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.stageName)
                            .font(TypographyTokens.body(13))
                            .foregroundStyle(ColorTokens.Kid.ink)
                        Spacer()
                        Text(formatPercent(item.rate))
                            .font(TypographyTokens.mono(12))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                    }
                    HSProgressBar(value: item.rate, style: .kid, tint: familyColor)
                        .frame(height: 8)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String.localizedStringWithFormat(
            String(localized: "child.home.sound.row.a11y"),
            item.sound, item.stageName, Int(item.rate * 100)
        )))
    }

    private func formatPercent(_ rate: Double) -> String {
        "\(Int(rate * 100))%"
    }
}

// MARK: - RecentSessionRow

struct ChildHomeRecentSessionRow: View {

    let session: ChildHomeModels.RecentSession

    var body: some View {
        HSCard(style: .flat) {
            HStack(spacing: SpacingTokens.sp3) {
                ZStack {
                    Circle()
                        .fill(ColorTokens.Brand.mint.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Text(session.soundTarget)
                        .font(TypographyTokens.body(16).weight(.black))
                        .foregroundStyle(ColorTokens.Brand.mint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.gameTitle)
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(1)
                    Text(formattedDate)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }

                Spacer()

                Text(session.scoreEmoji)
                    .font(TypographyTokens.body(16))
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String.localizedStringWithFormat(
            String(localized: "child.home.recent.row.a11y"),
            session.gameTitle, session.soundTarget, Int(session.score * 100)
        )))
    }

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: session.date, relativeTo: Date())
    }
}

// MARK: - AchievementBanner

struct ChildHomeAchievementBanner: View {

    let achievement: ChildHomeModels.Achievement
    let onDismiss: () -> Void

    var body: some View {
        HSLiquidGlassCard(style: .tinted(ColorTokens.Brand.gold)) {
            HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                Text(achievement.emoji)
                    .font(TypographyTokens.display(36))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "child.home.achievement.kicker"))
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Brand.gold)
                        .textCase(.uppercase)
                        .tracking(1)

                    Text(achievement.title)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Text(achievement.description)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 0)

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(TypographyTokens.title(22))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .frame(width: 56, height: 56)
                        .contentShape(Rectangle())
                        .accessibilityHidden(true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "child.home.achievement.dismiss"))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(achievement.title). \(achievement.description)"))
    }
}

// MARK: - Empty states

struct ChildHomeEmptyProgressView: View {
    var body: some View {
        HSCard(style: .flat) {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: "sparkles")
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .accessibilityHidden(true)
                Text(String(localized: "child.home.progress.empty"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                Spacer()
            }
        }
    }
}

struct ChildHomeEmptyRecentView: View {
    var body: some View {
        HSCard(style: .flat) {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: "book.closed")
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Brand.sky)
                    .accessibilityHidden(true)
                Text(String(localized: "child.home.recent.empty"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                Spacer()
            }
        }
    }
}

// MARK: - StreakBanner (B13 — full-width banner, не путать со StreakBadge в hero)

/// Полноразмерная карточка-баннер серии занятий. Показывается между маскотом и
/// daily mission. Содержит огонёк, счётчик дней (plural) и call-to-action
/// «Не прерви серию!». Pulse-анимация раз в 3 секунды (если ReduceMotion = off).
/// Hidden, если streak == 0 — нечего поощрять.
struct ChildHomeStreakBanner: View {

    let streak: Int
    let isHot: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse: CGFloat = 1.0
    @State private var flameRotation: Double = 0

    var body: some View {
        HSLiquidGlassCard(style: .tinted(ColorTokens.Semantic.warning)) {
            HStack(alignment: .center, spacing: SpacingTokens.sp4) {
                flameIcon

                VStack(alignment: .leading, spacing: 2) {
                    Text(streakCountText)
                        .font(TypographyTokens.headline(18))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(String(localized: "child.home.streak.subtitle"))
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 0)

                if isHot {
                    hotChip
                }
            }
            .scaleEffect(pulse)
        }
        .onAppear { startPulse() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String.localizedStringWithFormat(
            String(localized: "child.home.streak.banner.a11y"),
            streak
        )))
    }

    private var flameIcon: some View {
        ZStack {
            Circle()
                .fill(ColorTokens.Semantic.warning.opacity(0.2))
                .frame(width: 56, height: 56)

            Image(systemName: "flame.fill")
                .font(TypographyTokens.title(28).weight(.bold))
                .foregroundStyle(ColorTokens.Semantic.warning)
                .rotationEffect(.degrees(flameRotation))
                .accessibilityHidden(true)
        }
    }

    private var hotChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(TypographyTokens.caption(11).weight(.bold))
            Text(String(localized: "child.home.streak.hot"))
                .font(TypographyTokens.caption(11).weight(.bold))
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .foregroundStyle(ColorTokens.Brand.gold)
        .padding(.horizontal, SpacingTokens.sp2)
        .padding(.vertical, 4)
        .background(Capsule().fill(ColorTokens.Brand.gold.opacity(0.18)))
        .accessibilityHidden(true)
    }

    private var streakCountText: String {
        let format = String(localized: "child.home.streak.format")
        return String.localizedStringWithFormat(format, streak)
    }

    private func startPulse() {
        guard !reduceMotion else {
            pulse = 1.0
            flameRotation = 0
            return
        }
        // Pulse каждые 3 секунды — лёгкий «вдох» карточки, не раздражает периферийное зрение.
        withAnimation(
            .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
                .delay(0.5)
        ) {
            pulse = 1.025
        }
        withAnimation(
            .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
        ) {
            flameRotation = 6
        }
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

// MARK: - RecentRewardRow (B13)

/// Строка в секции «Недавние достижения». Не путать с `RecentSessionRow` —
/// здесь именно награды (emoji + название), без оценки и шаблона игры.
struct ChildHomeRecentRewardRow: View {

    let reward: ChildHomeModels.RecentReward

    var body: some View {
        HSCard(style: .flat) {
            HStack(spacing: SpacingTokens.sp3) {
                ZStack {
                    Circle()
                        .fill(ColorTokens.Brand.gold.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Text(reward.emoji)
                        .font(TypographyTokens.title(22))
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(reward.title)
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(formattedDate)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(TypographyTokens.caption(12).weight(.semibold))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(reward.emoji) \(reward.title). \(formattedDate)"))
    }

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: reward.earnedAt, relativeTo: Date())
    }
}

// MARK: - EmptyRewardsView (B13)

struct ChildHomeEmptyRewardsView: View {
    var body: some View {
        HSCard(style: .flat) {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: "trophy")
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Brand.gold)
                    .accessibilityHidden(true)
                Text(String(localized: "child.home.rewards.empty"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                Spacer()
            }
        }
    }
}

// MARK: - TodayWordCard (M8.7 v6)
//
// Карточка слова дня в горизонтальной карусели «Слова дня».
// Размер: 90×100, rounded.

struct ChildHomeTodayWordCard: View {

    let word: ChildHomeModels.TodayWord

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tapped = false

    var body: some View {
        Button {
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                tapped = true
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                tapped = false
            }
        } label: {
            VStack(spacing: SpacingTokens.sp2) {
                // Буква звука
                ZStack {
                    Circle()
                        .fill(ColorTokens.Brand.primary.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Text(word.targetSound)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(ColorTokens.Brand.primary)
                }
                .accessibilityHidden(true)

                Text(word.word)
                    .font(TypographyTokens.headline(13))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)

                Text(word.syllables)
                    .font(TypographyTokens.mono(11))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(word.positionEmoji)
                    .font(.system(size: 12))
                    .accessibilityHidden(true)
            }
            .padding(.vertical, SpacingTokens.sp3)
            .padding(.horizontal, SpacingTokens.sp3)
            .frame(width: 88)
            .frame(minHeight: 104)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .kidTileShadow()
            )
            .scaleEffect(tapped ? 0.92 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            String(format: String(localized: "child.home.today.word.a11y"),
                   word.word, word.syllables)
        )
        .accessibilityHint(String(localized: "child.home.today.word.play.hint"))
    }
}

// MARK: - HomeTaskPreviewRow (M8.7 v6)
//
// Строка задания от логопеда в preview-секции на ChildHome.

struct ChildHomeTaskPreviewRow: View {

    let task: ChildHomeModels.HomeTaskPreview
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: SpacingTokens.sp3) {
                ZStack {
                    Circle()
                        .fill(task.isCompleted
                              ? ColorTokens.Semantic.success.opacity(0.12)
                              : ColorTokens.Brand.primary.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "doc.badge.arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(task.isCompleted
                                         ? ColorTokens.Semantic.success
                                         : ColorTokens.Brand.primary)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(TypographyTokens.headline(14))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    HStack(spacing: SpacingTokens.sp2) {
                        Text(task.targetSound)
                            .font(TypographyTokens.mono(11))
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(ColorTokens.Brand.primary.opacity(0.10))
                            )

                        if task.isOverdue {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(ColorTokens.Semantic.error)
                                .accessibilityHidden(true)
                        }
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorTokens.Kid.line)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.sp3)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .kidTileShadow()
            )
        }
        .buttonStyle(.plain)
        .tapFeedback()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(task.title). \(task.targetSound)")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Helpers / extensions (shared with ChildHomeView)

extension String {
    var capitalizedFirstLetter: String {
        guard let first = first else { return self }
        return first.uppercased() + dropFirst()
    }
}

extension ColorTokens {
    /// Маппинг QuickPlayAccent → Color (используется в `ChildHomeQuickPlayCard`).
    static func color(for accent: ChildHomeModels.QuickPlayAccent) -> Color {
        switch accent {
        case .coral:  return ColorTokens.Brand.primary
        case .mint:   return ColorTokens.Brand.mint
        case .sky:    return ColorTokens.Brand.sky
        case .butter: return ColorTokens.Brand.butter
        case .lilac:  return ColorTokens.Brand.lilac
        case .gold:   return ColorTokens.Brand.gold
        case .rose:   return ColorTokens.Brand.rose
        }
    }
}
