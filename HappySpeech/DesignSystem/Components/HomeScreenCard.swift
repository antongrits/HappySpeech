import SwiftUI

// MARK: - HomeScreenCard
//
// Компонент, имитирующий внешний вид Home Screen Widget (small, 158×158pt).
// Используется внутри приложения на экранах ChildHome и ParentHome как «live tile»
// до внедрения полноценного WidgetKit Extension (post-v1.0, см. ADR).
//
// Параметры:
//   • dailyMission  — краткое описание задания дня (1–2 строки)
//   • streakDays    — текущий стрик (отображается как «N дней подряд»)
//   • lyalyaIcon    — SF Symbol имя для иконки маскота
//   • isCompact     — если true, размер уменьшается до 120×120pt (для карусели)
//
// Поддерживает: Dynamic Type, Dark Mode, Reduced Motion, VoiceOver.

public struct HomeScreenCard: View {

    // MARK: - Input

    let dailyMission: String
    let streakDays: Int
    let lyalyaIcon: String
    var isCompact: Bool = false

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Private

    private var cardSize: CGFloat { isCompact ? 120 : 158 }

    private var gradientColors: [Color] {
        colorScheme == .dark
            ? [ColorTokens.Brand.primary.opacity(0.35), ColorTokens.Brand.lilac.opacity(0.25)]
            : [ColorTokens.Brand.primary.opacity(0.18), ColorTokens.Brand.lilac.opacity(0.14)]
    }

    // MARK: - Body

    public var body: some View {
        ZStack(alignment: .topLeading) {
            // Background gradient
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                        .strokeBorder(
                            ColorTokens.Brand.primary.opacity(0.25),
                            lineWidth: 1
                        )
                )

            // Content
            VStack(alignment: .leading, spacing: 0) {
                // Top row: icon + streak badge
                HStack(alignment: .top) {
                    Image(systemName: lyalyaIcon)
                        .font(.system(size: isCompact ? 18 : 22, weight: .semibold))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .accessibilityHidden(true)

                    Spacer(minLength: SpacingTokens.micro)

                    if streakDays > 0 {
                        streakBadge
                    }
                }

                Spacer(minLength: SpacingTokens.tiny)

                // Widget title
                Text(String(localized: "widget.title"))
                    .font(TypographyTokens.caption(isCompact ? 9 : 10).weight(.semibold))
                    .foregroundStyle(ColorTokens.Brand.primary.opacity(0.7))
                    .textCase(.uppercase)
                    .lineLimit(1)

                Spacer(minLength: SpacingTokens.micro)

                // Mission text
                Text(dailyMission)
                    .font(TypographyTokens.headline(isCompact ? 12 : 13))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .lineSpacing(1.5)
            }
            .padding(isCompact ? SpacingTokens.tiny : SpacingTokens.regular)
        }
        .frame(width: cardSize, height: cardSize)
        .shadow(
            color: ColorTokens.Brand.primary.opacity(colorScheme == .dark ? 0.15 : 0.12),
            radius: isCompact ? 6 : 10,
            y: isCompact ? 3 : 5
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(
                format: String(localized: "widget.a11y"),
                dailyMission,
                streakDays
            )
        )
        .accessibilityAddTraits(.isStaticText)
    }

    // MARK: - Streak badge

    private var streakBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "flame.fill")
                .font(.system(size: isCompact ? 9 : 10, weight: .bold))
                .foregroundStyle(ColorTokens.Brand.butter)
                .accessibilityHidden(true)
            Text(String(format: String(localized: "widget.streak.format"), streakDays))
                .font(TypographyTokens.caption(isCompact ? 9 : 10).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, SpacingTokens.tiny)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(ColorTokens.Brand.butter.opacity(0.25))
        )
    }
}

// MARK: - Preview

#Preview("HomeScreenCard — normal") {
    HStack(spacing: 16) {
        HomeScreenCard(
            dailyMission: "Повтори звук «С» в словах: санки, сок, сыр",
            streakDays: 5,
            lyalyaIcon: "bird.fill"
        )
        HomeScreenCard(
            dailyMission: "Игра «Повтори за мной»",
            streakDays: 0,
            lyalyaIcon: "bird.fill",
            isCompact: true
        )
    }
    .padding()
    .background(ColorTokens.Kid.bgSoft)
}

#Preview("HomeScreenCard — dark") {
    HomeScreenCard(
        dailyMission: "Скажи «Ш-Ш-Ш» как змейка",
        streakDays: 12,
        lyalyaIcon: "bird.fill"
    )
    .padding()
    .background(Color.black)
    .environment(\.colorScheme, .dark)
}
