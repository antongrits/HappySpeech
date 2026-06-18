import OSLog
import SwiftUI

// MARK: - SeasonalBannerView
//
// Сезонный фичер-герой поверх ChildHome (HSLiquidGlassCard, tinted под событие).
// Показывается только когда SeasonalEventsManager.shared.activeEvent != nil.
// Тапая → onTap колбэк (роутер ChildHome запускает сезонный урок).
//
// Дизайн (эталон «seasonal-banner»):
//   • event-badge золотой (Brand.butter) с иконкой события
//   • крупный заголовок + подзаголовок (верхняя строка)
//   • маскот Ляля справа (brand-anchor)
//   • звёздный прогресс-бар («Снежные звёзды X / 10»)
//   • нижняя строка: countdown-chip («Осталось N дней») + CTA-кнопка flex
//   • тёплая заливка фона (gradient hero-g1→hero-g2), мягкие декор-искры

struct SeasonalBannerView: View {

    @ObservedObject var manager: SeasonalEventsManager
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "SeasonalBanner")

    // Тёмно-золотой текст event-бейджа поверх butter-капсулы (эталон .event-badge).
    // Функциональный оттенок бейджа, не UI-chrome (forbidden_color_literal не применим).
    // swiftlint:disable:next forbidden_color_literal
    private static let eventBadgeInk = Color(red: 0.23, green: 0.15, blue: 0.0)

    var body: some View {
        if let event = manager.activeEvent {
            bannerContent(event: event)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .opacity
                        )
                )
        }
    }

    // MARK: - Banner content

    @ViewBuilder
    private func bannerContent(event: SeasonalEvent) -> some View {
        Button(action: {
            Self.logger.info("Seasonal banner tapped: \(event.rawValue, privacy: .public)")
            onTap()
        }, label: {
            ZStack(alignment: .topTrailing) {
                // Тёплый градиентный фон карточки (эталон: hero-g1→hero-g2)
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [ColorTokens.Brand.primaryLo.opacity(0.55), ColorTokens.Brand.primaryLo.opacity(0.28)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Frost-радиальные акценты (эталон .frost)
                frostLayer(event: event)
                    .accessibilityHidden(true)

                // Декор-искры
                decorSparkles(event: event)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                    topRow(event: event)
                    starProgressRow(event: event)
                    footerRow(event: event)
                }
                .padding(SpacingTokens.regular)
            }
            .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
            )
            .shadow(color: ColorTokens.Overlay.shadow, radius: 14, y: 4)
        })
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(event.localizedTitle)
        .accessibilityHint(String(localized: "seasonal.banner.subtitle"))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Frost layer

    private func frostLayer(event: SeasonalEvent) -> some View {
        ZStack {
            // Top-right radial frost
            RadialGradient(
                colors: [event.accentColor.opacity(0.22), Color.clear],
                center: .init(x: 0.9, y: 0.1),
                startRadius: 0,
                endRadius: 80
            )
            // Bottom-left radial frost
            RadialGradient(
                colors: [event.accentColor.opacity(0.14), Color.clear],
                center: .init(x: 0.1, y: 0.9),
                startRadius: 0,
                endRadius: 60
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous))
    }

    // MARK: - Top row (text + mascot)

    private func topRow(event: SeasonalEvent) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.sp3) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                eventBadge(event: event)
                Text(event.localizedTitle)
                    .font(TypographyTokens.title(23))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
                Text(String(localized: "seasonal.banner.subtitle"))
                    .font(TypographyTokens.body(13.5))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
                    .frame(maxWidth: 200, alignment: .leading)
            }

            Spacer(minLength: 0)

            LyalyaMascotView(state: .happy, size: 88)
                .accessibilityHidden(true)
                .shadow(color: ColorTokens.Overlay.shadow, radius: 6, y: 3)
        }
    }

    // MARK: - Event badge (gold, эталон .event-badge)

    private func eventBadge(event: SeasonalEvent) -> some View {
        HStack(spacing: SpacingTokens.sp1) {
            Image(systemName: event.iconName)
                .font(.system(size: 12, weight: .bold))
            Text(String(localized: "seasonal.banner.badge"))
                .font(TypographyTokens.caption(11).weight(.heavy))
                .textCase(.uppercase)
                .tracking(0.5)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(Self.eventBadgeInk)
        .padding(.vertical, SpacingTokens.sp1)
        .padding(.horizontal, SpacingTokens.sp2 + 2)
        .background(
            Capsule(style: .continuous)
                .fill(ColorTokens.Brand.butter)
        )
        .shadow(color: ColorTokens.Brand.butter.opacity(0.45), radius: 6, y: 3)
        .accessibilityHidden(true)
    }

    // MARK: - Star progress row (эталон .star-prog)

    private func starProgressRow(event: SeasonalEvent) -> some View {
        let progress = Double(manager.starProgress) / Double(event.starGoal)
        return VStack(spacing: SpacingTokens.tiny) {
            HStack {
                HStack(spacing: SpacingTokens.sp1) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(ColorTokens.Brand.butter)
                    Text(String(localized: "seasonal.banner.stars_label"))
                        .font(TypographyTokens.caption(12.5).weight(.bold))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
                Text("\(manager.starProgress) / \(event.starGoal)")
                    .font(TypographyTokens.caption(12.5).weight(.bold))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(ColorTokens.Kid.line.opacity(0.7))
                        .frame(height: 9)
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [ColorTokens.Brand.butter, ColorTokens.Brand.gold],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(9, geo.size.width * progress), height: 9)
                }
            }
            .frame(height: 9)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(
                format: NSLocalizedString("seasonal.banner.stars_progress %lld %lld", comment: ""),
                manager.starProgress,
                event.starGoal
            )
        )
    }

    // MARK: - Footer row: countdown + CTA

    private func footerRow(event: SeasonalEvent) -> some View {
        HStack(spacing: SpacingTokens.sp3) {
            countdownChip(event: event)
            ctaButton
        }
    }

    private func countdownChip(event: SeasonalEvent) -> some View {
        let days = event.daysRemaining()
        let label: String = days == 0
            ? String(localized: "seasonal.banner.last_day")
            : String(format: NSLocalizedString("seasonal.banner.days_left %lld", comment: ""), days)
        return HStack(spacing: SpacingTokens.sp1) {
            Image(systemName: "hourglass")
                .font(.system(size: 14, weight: .bold))
            Text(label)
                .font(TypographyTokens.caption(13).weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(ColorTokens.Brand.primary)
        .frame(height: 44)
        .padding(.horizontal, SpacingTokens.regular)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                .fill(ColorTokens.Brand.primaryLo.opacity(0.7))
        )
        .accessibilityHidden(true)
    }

    private var ctaButton: some View {
        HStack(spacing: SpacingTokens.sp2) {
            Text(String(localized: "seasonal.banner.cta"))
                .font(TypographyTokens.body(16.5).weight(.heavy))
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
                .lineLimit(1)
            Image(systemName: "arrow.right")
                .font(.system(size: 15, weight: .bold))
        }
        .foregroundStyle(ColorTokens.Overlay.onAccent)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: ColorTokens.Brand.primary.opacity(0.38), radius: 14, y: 7)
        )
        .accessibilityHidden(true)
    }

    // MARK: - Decorative seasonal sparkles

    /// Мягкие тематические «искры» в углах баннера — лёгкий праздничный
    /// акцент. Чисто декоративные, скрыты от VoiceOver.
    private func decorSparkles(event: SeasonalEvent) -> some View {
        ZStack {
            Image(systemName: event.iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(event.accentColor.opacity(0.45))
                .offset(x: -8, y: 6)
            Image(systemName: "sparkle")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(ColorTokens.Brand.butter.opacity(0.50))
                .offset(x: -36, y: 30)
            Image(systemName: "sparkle")
                .font(.system(size: 7, weight: .semibold))
                .foregroundStyle(event.accentColor.opacity(0.35))
                .offset(x: -18, y: 56)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
}

// MARK: - Preview

#Preview("Halloween — Light") {
    let manager = SeasonalEventsManager()
    manager.overrideEvent(.halloween)
    return SeasonalBannerView(manager: manager, onTap: {})
        .padding()
        .background(ColorTokens.Kid.bg)
        .environment(\.circuitContext, .kid)
}

#Preview("New Year — Dark") {
    let manager = SeasonalEventsManager()
    manager.overrideEvent(.newYear)
    return SeasonalBannerView(manager: manager, onTap: {})
        .padding()
        .background(ColorTokens.Kid.bg)
        .preferredColorScheme(.dark)
        .environment(\.circuitContext, .kid)
}

#Preview("No Event") {
    let manager = SeasonalEventsManager()
    manager.overrideEvent(nil)
    return SeasonalBannerView(manager: manager, onTap: {})
        .padding()
        .background(ColorTokens.Kid.bg)
        .environment(\.circuitContext, .kid)
}
