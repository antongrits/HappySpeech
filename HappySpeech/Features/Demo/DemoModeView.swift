import SwiftUI

// MARK: - DemoModeView

struct DemoModeView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var currentStep = 0
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let demoSteps: [DemoStep] = [
        DemoStep(
            title: "Персональный маршрут",
            description: "Каждый день — новый план занятий, подобранный под прогресс ребёнка. ИИ учитывает усталость и успехи.",
            icon: "map.fill",
            color: ColorTokens.Brand.sky,
            animationType: .bounce
        ),
        DemoStep(
            title: "16 видов упражнений",
            description: "От простых игр с картинками до AR-зеркала, где ребёнок видит своё лицо и повторяет артикуляцию.",
            icon: "gamecontroller.fill",
            color: ColorTokens.Brand.primary,
            animationType: .spring
        ),
        DemoStep(
            title: "Аналитика для родителей",
            description: "Чёткие цифры: сколько правильных ответов, какие слова даются трудно, что повторить дома.",
            icon: "chart.xyaxis.line",
            color: ColorTokens.Parent.accent,
            animationType: .page
        ),
        DemoStep(
            title: "Инструменты логопеда",
            description: "Специалист видит спектрограммы, слышит записи, ставит оценки и экспортирует отчёты.",
            icon: "stethoscope",
            color: ColorTokens.Brand.lilac,
            animationType: .bounce
        ),
    ]

    var body: some View {
        ZStack {
            demoBackground

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button {
                        coordinator.navigate(to: .auth)
                    } label: {
                        Text(String(localized: "Пропустить"))
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .accessibilityLabel(String(localized: "Пропустить демо"))
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)

                Spacer()

                // Demo steps carousel
                TabView(selection: $currentStep) {
                    ForEach(Array(demoSteps.enumerated()), id: \.offset) { index, step in
                        DemoStepCard(step: step)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 400)

                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<demoSteps.count, id: \.self) { i in
                        Capsule()
                            .fill(.white.opacity(i == currentStep ? 1.0 : 0.35))
                            .frame(width: i == currentStep ? 20 : 6, height: 6)
                            .animation(reduceMotion ? nil : MotionTokens.spring, value: currentStep)
                    }
                }
                .padding(.top, SpacingTokens.sp4)

                Spacer()

                // CTA
                VStack(spacing: SpacingTokens.sp3) {
                    if currentStep < demoSteps.count - 1 {
                        HSButton(String(localized: "Далее"), style: .primary, icon: "arrow.right") {
                            withAnimation(reduceMotion ? nil : MotionTokens.page) {
                                currentStep += 1
                            }
                        }
                    } else {
                        HSButton(String(localized: "Создать аккаунт"), style: .primary, icon: "person.badge.plus") {
                            coordinator.navigate(to: .auth)
                        }
                    }
                    Button {
                        coordinator.navigate(to: .childHome(childId: "demo-child"))
                    } label: {
                        Text(String(localized: "Попробовать без аккаунта"))
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.sp16)
            }
        }
    }

    private var demoBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    demoSteps[currentStep].color.opacity(0.9),
                    demoSteps[currentStep].color.adjustingBrightness(by: -0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: currentStep)
            .ignoresSafeArea()

            // Decorative circles
            Circle().fill(.white.opacity(0.06)).frame(width: 300).offset(x: -80, y: -200)
            Circle().fill(.white.opacity(0.04)).frame(width: 200).offset(x: 130, y: 50)
        }
    }
}

// MARK: - DemoStep

private struct DemoStep {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let animationType: AnimationType

    enum AnimationType { case bounce, spring, page }
}

private struct DemoStepCard: View {
    let step: DemoStep
    @State private var iconScale: CGFloat = 0.5
    @State private var contentOpacity: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: SpacingTokens.sp6) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 140, height: 140)
                Image(systemName: step.icon)
                    .font(.system(size: 60, weight: .thin))
                    .foregroundStyle(.white)
                    .scaleEffect(iconScale)
            }

            // Text content
            VStack(spacing: SpacingTokens.sp3) {
                Text(step.title)
                    .font(TypographyTokens.title(26))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(step.description)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpacingTokens.sp6)
                    .lineSpacing(4)
            }
            .opacity(contentOpacity)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .onAppear {
            if reduceMotion {
                iconScale = 1.0
                contentOpacity = 1.0
                return
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) {
                iconScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.25)) {
                contentOpacity = 1.0
            }
        }
        .onDisappear {
            iconScale = 0.5
            contentOpacity = 0
        }
    }
}

// MARK: - Preview

#Preview("Demo Mode") {
    DemoModeView()
        .environment(AppCoordinator())
}
