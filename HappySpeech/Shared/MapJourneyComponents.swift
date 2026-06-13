import SwiftUI

// MARK: - MapJourneyComponents
//
// Общий визуальный язык экранов-путешествий («карта приключений», эталон
// `references/kid-map.html`): шапка острова, плашка-пилюля звёзд, тонкий
// коралловый трек прогресса и нижняя CTA-карточка «текущий уровень».
//
// Применяется к WorldMap / SoundExplorerMap / PhonemeJourneyMap /
// ObjectDescriptionMap, чтобы все «карты звуков» читались как один продукт.
// Только View-слой: ни бизнес-логики, ни сетевых вызовов — компоненты
// получают готовые строки/дроби из Presenter/ViewModel.
//
// Тёплая палитра DesignSystem: coral (primary), butter/gold (звёзды), lilac
// (мягкие тинты островов). Никаких off-palette зелёных/синих заливок.

// MARK: - MapJourneyHeader

/// Шапка экрана-путешествия по эталону: круглая кнопка-«назад» (или иконка
/// острова) слева, заголовок острова + подзаголовок звуков по центру, плашка
/// собранных звёзд (butter/gold) справа и тонкий коралловый трек прогресса под
/// строкой. Симметричные отступы, без обрезки текста.
struct MapJourneyHeader: View {

    let title: String
    let subtitle: String
    /// Текст внутри плашки-пилюли (например «12»). Метка «из 30» — `starsTotal`.
    let starsCollected: String
    /// Опциональный «из N». Если `nil` — показывается только `starsCollected`.
    let starsTotal: String?
    /// Доля прогресса 0…1 для кораллового трека.
    let progress: Double
    /// SF Symbol для leading-кнопки. По умолчанию — стрелка «назад».
    var leadingIcon: String = "chevron.left"
    /// Действие leading-кнопки. Если `nil` — кнопка не интерактивна (иконка).
    var onLeadingTap: (() -> Void)? = nil
    var reduceMotion: Bool = false

    var body: some View {
        VStack(spacing: SpacingTokens.small) {
            HStack(spacing: SpacingTokens.small) {
                leadingButton

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(TypographyTokens.title(20).weight(.bold))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(TypographyTokens.caption(13).weight(.semibold))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                starsPill
            }

            progressTrack
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.tiny)
        .padding(.bottom, SpacingTokens.small)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: Leading button

    @ViewBuilder
    private var leadingButton: some View {
        if let onLeadingTap {
            Button(action: onLeadingTap) {
                leadingChrome
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "action.back", defaultValue: "Назад"))
        } else {
            leadingChrome
                .accessibilityHidden(true)
        }
    }

    private var leadingChrome: some View {
        Image(systemName: leadingIcon)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(ColorTokens.Kid.ink)
            .frame(width: 42, height: 42)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
            )
            .shadow(color: ColorTokens.Overlay.shadow, radius: 4, y: 2)
    }

    // MARK: Stars pill

    private var starsPill: some View {
        HStack(spacing: SpacingTokens.micro) {
            Image(systemName: "star.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(ColorTokens.Brand.gold)
            Text(starsCollected)
                .font(TypographyTokens.headline(15).weight(.bold))
                .foregroundStyle(ColorTokens.Brand.gold)
            if let starsTotal {
                Text(starsTotal)
                    .font(TypographyTokens.caption(13).weight(.semibold))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .padding(.horizontal, SpacingTokens.small)
        .padding(.vertical, SpacingTokens.tiny)
        .background(
            Capsule(style: .continuous)
                .fill(ColorTokens.Brand.butter.opacity(0.32))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(ColorTokens.Brand.butter.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: ColorTokens.Brand.gold.opacity(0.16), radius: 6, y: 3)
        .accessibilityHidden(true)
    }

    // MARK: Progress track

    private var progressTrack: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(ColorTokens.Kid.line)
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, min(1, progress)) * proxy.size.width)
                    .shadow(color: ColorTokens.Brand.primary.opacity(0.45), radius: 3, y: 1)
                    .animation(reduceMotion ? nil : MotionTokens.smooth, value: progress)
            }
        }
        .frame(height: 9)
        .accessibilityHidden(true)
    }

    private var accessibilityLabel: String {
        let starsPart = starsTotal.map { "\(starsCollected) \($0)" } ?? starsCollected
        let percent = Int((max(0, min(1, progress)) * 100).rounded())
        return "\(title). \(subtitle). \(starsPart). \(percent)%"
    }
}

