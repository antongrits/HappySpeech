import OSLog
import SwiftUI

// MARK: - SeasonalBannerView
//
// Горизонтальный banner (HSLiquidGlassCard) поверх ChildHome.
// Показывается только когда SeasonalEventsManager.shared.activeEvent != nil.
// Тапая → onTap колбэк (роутер ChildHome запускает сезонный урок).

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
            HSLiquidGlassCard {
                HStack(spacing: SpacingTokens.sp3) {
                    Image(systemName: event.iconName)
                        .font(.title2)
                        .foregroundStyle(event.accentColor)
                        .frame(width: 36, height: 36)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                        Text(event.localizedTitle)
                            .font(TypographyTokens.headline())
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Text(String(localized: "seasonal.banner.subtitle"))
                            .font(TypographyTokens.caption())
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }

                    Spacer(minLength: SpacingTokens.sp2)

                    Text(String(localized: "seasonal.banner.cta"))
                        .font(TypographyTokens.body())
                        .foregroundStyle(event.accentColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ColorTokens.Kid.inkSoft)
                        .accessibilityHidden(true)
                }
            }
        })
        .buttonStyle(.plain)
        .accessibilityLabel(event.localizedTitle)
        .accessibilityHint(String(localized: "seasonal.banner.subtitle"))
        .accessibilityAddTraits(.isButton)
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
