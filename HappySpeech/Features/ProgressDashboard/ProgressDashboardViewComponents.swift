import Charts
import SwiftUI

// MARK: - ProgressDashboardViewComponents
//
// Подкомпоненты `ProgressDashboardView`.
// Детальный вид звука вынесен в `ProgressDashboardViewDetail.swift`.

// MARK: - SoundDetailRoute

struct SoundDetailRoute: Hashable {
    let detail: SoundDetailViewModel
}

// MARK: - SummaryCardView

struct SummaryCardView: View {

    let card: SummaryCardViewModel

    var body: some View {
        HSLiquidGlassCard(style: .tinted(accentColor), padding: SpacingTokens.cardPad) {
            VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                Text(card.title)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(card.value)
                    .font(TypographyTokens.display(34))
                    .foregroundStyle(accentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityHidden(true)

                if let progress = card.progress {
                    HSProgressBar(value: progress, style: .parent, tint: accentColor)
                        .frame(height: 4)
                        .padding(.top, SpacingTokens.micro)
                } else if let caption = card.caption {
                    Text(caption)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 160, height: 120)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(card.accessibilityLabel)
    }

    private var accentColor: Color {
        switch card.valueAccent {
        case .accent: return ColorTokens.Parent.accent
        case .butter: return ColorTokens.Brand.butter
        case .mint:   return ColorTokens.Brand.mint
        case .lilac:  return ColorTokens.Brand.lilac
        }
    }
}

// MARK: - SoundProgressCellView

struct SoundProgressCellView: View {

    let cell: SoundProgressCellViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HSLiquidGlassCard(style: .tinted(Color(cell.familyHueName)), padding: SpacingTokens.regular) {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                HStack(alignment: .top) {
                    Text(cell.sound)
                        .font(TypographyTokens.display(28))
                        .foregroundStyle(Color(cell.familyHueName))
                        .accessibilityHidden(true)

                    Spacer()

                    Image(systemName: cell.trendIconName)
                        .font(TypographyTokens.labelRounded(14))
                        .foregroundStyle(trendColor)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle().fill(trendColor.opacity(0.15))
                        )
                        .accessibilityHidden(true)
                }

                Text(cell.accuracyText)
                    .font(TypographyTokens.headline(20))
                    .foregroundStyle(ColorTokens.Parent.ink)

                HSProgressBar(
                    value: cell.accuracyValue / 100,
                    style: .parent,
                    tint: Color(cell.familyHueName)
                )
                .frame(height: 4)

                Text(cell.sessionsCaption)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cell.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var trendColor: Color {
        switch cell.trend {
        case .up:     return ColorTokens.Semantic.success
        case .down:   return ColorTokens.Semantic.error
        case .stable: return ColorTokens.Parent.inkMuted
        }
    }
}

// MARK: - PeriodChipView

struct PeriodChipView: View {

    let option: PeriodOptionViewModel
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            Text(option.title)
                .font(TypographyTokens.headline(14))
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SpacingTokens.small)
                .background(background)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: option.isSelected)
        .accessibilityLabel(option.accessibilityLabel)
        .accessibilityAddTraits(option.isSelected ? [.isButton, .isSelected] : [.isButton])
    }

    @ViewBuilder
    private var background: some View {
        if option.isSelected {
            RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                .fill(ColorTokens.Parent.accent)
        } else {
            RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                .fill(Color.clear)
        }
    }

    private var textColor: Color {
        option.isSelected ? .white : ColorTokens.Parent.ink
    }
}

// MARK: - FlowChipsRow

struct FlowChipsRow: View {

    let chips: [SoundChipViewModel]

    var body: some View {
        // Простая горизонтальная прокрутка — на iPhone хватает на 3-5 чипов.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.tiny) {
                ForEach(chips) { chip in
                    SoundChipView(chip: chip)
                }
            }
        }
    }
}

// MARK: - SoundChipView

struct SoundChipView: View {

    let chip: SoundChipViewModel

    var body: some View {
        HStack(spacing: SpacingTokens.micro) {
            Text(chip.sound)
                .font(TypographyTokens.headline(14))
                .foregroundStyle(textColor)
            Text(chip.percentText)
                .font(TypographyTokens.mono(11))
                .foregroundStyle(textColor.opacity(0.85))
        }
        .padding(.horizontal, SpacingTokens.small)
        .padding(.vertical, SpacingTokens.micro)
        .background(
            Capsule(style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(chip.accessibilityLabel)
    }

    private var textColor: Color {
        switch chip.tone {
        case .positive:  return ColorTokens.Semantic.success
        case .attention: return ColorTokens.Semantic.warning
        }
    }

    private var backgroundColor: Color {
        switch chip.tone {
        case .positive:  return ColorTokens.Semantic.successBg
        case .attention: return ColorTokens.Semantic.warningBg
        }
    }

    private var borderColor: Color {
        textColor.opacity(0.25)
    }
}

// MARK: - RecommendationRowView

struct RecommendationRowView: View {

    let item: RecommendationViewModel

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.regular) {
            Image(systemName: item.iconName)
                .font(TypographyTokens.subtitle(18))
                .foregroundStyle(ColorTokens.Parent.accent)
                .accessibilityHidden(true)

            Text(item.text)
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Parent.ink)
                .lineSpacing(TypographyTokens.LineSpacing.normal)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.accessibilityLabel)
    }
}

// MARK: - ParentInsightCard

struct ParentInsightCard: View {

    let card: ParentInsightCardViewModel

    var body: some View {
        HSLiquidGlassCard(style: .tinted(toneColor), padding: SpacingTokens.cardPad) {
            HStack(alignment: .top, spacing: SpacingTokens.sp4) {
                Image(systemName: card.icon)
                    .font(.title2)
                    .foregroundStyle(toneColor)
                    .accessibilityHidden(true)

                Text(card.text)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineSpacing(TypographyTokens.LineSpacing.normal)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(card.accessibilityLabel)
    }

    private var toneColor: Color {
        switch card.toneRawValue {
        case "positive": return ColorTokens.Semantic.success
        case "warning":  return ColorTokens.Semantic.warning
        default:         return ColorTokens.Brand.primary
        }
    }
}
