import SwiftUI

// MARK: - CustomizationViewComponents
//
// Вспомогательные компоненты `CustomizationView`.
// Карточки нарядов, скинов и голоса — в `CustomizationViewCards.swift`.

// MARK: - CustomizationTabButton

struct CustomizationTabButton: View {

    let tab: CustomizationTab
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(spacing: SpacingTokens.sp1) {
                Image(systemName: tab.iconName)
                    .font(TypographyTokens.headline(18))
                Text(tab.localizedName)
                    .font(TypographyTokens.caption(11))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(
                isSelected ? ColorTokens.Brand.primary : ColorTokens.Kid.inkMuted
            )
            .frame(minWidth: 64, minHeight: 56)
            .padding(.horizontal, SpacingTokens.small)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                    .fill(
                        isSelected
                            ? ColorTokens.Brand.primary.opacity(0.12)
                            : Color.clear
                    )
            )
            .animation(reduceMotion ? nil : MotionTokens.outQuick, value: isSelected)
        }
        .accessibilityLabel(tab.localizedName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - BackgroundCard

struct BackgroundCard: View {

    let item: BackgroundItemViewModel
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool { horizontalSizeClass == .compact }
    private var cardWidth: CGFloat { isCompact ? 100 : 120 }
    private var cardHeight: CGFloat { isCompact ? 100 : 120 }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                if UIImage(named: item.illustrationName) != nil {
                    Image(item.illustrationName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cardWidth, height: cardHeight)
                        .clipped()
                } else {
                    item.background.previewGradient
                        .frame(width: cardWidth, height: cardHeight)
                }

                Text(item.localizedName)
                    .font(TypographyTokens.caption(10))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)
                    .padding(.vertical, SpacingTokens.sp1)
                    .padding(.horizontal, SpacingTokens.sp2)
                    .background(.ultraThinMaterial)
                    .frame(maxWidth: .infinity)
            }
            .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .strokeBorder(
                        isSelected ? ColorTokens.Brand.primary : Color.clear,
                        lineWidth: 3
                    )
            )
            .frame(width: cardWidth, height: cardHeight)
        }
        .accessibilityLabel("\(item.localizedName)\(isSelected ? ", выбран" : "")")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - AccessoryToggleButton

struct AccessoryToggleButton: View {

    let item: AccessoryItemViewModel
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isLocked: Bool {
        if case .locked = item.unlockStatus { return true }
        return false
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: SpacingTokens.sp1) {
                ZStack {
                    Circle()
                        .fill(item.isEnabled
                            ? ColorTokens.Brand.primary.opacity(0.15)
                            : ColorTokens.Kid.surface)
                        .frame(width: 52, height: 52)

                    Image(systemName: item.iconName)
                        .font(TypographyTokens.headline(22))
                        .foregroundStyle(
                            isLocked
                                ? ColorTokens.Kid.inkMuted
                                : (item.isEnabled ? ColorTokens.Brand.primary : ColorTokens.Kid.ink)
                        )

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(TypographyTokens.caption(10))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .offset(x: 16, y: 16)
                    }
                }

                Text(item.localizedName)
                    .font(TypographyTokens.caption(10))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)
            }
            .frame(minWidth: 56, minHeight: 72)
            .animation(reduceMotion ? nil : MotionTokens.outQuick, value: item.isEnabled)
        }
        .accessibilityLabel(item.localizedName)
        .accessibilityHint(
            isLocked
                ? String(localized: "customization.a11y.accessory_locked")
                : (item.isEnabled
                    ? String(localized: "customization.a11y.accessory_on")
                    : String(localized: "customization.a11y.accessory_off"))
        )
        .accessibilityAddTraits(item.isEnabled ? [.isSelected] : [])
    }
}

// MARK: - ColorCircle (hair / eye / skin tone)

struct ColorCircle: View {

    let color: Color
    let label: String
    let isSelected: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool { horizontalSizeClass == .compact }
    private var circleSize: CGFloat { isCompact ? 40 : 44 }
    private var touchTarget: CGFloat { isCompact ? 48 : 56 }

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: circleSize, height: circleSize)
                .overlay(
                    Circle().strokeBorder(ColorTokens.Overlay.highlight, lineWidth: 1)
                )

            if isSelected {
                Circle()
                    .strokeBorder(ColorTokens.Brand.primary, lineWidth: 3)
                    .frame(width: circleSize + 8, height: circleSize + 8)
                    .animation(reduceMotion ? nil : MotionTokens.outQuick, value: isSelected)
            }
        }
        .frame(width: touchTarget, height: touchTarget)
        .contentShape(Circle())
        .accessibilityLabel("\(label)\(isSelected ? ", выбран" : "")")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - ColorPaletteCircle

struct ColorPaletteCircle: View {

    let variant: LyalyaColorVariant
    let isSelected: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompactWidth: Bool { horizontalSizeClass == .compact }
    private var touchTarget: CGFloat { isCompactWidth ? 48 : 56 }
    private var circleSize: CGFloat { isCompactWidth ? 40 : 44 }

    var body: some View {
        ZStack {
            Circle()
                .fill(variant.previewGradient)
                .frame(width: circleSize, height: circleSize)

            if isSelected {
                Circle()
                    .strokeBorder(ColorTokens.Brand.primary, lineWidth: 3)
                    .frame(width: circleSize + 8, height: circleSize + 8)
                    .animation(reduceMotion ? nil : MotionTokens.outQuick, value: isSelected)
            }
        }
        .frame(width: touchTarget, height: touchTarget)
        .contentShape(Circle())
        .accessibilityLabel("\(variant.localizedName)\(isSelected ? ", выбрана" : "")")
        .accessibilityHint(String(localized: "customization.a11y.color_card_hint"))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
