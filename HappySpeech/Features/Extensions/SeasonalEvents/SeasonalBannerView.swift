import OSLog
import SwiftUI

// MARK: - SeasonalBannerView
//
// Сезонный фичер-герой поверх ChildHome (HSLiquidGlassCard, tinted под событие).
// Показывается только когда SeasonalEventsManager.shared.activeEvent != nil.
// Тапая → onTap колбэк (роутер ChildHome запускает сезонный урок).
//
// Дизайн (эталон «seasonal-banner»): event-badge + крупный заголовок + подзаголовок,
// маскот Ляля как brand-anchor, мягкие тематические «искры»-snow декор поверх
// тёплой заливки и коралловая CTA. Тёплая палитра; accentColor события —
// мелкий семантический акцент (badge / иконки), НЕ крупная холодная заливка.

struct SeasonalBannerView: View {

    @ObservedObject var manager: SeasonalEventsManager
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "SeasonalBanner")

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
            HSLiquidGlassCard(style: .tinted(event.accentColor)) {
                ZStack(alignment: .topTrailing) {
                    decorSparkles(event: event)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                        topRow(event: event)
                        ctaRow(event: event)
                    }
                }
            }
        })
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(event.localizedTitle)
        .accessibilityHint(String(localized: "seasonal.banner.subtitle"))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Top row (text + mascot)

    private func topRow(event: SeasonalEvent) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.sp3) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                eventBadge(event: event)
                Text(event.localizedTitle)
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                Text(String(localized: "seasonal.banner.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            LyalyaMascotView(state: .happy, size: 64)
                .accessibilityHidden(true)
        }
    }

    private func eventBadge(event: SeasonalEvent) -> some View {
        HStack(spacing: SpacingTokens.sp1) {
            Image(systemName: event.iconName)
                .font(.system(size: 12, weight: .bold))
            Text(String(localized: "seasonal.banner.badge"))
                .font(TypographyTokens.caption(11).weight(.heavy))
                .textCase(.uppercase)
                .tracking(0.6)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(ColorTokens.Kid.ink)
        .padding(.vertical, SpacingTokens.sp1)
        .padding(.horizontal, SpacingTokens.sp2)
        .background(
            Capsule(style: .continuous)
                .fill(event.accentColor.opacity(0.9))
        )
        .accessibilityHidden(true)
    }

    // MARK: - CTA row

    private func ctaRow(event: SeasonalEvent) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            HStack(spacing: SpacingTokens.sp1) {
                Text(String(localized: "seasonal.banner.cta"))
                    .font(TypographyTokens.body(15).weight(.heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .padding(.vertical, SpacingTokens.sp2)
            .padding(.horizontal, SpacingTokens.sp4)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: ColorTokens.Brand.primary.opacity(0.32), radius: 12, y: 6)
            )

            Spacer(minLength: 0)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Decorative seasonal sparkles

    /// Мягкие тематические «искры»/снежинки в углах баннера — лёгкий праздничный
    /// акцент. Чисто декоративные, скрыты от VoiceOver.
    private func decorSparkles(event: SeasonalEvent) -> some View {
        ZStack {
            Image(systemName: event.iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(event.accentColor.opacity(0.5))
                .offset(x: -6, y: 4)
            Image(systemName: "sparkle")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(ColorTokens.Brand.butter.opacity(0.55))
                .offset(x: -34, y: 28)
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
