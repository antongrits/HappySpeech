import SwiftUI

// MARK: - RoleSelectView

struct RoleSelectView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(AppContainer.self) private var container
    @State private var appeared = false
    @State private var isResolvingChild = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    /// Действие карточки роли: либо прямой маршрут (родитель/логопед), либо
    /// асинхронное разрешение активного ребёнка (детская роль — P0-1: больше не
    /// ведём в фантомный `preview-child-1`).
    private enum RoleAction {
        case route(AppRoute)
        case resolveChild
    }

    private struct RoleEntry: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let color: Color
        let action: RoleAction
    }

    // Порядок выровнен с эталоном: ведущая роль — ребёнок (первичный пользователь),
    // затем взрослые роли. Детский контур всюду тёплый (коралл) — карточка ребёнка
    // совпадает с ним, а не зелёная (mint). Взрослые роли (родитель/логопед)
    // остаются прохладными sky/lilac как осознанный «взрослый» акцент.
    private let roles: [RoleEntry] = [
        RoleEntry(
            title: String(localized: "Ребёнок"),
            subtitle: String(localized: "Игры и весёлые задания с Лялей"),
            icon: "face.smiling.fill",
            color: ColorTokens.Brand.primary,
            action: .resolveChild
        ),
        RoleEntry(
            title: String(localized: "Родитель"),
            subtitle: String(localized: "Настройка профиля и наблюдение за прогрессом"),
            icon: "person.2.fill",
            color: ColorTokens.Brand.lilac,
            action: .route(.parentHome)
        ),
        RoleEntry(
            title: String(localized: "Логопед"),
            subtitle: String(localized: "Специальные инструменты анализа и экспорта"),
            icon: "stethoscope",
            color: ColorTokens.Brand.sky,
            action: .route(.specialistHome)
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
                    // Текст выровнен с дизайн-эталоном (references/auth.html).
                    Text(String(localized: "auth.role.select.title"))
                        .font(TypographyTokens.kidDisplay(30))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.80)

                    Text(String(localized: "auth.role.select.subtitle"))
                        .font(TypographyTokens.body())
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, SpacingTokens.pageTop)
                .padding(.horizontal, SpacingTokens.screenEdge)

                // Равные гибкие отступы сверху и снизу центрируют блок карточек
                // в свободном пространстве под шапкой — без «дыры» внизу на
                // высоких устройствах (17 Pro Max) и без обрезки на SE.
                Spacer(minLength: SpacingTokens.sectionGap)

                // Role cards
                VStack(spacing: SpacingTokens.listGap) {
                    ForEach(Array(roles.enumerated()), id: \.offset) { index, role in
                        RoleCard(
                            title: role.title,
                            subtitle: role.subtitle,
                            icon: role.icon,
                            accentColor: role.color
                        ) {
                            handle(role.action)
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

                Spacer(minLength: SpacingTokens.sectionGap)
            }
        }
        .onAppear { appeared = true }
    }

    // MARK: - Role action handling

    private func handle(_ action: RoleAction) {
        switch action {
        case .route(let route):
            coordinator.navigate(to: route)
        case .resolveChild:
            resolveActiveChildAndRoute()
        }
    }

    /// P0-1: разрешает РЕАЛЬНЫЙ id активного ребёнка перед входом в детский контур.
    /// Раньше карточка «Ребёнок» вела в захардкоженный `preview-child-1`, которого
    /// в live-Realm нет → пустая главная + сессии-сироты. Теперь:
    ///   1) берём сохранённый `ActiveChildStore.id`, если такой профиль реально есть;
    ///   2) иначе — первый профиль ребёнка из репозитория;
    ///   3) если детей нет — ведём родителя в его контур создавать профиль,
    ///      а не в фантомную детскую главную.
    private func resolveActiveChildAndRoute() {
        guard !isResolvingChild else { return }
        isResolvingChild = true
        let repository = container.childRepository
        Task { @MainActor in
            defer { isResolvingChild = false }
            let profiles = (try? await repository.fetchAll()) ?? []

            if let storedId = ActiveChildStore.shared.id,
               profiles.contains(where: { $0.id == storedId }) {
                coordinator.navigate(to: .childHome(childId: storedId))
                return
            }

            if let first = profiles.first {
                ActiveChildStore.shared.set(first.id)
                coordinator.navigate(to: .childHome(childId: first.id))
                return
            }

            // Детей ещё нет — отправляем создавать профиль в родительском контуре.
            coordinator.navigate(to: .parentHome)
        }
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
        .environment(AppContainer.preview())
}
