import OSLog
import SwiftUI

// MARK: - ChildHomeViewListComponents
//
// Подкомпоненты для `ChildHomeView`, относящиеся к спискам/строкам прогресса,
// баннерам достижений и серий, карточкам слова дня и пустым состояниям.
// Извлечено из `ChildHomeViewComponents.swift` (Block K.1 v16) для
// удержания LOC ≤500. Все компоненты — `internal` внутри модуля.

// MARK: - SoundProgressRow

struct ChildHomeSoundProgressRow: View {

    let item: ChildHomeModels.SoundProgressItem

    private var familyColor: Color {
        ColorTokens.SoundFamilyColors.hue(for: item.accent)
    }

    var body: some View {
        HSCard(style: .elevated) {
            HStack(spacing: 0) {
                // Left colour accent border keyed to sound family
                RoundedRectangle(cornerRadius: RadiusTokens.xs, style: .continuous)
                    .fill(familyColor)
                    .frame(width: 4)
                    .padding(.vertical, SpacingTokens.sp1)
                    .accessibilityHidden(true)

                HStack(spacing: SpacingTokens.sp3) {
                    ZStack {
                        Circle()
                            .fill(familyColor.opacity(0.14))
                            .frame(width: 40, height: 40)
                        Text(item.sound)
                            .font(TypographyTokens.title(20).weight(.black))
                            .foregroundStyle(familyColor)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.stageName)
                                .font(TypographyTokens.body(13))
                                .foregroundStyle(ColorTokens.Kid.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Spacer()
                            Text(formatPercent(item.rate))
                                .font(TypographyTokens.mono(12))
                                .foregroundStyle(ColorTokens.Kid.inkMuted)
                        }
                        HSProgressBar(value: item.rate, style: .kid, tint: familyColor)
                            .frame(height: 8)
                    }
                }
                .padding(.leading, SpacingTokens.sp3)
            }
        }
        // Block J v18 — kavsoft-style tilt carousel scroll transition.
        .hsScrollEffect(.tiltCarousel)
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

    /// Sound-family accent colour for the left border and sound-letter circle.
    private var familyAccentColor: Color {
        let hissing = ["Ш", "Ж", "Ч", "Щ"]
        let whistling = ["С", "З", "Ц"]
        let sonorant = ["Р", "Рь", "Л", "Ль"]
        let sound = session.soundTarget
        if hissing.contains(sound) { return ColorTokens.SoundFamilyColors.Hissing.hue }
        if whistling.contains(sound) { return ColorTokens.SoundFamilyColors.Whistling.hue }
        if sonorant.contains(sound) { return ColorTokens.SoundFamilyColors.Sonorant.hue }
        return ColorTokens.SoundFamilyColors.Velar.hue
    }

