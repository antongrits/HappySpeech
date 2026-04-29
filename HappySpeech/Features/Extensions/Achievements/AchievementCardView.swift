import SwiftUI

// MARK: - AchievementCardView

struct AchievementCardView: View {

    let item: AchievementCellViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: SpacingTokens.sp3) {
            iconView
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                Text(item.title)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(item.isUnlocked ? ColorTokens.Kid.ink : ColorTokens.Kid.inkMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                if item.isUnlocked, !item.description.isEmpty {
                    Text(item.description)
                        .font(TypographyTokens.caption(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }

                if let dateText = item.unlockedDateFormatted {
                    Text(dateText)
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(rarityColor.opacity(0.8))
                }
            }

            Spacer(minLength: 0)

            if item.isUnlocked {
                rarityBadge
            } else {
                Image(systemName: "lock.fill")
                    .font(TypographyTokens.caption(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted.opacity(0.5))
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, SpacingTokens.sp4)
        .padding(.vertical, SpacingTokens.sp3)
        .background(cardBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Sub-views

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(item.isUnlocked ? rarityColor.opacity(0.15) : ColorTokens.Kid.inkMuted.opacity(0.08))

            Image(systemName: item.iconName)
                .font(TypographyTokens.headline(22))
                .foregroundStyle(item.isUnlocked ? rarityColor : ColorTokens.Kid.inkMuted.opacity(0.4))
                .scaleEffect(item.isUnlocked ? 1.0 : 0.8)
                .animation(
                    reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.7),
                    value: item.isUnlocked
                )
        }
        .accessibilityHidden(true)
    }

    private var rarityBadge: some View {
        Text(item.rarity.localizedTitle)
            .font(TypographyTokens.caption(10))
            .foregroundStyle(.white)
            .padding(.horizontal, SpacingTokens.sp2)
            .padding(.vertical, 3)
            .background(Capsule().fill(rarityColor))
            .accessibilityHidden(true)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: RadiusTokens.card)
            .fill(item.isUnlocked
                ? rarityColor.opacity(0.07)
                : Color(.systemFill).opacity(0.4))
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .strokeBorder(
                        item.isUnlocked ? rarityColor.opacity(0.25) : Color.clear,
                        lineWidth: 1
                    )
            )
    }

    // MARK: - Helpers

    private var rarityColor: Color {
        switch item.rarity {
        case .legendary: return ColorTokens.Brand.butter
        case .rare:      return ColorTokens.Brand.lilac
        case .common:    return ColorTokens.Brand.mint
        }
    }

    private var accessibilityLabel: String {
        if item.isUnlocked {
            let date = item.unlockedDateFormatted ?? ""
            return "\(item.title). \(item.description). \(date)"
        } else {
            return String(localized: "achievements.locked.title")
        }
    }
}

// MARK: - Preview

#Preview("Achievement Card — Unlocked") {
    VStack(spacing: 8) {
        AchievementCardView(item: AchievementCellViewModel(
            id: "streak7Days",
            title: "Неделя!",
            description: "7 дней подряд",
            iconName: "flame.fill",
            rarity: .rare,
            isUnlocked: true,
            unlockedAt: Date(),
            unlockedDateFormatted: "Получено 1 янв. 2026"
        ))
        AchievementCardView(item: AchievementCellViewModel(
            id: "streak100Days",
            title: "???",
            description: "",
            iconName: "crown.fill",
            rarity: .legendary,
            isUnlocked: false,
            unlockedAt: nil,
            unlockedDateFormatted: nil
        ))
    }
    .padding()
}
