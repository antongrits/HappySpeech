import SwiftUI

// MARK: - CustomizationViewCards
//
// Карточки нарядов, скинов, голоса и вспомогательные стили для `CustomizationView`.

// MARK: - OutfitCard

struct OutfitCard: View {

    let item: OutfitItemViewModel
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isPressed = false

    private var isCompact: Bool { horizontalSizeClass == .compact }
    private var cardWidth: CGFloat { isCompact ? 100 : 120 }
    private var cardHeight: CGFloat { isCompact ? 136 : 158 }

    var body: some View {
        Button(action: action) {
            VStack(spacing: SpacingTokens.tiny) {
                ZStack(alignment: .topTrailing) {
                    outfitIllustration
                        .frame(width: cardWidth * 0.7, height: cardHeight * 0.6)
                        .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous))

                    if case .locked = item.unlockStatus {
                        Image(systemName: "lock.fill")
                            .font(TypographyTokens.body(16))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .background(Circle().fill(ColorTokens.Kid.surface).padding(-4))
                            .padding(SpacingTokens.sp1)
                    } else if item.isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(TypographyTokens.headline(20))
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .background(Circle().fill(ColorTokens.Kid.surface).padding(-2))
                            .padding(SpacingTokens.sp1)
                    }
                }

                Text(item.localizedName)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)

                if item.starCost > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(TypographyTokens.caption(9))
                            .foregroundStyle(ColorTokens.Brand.gold)
                        Text("\(item.starCost)")
                            .font(TypographyTokens.caption(10))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                    }
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(item.isSelected
                        ? ColorTokens.Brand.primary.opacity(0.12)
                        : ColorTokens.Kid.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                            .strokeBorder(
                                item.isSelected ? ColorTokens.Brand.primary : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
            .opacity(item.unlockStatus.isAccessible ? 1.0 : 0.55)
            .scaleEffect(isPressed && !reduceMotion ? 0.95 : 1.0)
            .animation(reduceMotion ? nil : MotionTokens.outQuick, value: isPressed)
        }
        .buttonStyle(PressedButtonStyle(isPressed: $isPressed))
        .accessibilityLabel("\(item.localizedName)\(item.isSelected ? ", выбран" : "")")
        .accessibilityHint(
            item.unlockStatus.isAccessible
                ? String(localized: "customization.a11y.outfit_card_hint")
                : item.outfit.unlockHint
        )
        .accessibilityAddTraits(item.isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var outfitIllustration: some View {
        if UIImage(named: item.illustrationName) != nil {
            Image(item.illustrationName)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                outfitPlaceholderGradient
                Image(systemName: "tshirt")
                    .font(TypographyTokens.title(28))
                    .foregroundStyle(ColorTokens.Overlay.onAccent.opacity(0.85))
            }
        }
    }

    private var outfitPlaceholderGradient: some View {
        LinearGradient(
            colors: [placeholderFromColor, placeholderToColor],
            startPoint: .top, endPoint: .bottom
        )
    }

    private var placeholderFromColor: Color {
        switch item.outfit {
        case .everyday:  return ColorTokens.Theme.everydayFrom
        case .beach:     return ColorTokens.Theme.beachFrom
        case .winter:    return ColorTokens.Theme.winterFrom
        case .school:    return ColorTokens.Theme.schoolFrom
        case .birthday:  return ColorTokens.Theme.birthdayFrom
        case .space:     return ColorTokens.Theme.spaceFrom
        }
    }

    private var placeholderToColor: Color {
        switch item.outfit {
        case .everyday:  return ColorTokens.Theme.everydayTo
        case .beach:     return ColorTokens.Theme.beachTo
        case .winter:    return ColorTokens.Theme.winterTo
        case .school:    return ColorTokens.Theme.schoolTo
        case .birthday:  return ColorTokens.Theme.birthdayTo
        case .space:     return ColorTokens.Theme.spaceTo
        }
    }
}

// MARK: - SkinCard

struct SkinCard: View {

    let skin: LyalyaSkin
    let isSelected: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isPressed = false

    private var isCompactWidth: Bool { horizontalSizeClass == .compact }