    var body: some View {
        HSCard(style: .elevated) {
            HStack(spacing: 0) {
                // Left colour accent border keyed to sound family
                RoundedRectangle(cornerRadius: RadiusTokens.xs, style: .continuous)
                    .fill(familyAccentColor)
                    .frame(width: 4)
                    .padding(.vertical, SpacingTokens.sp1)
                    .accessibilityHidden(true)

                HStack(spacing: SpacingTokens.sp3) {
                    ZStack {
                        Circle()
                            .fill(familyAccentColor.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Text(session.soundTarget)
                            .font(TypographyTokens.body(16).weight(.black))
                            .foregroundStyle(familyAccentColor)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.gameTitle)
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Text(formattedDate)
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                    }

                    Spacer()

                    HStack(spacing: 1) {
                        ForEach(0..<session.scoreStars, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(TypographyTokens.caption(12))
                                .foregroundStyle(ColorTokens.Brand.gold)
                        }
                    }
                    .accessibilityHidden(true)
                }
                .padding(.leading, SpacingTokens.sp3)
            }
        }
        // Block J v18 — kavsoft-style tilt carousel scroll transition.
        .hsScrollEffect(.tiltCarousel)
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
                Image(systemName: achievement.emoji)
                    .font(.system(size: 36, weight: .regular))
                    .foregroundStyle(ColorTokens.Brand.gold)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "child.home.achievement.kicker"))
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Brand.gold)
                        .textCase(.uppercase)
                        .tracking(1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    // Fix (text truncation) — заголовок «Отличная серия!» и
                    // описание ачивки не должны усекаться «…». Снимаем жёсткий
                    // lineLimit, переносим текст полностью через fixedSize(vertical).
                    Text(achievement.title)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(achievement.description)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
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

                VStack(alignment: .leading, spacing: 3) {
                    // Fix (text truncation, SE 375pt) — заголовок «7 дней подряд»
                    // ранее имел .lineLimit(1) и при наличии чипа «В ударе» в той
                    // же строке усекался («7 дней под…»). Теперь .lineLimit(2) +
                    // .fixedSize(vertical) гарантируют полный перенос без «…»,
                    // а чип «В ударе» вынесен под текст (см. ниже), чтобы не
                    // конкурировал за ширину строки на узком экране.
                    HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.sp2) {
                        Text(streakCountText)
                            .font(TypographyTokens.headline(18))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .fixedSize(horizontal: false, vertical: true)

                        if isHot {
                            hotChip
                        }
                    }

                    Text(String(localized: "child.home.streak.subtitle"))
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
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
                .symbolEffect(.bounce, value: streak)
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
        .padding(.vertical, SpacingTokens.micro)
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

// MARK: - StartStreakBanner (первый запуск — приглашение начать серию)
//
// Полноразмерный дружелюбный баннер, показывается между маскотом и daily
// mission, когда серия == 0. Заменяет пустоту скрытого `ChildHomeStreakBanner`
// дружелюбным «Начни серию сегодня!» (defect #4). Тёплый коралловый стиль,
// без обрезки текста (fixedSize vertical), tap → DailyStreakView.

struct ChildHomeStartStreakBanner: View {

    var body: some View {
        HSLiquidGlassCard(style: .tinted(ColorTokens.Brand.primary)) {
            HStack(alignment: .center, spacing: SpacingTokens.sp4) {
                ZStack {
                    Circle()
                        .fill(ColorTokens.Brand.primary.opacity(0.16))
                        .frame(width: 56, height: 56)
                    Image(systemName: "flame")
                        .font(TypographyTokens.title(28).weight(.bold))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "child.home.streak.start"))
                        .font(TypographyTokens.headline(18))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(String(localized: "child.home.streak.start.subtitle"))
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String(localized: "child.home.streak.start"))
            + Text(". ")
            + Text(String(localized: "child.home.streak.start.subtitle")))
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
                    Image(systemName: reward.emoji)
                        .font(TypographyTokens.title(22))
                        .foregroundStyle(ColorTokens.Brand.gold)
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
        .accessibilityLabel(Text("\(reward.title). \(formattedDate)"))
    }

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: reward.earnedAt, relativeTo: Date())
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
                        .font(TypographyTokens.kidDisplay(17))
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

                Image(systemName: word.positionSymbol)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
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
                // Part 2: completed task icon → Brand.gold.opacity(0.12) + Brand.gold
                ZStack {
                    Circle()
                        .fill(task.isCompleted
                              ? ColorTokens.Brand.gold.opacity(0.12)
                              : ColorTokens.Brand.primary.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "doc.badge.arrow.up")
                        .font(TypographyTokens.subtitle(18))
                        .foregroundStyle(task.isCompleted
                                         ? ColorTokens.Brand.gold
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
                            .padding(.horizontal, SpacingTokens.tiny)
                            .padding(.vertical, SpacingTokens.micro / 2)
                            .background(
                                Capsule()
                                    .fill(ColorTokens.Brand.primary.opacity(0.10))
                            )

                        if task.isOverdue {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(TypographyTokens.caption(12))
                                .foregroundStyle(ColorTokens.Semantic.error)
                                .accessibilityHidden(true)
                        }
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(TypographyTokens.labelRounded(13))
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
