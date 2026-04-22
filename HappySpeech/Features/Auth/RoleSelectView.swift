import SwiftUI

// MARK: - RoleSelectView

struct RoleSelectView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let roles: [(title: String, subtitle: String, icon: String, color: Color, route: AppRoute)] = [
        (
            title: String(localized: "Родитель"),
            subtitle: String(localized: "Настройка профиля и наблюдение за прогрессом"),
            icon: "person.2.fill",
            color: ColorTokens.Brand.sky,
            route: .parentHome
        ),
        (
            title: String(localized: "Логопед"),
            subtitle: String(localized: "Специальные инструменты анализа и экспорта"),
            icon: "stethoscope",
            color: ColorTokens.Brand.lilac,
            route: .specialistHome
        ),
        (
            title: String(localized: "Ребёнок"),
            subtitle: String(localized: "Продолжить занятия"),
            icon: "star.fill",
            color: ColorTokens.Brand.mint,
            route: .childHome(childId: "preview-child-1")
        ),
    ]

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: SpacingTokens.sp3) {
                    Text(String(localized: "Кто вы?"))
                        .font(TypographyTokens.display(28))
                        .foregroundStyle(ColorTokens.Kid.ink)

                    Text(String(localized: "Выберите профиль для начала"))
                        .font(TypographyTokens.body())
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }
                .padding(.top, SpacingTokens.pageTop)
                .padding(.horizontal, SpacingTokens.screenEdge)

                Spacer(minLength: SpacingTokens.sp8)

                // Role cards
                VStack(spacing: SpacingTokens.listGap) {
                    ForEach(Array(roles.enumerated()), id: \.offset) { index, role in
                        RoleCard(
                            title: role.title,
                            subtitle: role.subtitle,
                            icon: role.icon,
                            accentColor: role.color
                        ) {
                            coordinator.navigate(to: role.route)
                        }
                        .offset(y: appeared ? 0 : 40)
                        .opacity(appeared ? 1 : 0)
                        .animation(
                            reduceMotion ? nil : MotionTokens.spring.delay(Double(index) * 0.08),
                            value: appeared
                        )
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)

                Spacer()
            }
        }
        .onAppear { appeared = true }
    }
}

// MARK: - RoleCard

private struct RoleCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.sp5) {
                // Icon container
                ZStack {
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundStyle(accentColor)
                }

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Kid.ink)

                    Text(subtitle)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(2)
                        .ctaTextStyle()
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
            }
            .padding(SpacingTokens.sp5)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .kidCardShadow()
            )
        }
        .buttonStyle(.plain)
        .tapFeedback()
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Preview

#Preview("Role Select") {
    RoleSelectView()
        .environment(AppCoordinator())
}