    var body: some View {
        VStack(spacing: SpacingTokens.tiny) {
            ZStack(alignment: .topTrailing) {
                skinIllustration
                    .frame(width: skinWidth, height: skinHeight)
                    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous))

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(TypographyTokens.headline(22))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .background(Circle().fill(ColorTokens.Kid.surface).padding(-2))
                        .padding(SpacingTokens.sp1)
                }
            }

            Text(skin.localizedName)
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(isSelected
                    ? ColorTokens.Brand.primary.opacity(0.12)
                    : ColorTokens.Kid.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                        .strokeBorder(
                            isSelected ? ColorTokens.Brand.primary : Color.clear,
                            lineWidth: 2
                        )
                )
        )
        .scaleEffect(isPressed && !reduceMotion ? 0.95 : 1.0)
        .animation(reduceMotion ? nil : MotionTokens.outQuick, value: isPressed)
        .onLongPressGesture(
            minimumDuration: .infinity,
            maximumDistance: .infinity,
            pressing: { pressing in isPressed = pressing },
            perform: {}
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Скин: \(skin.localizedName)\(isSelected ? ", выбран" : "")")
        .accessibilityHint(String(localized: "customization.a11y.skin_card_hint"))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var skinIllustration: some View {
        if UIImage(named: skin.illustrationName) != nil {
            Image(skin.illustrationName)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                placeholderGradient
                Image(systemName: "figure.stand")
                    .font(.system(size: skinHeight * 0.5, weight: .light))
                    .foregroundStyle(ColorTokens.Overlay.onAccent.opacity(0.85))
            }
        }
    }

    private var placeholderGradient: some View {
        LinearGradient(
            colors: [placeholderFrom, placeholderTo],
            startPoint: .top, endPoint: .bottom
        )
    }

    private var placeholderFrom: Color {
        switch skin {
        case .classic:   return ColorTokens.Theme.everydayFrom
        case .princess:  return ColorTokens.Theme.princessFrom
        case .scientist: return ColorTokens.Theme.scientistFrom
        case .athlete:   return ColorTokens.Theme.athleteFrom
        case .artist:    return ColorTokens.Theme.artistFrom
        }
    }

    private var placeholderTo: Color {
        switch skin {
        case .classic:   return ColorTokens.Theme.everydayTo
        case .princess:  return ColorTokens.Theme.princessTo
        case .scientist: return ColorTokens.Theme.scientistTo
        case .athlete:   return ColorTokens.Theme.athleteTo
        case .artist:    return ColorTokens.Theme.artistTo
        }
    }

    private var cardWidth: CGFloat { isCompactWidth ? 100 : 120 }
    private var cardHeight: CGFloat { isCompactWidth ? 136 : 160 }
    private var skinWidth: CGFloat { isCompactWidth ? 66 : 80 }
    private var skinHeight: CGFloat { isCompactWidth ? 84 : 100 }
}

// MARK: - VoiceRow

struct VoiceRow: View {

    let voice: LyalyaVoice
    let isSelected: Bool
    let isPlaying: Bool
    var onPreviewTap: ((LyalyaVoice) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: SpacingTokens.small) {
            ZStack {
                Circle()
                    .strokeBorder(
                        isSelected ? ColorTokens.Brand.primary : ColorTokens.Kid.line,
                        lineWidth: 2
                    )
                    .frame(width: 24, height: 24)
                if isSelected {
                    Circle()
                        .fill(ColorTokens.Brand.primary)
                        .frame(width: 14, height: 14)
                }
            }
            .animation(reduceMotion ? nil : MotionTokens.outQuick, value: isSelected)

            Text(voice.localizedName)
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Kid.ink)

            Spacer()

            Button {
                onPreviewTap?(voice)
            } label: {
                Label(
                    String(localized: "customization.voice.preview"),
                    systemImage: isPlaying ? "stop.circle.fill" : "play.circle.fill"
                )
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Brand.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            }
            .frame(minWidth: 56, minHeight: 44)
            .accessibilityLabel(
                String(format: String(localized: "customization.a11y.voice_preview"), voice.localizedName)
            )
            .accessibilityHint(isPlaying ? "Нажмите чтобы остановить" : "Нажмите чтобы прослушать")
        }
        .frame(minHeight: 56)
        .padding(.horizontal, SpacingTokens.regular)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(isSelected ? ColorTokens.Brand.primary.opacity(0.08) : Color.clear)
                .animation(reduceMotion ? nil : MotionTokens.outQuick, value: isSelected)
        )
        .padding(.horizontal, SpacingTokens.small)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - PressedButtonStyle

struct PressedButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
    }
}