// MARK: - MapLevelCTACard

/// Нижняя карточка «текущий уровень» по эталону: квадратный коралловый бейдж
/// (буква звука / иконка), надстрочная метка + название уровня и коралловая
/// кнопка «Играть». Поднимается над контентом как sticky-футер.
struct MapLevelCTACard: View {

    /// Короткий символ для бейджа (буква звука «Ц» или 1–2 символа). Если пусто
    /// — показывается `badgeSystemImage`.
    let badgeText: String
    /// SF Symbol-иконка бейджа, если `badgeText` пуст.
    var badgeSystemImage: String = "play.fill"
    /// Надстрочная метка (например «Текущий уровень»).
    let kicker: String
    /// Название уровня/действия.
    let levelTitle: String
    /// Текст кнопки.
    let actionTitle: String
    var actionIcon: String = "play.fill"
    /// Заблокирована ли карточка (кнопка приглушена, иконка — замок).
    var isLocked: Bool = false
    var reduceMotion: Bool = false
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        HStack(spacing: SpacingTokens.small) {
            badge

            VStack(alignment: .leading, spacing: 1) {
                Text(kicker)
                    .font(TypographyTokens.caption(11).weight(.bold))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(levelTitle)
                    .font(TypographyTokens.headline(16).weight(.bold))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            playButton
        }
        .padding(.horizontal, SpacingTokens.regular)
        .padding(.vertical, SpacingTokens.small)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(ColorTokens.Kid.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
                )
                .shadow(color: ColorTokens.Brand.primary.opacity(0.22), radius: 18, y: 8)
                .shadow(color: ColorTokens.Overlay.shadow, radius: 6, y: 2)
        )
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kicker). \(levelTitle)")
        .accessibilityHint(actionTitle)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Badge

    private var badge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isLocked
                            ? [ColorTokens.Kid.bgSoft, ColorTokens.Kid.surfaceAlt]
                            : [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 46, height: 46)
                .shadow(
                    color: (isLocked ? ColorTokens.Overlay.shadow : ColorTokens.Brand.primary.opacity(0.4)),
                    radius: 6, y: 3
                )
            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
            } else if !badgeText.isEmpty {
                Text(badgeText)
                    .font(TypographyTokens.title(22).weight(.black))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                Image(systemName: badgeSystemImage)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Play button

    private var playButton: some View {
        Button(action: { if !isLocked { onTap() } }) {
            HStack(spacing: SpacingTokens.micro) {
                Image(systemName: isLocked ? "lock.fill" : actionIcon)
                    .font(.system(size: 14, weight: .bold))
                Text(actionTitle)
                    .font(TypographyTokens.headline(16).weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .padding(.horizontal, SpacingTokens.medium)
            .frame(height: 48)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isLocked
                                ? [ColorTokens.Kid.inkSoft, ColorTokens.Kid.inkSoft]
                                : [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: (isLocked ? .clear : ColorTokens.Brand.primary.opacity(0.45)),
                        radius: 8, y: 4
                    )
            )
            .scaleEffect(isPressed && !reduceMotion && !isLocked ? 0.95 : 1.0)
            .animation(reduceMotion ? nil : MotionTokens.pressSpring, value: isPressed)
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel(actionTitle)
    }
}

// MARK: - Preview

#Preview("Map journey chrome") {
    ZStack {
        ColorTokens.Kid.bg.ignoresSafeArea()
        VStack {
            MapJourneyHeader(
                title: String(localized: "worldmap.island.sibilants"),
                subtitle: "С · З · Ц",
                starsCollected: "12",
                starsTotal: String(localized: "worldMap.stars.of", defaultValue: "из 30"),
                progress: 0.4,
                onLeadingTap: {}
            )
            Spacer()
            MapLevelCTACard(
                badgeText: "Ц",
                kicker: String(localized: "worldMap.cta.kicker", defaultValue: "Текущий уровень"),
                levelTitle: "Звук Ц · Свистелочка",
                actionTitle: String(localized: "action.play", defaultValue: "Играть"),
                onTap: {}
            )
            .padding(.bottom, SpacingTokens.regular)
        }
    }
}
