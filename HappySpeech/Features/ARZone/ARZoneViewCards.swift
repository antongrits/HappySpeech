import SwiftUI

// MARK: - ARZoneViewCards
//
// Карточки, фильтры и баннеры для `ARZoneView`.

// MARK: - ARDifficultyFilterChips

/// Набор chips для фильтра по сложности (Все / Легко / Средне / Сложно).
struct ARDifficultyFilterChips: View {
    @Binding var selected: ARDifficultyFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.small) {
                ForEach(ARDifficultyFilter.allCases, id: \.self) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selected = filter
                        }
                    } label: {
                        chip(for: filter, isActive: selected == filter)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(LocalizedStringResource(stringLiteral: filter.titleKey)))
                    .accessibilityAddTraits(selected == filter ? .isSelected : [])
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }

    private func chip(for filter: ARDifficultyFilter, isActive: Bool) -> some View {
        Text(LocalizedStringResource(stringLiteral: filter.titleKey))
            .font(TypographyTokens.body(13).weight(.semibold))
            .foregroundStyle(isActive ? ColorTokens.Overlay.onAccent : ColorTokens.Kid.ink)
            .padding(.horizontal, SpacingTokens.regular)
            .padding(.vertical, SpacingTokens.tiny)
            .background(
                Capsule().fill(
                    isActive
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [ColorTokens.Brand.primary, ColorTokens.Brand.lilac],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    : AnyShapeStyle(ColorTokens.Kid.surfaceAlt)
                )
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isActive ? Color.clear : ColorTokens.Kid.ink.opacity(0.08),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - ARFilterEmptyState

/// «Под этот фильтр игр нет» — мягкий empty-state.
struct ARFilterEmptyState: View {
    let filter: ARDifficultyFilter

    var body: some View {
        VStack(spacing: SpacingTokens.small) {
            Image(systemName: "magnifyingglass")
                .font(TypographyTokens.title(28).weight(.regular))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .accessibilityHidden(true)
            Text("ar.zone.filter.empty")
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.xLarge)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("ar.zone.filter.empty"))
    }
}

// MARK: - ARFallbackBannerView

/// Полноценный fallback-баннер для устройств без TrueDepth-камеры.
/// Содержит иконку, заголовок, объяснение и CTA «Открыть 2D-альтернативу».
struct ARFallbackBannerView: View {
    let onSelectFallback: () -> Void

    var body: some View {
        HSLiquidGlassCard(
            style: .tinted(ColorTokens.Semantic.warningBg),
            padding: SpacingTokens.large
        ) {
            VStack(spacing: SpacingTokens.regular) {
                ZStack {
                    Circle()
                        .fill(ColorTokens.Semantic.warning.opacity(0.18))
                        .frame(width: 64, height: 64)
                    Image(systemName: "iphone.gen3.slash")
                        .font(TypographyTokens.title(28).weight(.medium))
                        .foregroundStyle(ColorTokens.Semantic.warning)
                        .accessibilityHidden(true)
                }
                Text("ar.zone.unsupportedTitle")
                    .font(TypographyTokens.headline(18))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                Text("ar.zone.unsupportedBody")
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onSelectFallback) {
                    HStack(spacing: SpacingTokens.tiny) {
                        Image(systemName: "play.fill")
                            .accessibilityHidden(true)
                        Text("ar.zone.fallbackCTA")
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .padding(.horizontal, SpacingTokens.large)
                    .padding(.vertical, SpacingTokens.small)
                    .background(
                        Capsule().fill(ColorTokens.Semantic.warning)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("ar.zone.fallbackCTA"))
                .padding(.top, SpacingTokens.tiny)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - ARPlannerBannerView

/// Баннер рекомендации/предупреждения от AdaptivePlannerService.
/// Три варианта: recommended (звезда), fatigueWarning (zzz), fatigueLight (листик).
struct ARPlannerBannerView: View {
    let banner: ARPlannerBanner

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var iconBounce: Int = 0

    private var bannerStyle: HSLiquidGlassStyle {
        switch banner.variant {
        case .recommended:    return .tinted(ColorTokens.Brand.butter.opacity(0.22))
        case .fatigueWarning: return .tinted(ColorTokens.Semantic.warningBg)
        case .fatigueLight:   return .tinted(ColorTokens.Brand.mint.opacity(0.2))
        }
    }

    private var iconColor: Color {
        switch banner.variant {
        case .recommended:    return ColorTokens.Brand.gold
        case .fatigueWarning: return ColorTokens.Semantic.warning
        case .fatigueLight:   return ColorTokens.Brand.mint
        }
    }

    var body: some View {
        HSLiquidGlassCard(style: bannerStyle, padding: SpacingTokens.regular) {
            HStack(spacing: SpacingTokens.regular) {
                Image(systemName: banner.icon)
                    .font(TypographyTokens.title(24).weight(.semibold))
                    .foregroundStyle(iconColor)
                    .symbolEffect(.bounce.down, value: iconBounce)
                    .frame(width: 36)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(String(localized: String.LocalizationValue(banner.titleKey)))
                        .font(TypographyTokens.headline(14).weight(.semibold))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(String(localized: String.LocalizationValue(banner.bodyKey)))
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text(
                "\(String(localized: String.LocalizationValue(banner.titleKey))). " +
                "\(String(localized: String.LocalizationValue(banner.bodyKey)))"
            )
        )
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(MotionTokens.bounce.delay(0.4)) {
                iconBounce += 1
            }
        }
    }
}

// MARK: - ARGameCardView

struct ARGameCardView: View {
    let card: ARGameCard
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let colors = ARCardPalette.gradient(for: card.accentColorIndex)
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                HStack {
                    Image(systemName: card.iconName)
                        .font(TypographyTokens.title(30).weight(.medium))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .accessibilityHidden(true)
                    Spacer()
                    difficultyDots
                }
                Spacer(minLength: SpacingTokens.tiny)
                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(card.title)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    HStack(spacing: SpacingTokens.micro) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .accessibilityHidden(true)
                        Text("\(card.estimatedMinutes) мин")
                            .font(TypographyTokens.body(12))
                    }
                    .foregroundStyle(ColorTokens.Overlay.onAccent.opacity(0.85))
                }
            }
            .padding(SpacingTokens.regular)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(RadiusTokens.lg)
            .shadow(
                color: colors.first?.opacity(0.3) ?? ColorTokens.Overlay.shadow,
                radius: reduceMotion ? 0 : 8,
                x: 0, y: 4
            )

            // Бейдж от AdaptivePlannerService
            ARGameBadgeOverlay(badge: card.badge)
                .padding(.top, SpacingTokens.small)
                .padding(.trailing, SpacingTokens.small)
        }
    }

    private var difficultyDots: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(i < card.difficulty ? ColorTokens.Overlay.onAccent : ColorTokens.Overlay.highlight)
                    .frame(width: 6, height: 6)
            }
        }
    }
}

// MARK: - ARGameBadgeOverlay

/// Маленький бейдж в углу карточки AR-игры.
struct ARGameBadgeOverlay: View {
    let badge: ARGameBadge

    var body: some View {
        switch badge {
        case .recommendedByLyalya:
            badgeView(icon: "star.fill", color: ColorTokens.Brand.gold,
                      labelKey: "ar.zone.badge.recommended")
        case .newGame:
            badgeView(icon: "sparkles", color: ColorTokens.Brand.sky,
                      labelKey: "ar.zone.badge.new")
        case .completed:
            badgeView(icon: "checkmark.circle.fill", color: ColorTokens.Brand.mint,
                      labelKey: "ar.zone.badge.completed")
        case .none:
            EmptyView()
        }
    }

    private func badgeView(icon: String, color: Color, labelKey: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(TypographyTokens.caption(9))
                .accessibilityHidden(true)
            Text(String(localized: String.LocalizationValue(labelKey)))
                .font(TypographyTokens.body(9).weight(.bold))
        }
        .foregroundStyle(ColorTokens.Overlay.onAccent)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(color)
        )
        .shadow(color: color.opacity(0.4), radius: 4, x: 0, y: 2)
    }
}
