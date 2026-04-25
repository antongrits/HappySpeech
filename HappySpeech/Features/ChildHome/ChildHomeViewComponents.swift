// swiftlint:disable file_length
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
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTokens.Semantic.warning)

                Text("\(streak)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
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
            VStack(spacing: SpacingTokens.sp4) {
                topRow
                progressBlock
                if mission.isCompleted {
                    completedRow
                }
            }
            .padding(SpacingTokens.cardPad)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .kidCardShadow()
            )
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
                .font(.system(size: 32))
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
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(accentColor)
                }

                Spacer(minLength: 0)

                Text(item.title)
                    .font(TypographyTokens.headline(14))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
                    .ctaTextStyle()
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
        .accessibilityHint(String(localized: "child.home.quick.a11y.hint"))
    }
}

// MARK: - QuickActionTile (legacy 2x2 tile)

struct ChildHomeQuickActionTile: View {

    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: SpacingTokens.sp2) {
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundStyle(color)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(color.opacity(0.12)))

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
}

// MARK: - WorldMapMiniPreview

struct ChildHomeWorldMapMiniPreview: View {

    let zones: [ChildHomeModels.WorldZonePreview]
    let onZoneTap: (ChildHomeModels.WorldZonePreview) -> Void

    var body: some View {
        HSCard(style: .elevated) {
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
                    .font(.system(size: 22))
            }
            .frame(width: 56, height: 56)

            Text(zone.sound)
                .font(.system(size: 12, weight: .bold, design: .rounded))
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
                    .font(.system(size: 22, weight: .black, design: .rounded))
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
                        .font(.system(size: 16, weight: .black, design: .rounded))
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
                    .font(.system(size: 16))
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
        HSCard(style: .tinted(ColorTokens.Brand.gold.opacity(0.18))) {
            HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                Text(achievement.emoji)
                    .font(.system(size: 36))
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
                        .font(.system(size: 22))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }
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
                    .font(.system(size: 22))
                    .foregroundStyle(ColorTokens.Brand.primary)
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
                    .font(.system(size: 20))
                    .foregroundStyle(ColorTokens.Brand.sky)
                Text(String(localized: "child.home.recent.empty"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                Spacer()
            }
        }
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
