import SwiftUI

// MARK: - RoleSelectView

struct RoleSelectView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private struct RoleEntry: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let color: Color
        let route: AppRoute
    }

    private let roles: [RoleEntry] = [
        RoleEntry(
            title: String(localized: "Родитель"),
            subtitle: String(localized: "Настройка профиля и наблюдение за прогрессом"),
            icon: "person.2.fill",
            color: ColorTokens.Brand.sky,
            route: .parentHome
        ),
        RoleEntry(
            title: String(localized: "Логопед"),
            subtitle: String(localized: "Специальные инструменты анализа и экспорта"),
            icon: "stethoscope",
            color: ColorTokens.Brand.lilac,
            route: .specialistHome
        ),
        RoleEntry(
            title: String(localized: "Ребёнок"),
            subtitle: String(localized: "Продолжить занятия"),
            icon: "star.fill",
            // Детский контур всюду тёплый (коралл/butter) — карточка ребёнка должна
            // совпадать с ним, а не быть зелёной (mint). Взрослые роли (родитель/логопед)
            // остаются прохладными sky/lilac как осознанный «взрослый» акцент.
            color: ColorTokens.Brand.primary,
            route: .childHome(childId: "preview-child-1")
        )
    ]

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: SpacingTokens.sp3) {
                    // F.tier1 v21: hero mascot мягче в dark.
                    // E v21: 3D Ляля в hero RoleSelectView (требование пользователя).
                    LyalyaHeroView(state: .waving, size: 140)
                        .opacity(colorScheme == .dark ? 0.92 : 1.0)
                        .padding(.bottom, SpacingTokens.sp2)

                    // P3 v32: hero text → kidDisplay для большей выразительности.
                    Text(String(localized: "Кто вы?"))
                        .font(TypographyTokens.kidDisplay(32))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.80)

                    Text(String(localized: "Выберите профиль для начала"))
                        .font(TypographyTokens.body())
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            // P0.1 v32: каждая RoleCard получает gradientTinted background
            // (accentColor.opacity(0.15) → surface). Иконка — HSIconCircle 72pt.
            HSCard(
                style: .gradientTinted(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(0.15),
                            accentColor.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                ),
                padding: SpacingTokens.sp5
            ) {
                HStack(spacing: SpacingTokens.sp5) {
                    // P4 v32: тёплый кружок-иконка 72pt с concentric radius.
                    HSIconCircle(
                        systemName: icon,
                        size: 72,
                        color: accentColor,
                        iconScale: 0.44,
                        fillOpacity: 0.18
                    )

                    // Text
                    VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                        Text(title)
                            .font(TypographyTokens.kidCardTitle(18))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)

                        Text(subtitle)
                            .font(TypographyTokens.body(13))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(TypographyTokens.caption(14))
                        .fontWeight(.semibold)
                        .foregroundStyle(accentColor.opacity(0.60))
                }
            }
        }
        .buttonStyle(.plain)
        // P0.1 v32: MotionTokens.playful spring на tap + scaleEffect press-feedback.
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(reduceMotion ? nil : MotionTokens.pressSpring, value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
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
