import OSLog
import SwiftUI

// MARK: - OnboardingFlowView
//
// 10-шаговый онбординг (welcome → role → childName → childAge → goals →
// sounds → schedule → permissions → modelDownload → completion).
//
// Сигнатура `init(onComplete:)` опциональна: если onComplete не передан,
// View использует router → AppCoordinator (по выбранной роли).

struct OnboardingFlowView: View {

    // MARK: - Inputs

    let onComplete: ((OnboardingProfile) -> Void)?

    // MARK: - Environment

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    // MARK: - VIP State

    @State private var display = OnboardingDisplay()
    @State private var interactor: OnboardingInteractor?
    @State private var presenter: OnboardingPresenter?
    @State private var router: OnboardingRouter?
    @State private var bootstrapped = false

    private let logger = Logger(subsystem: "ru.happyspeech", category: "OnboardingFlowView")

    // MARK: - Init

    init(onComplete: ((OnboardingProfile) -> Void)? = nil) {
        self.onComplete = onComplete
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    progressHeader

                    stepContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Mascot bubble: показываем на шагах, где есть фраза Ляли.
                    // Welcome и Completion — пропускаем (там своя большая Ляля).
                    if !display.mascotText.isEmpty
                        && display.currentStep != .welcome
                        && display.currentStep != .completion {
                        OnboardingMascotBubble(text: display.mascotText)
                            .padding(.bottom, SpacingTokens.small)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .animation(reduceMotion ? nil : MotionTokens.spring, value: display.currentStep)
                    }

                    actionFooter
                        .background(
                            GradientTokens.kidBottomFade(
                                background: gradientColors(for: display.currentStep).last ?? ColorTokens.Kid.bg
                            )
                            .ignoresSafeArea(edges: .bottom)
                        )
                        .padding(.bottom, geometry.safeAreaInsets.bottom)
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .accessibilityIdentifier("OnboardingRoot")
        .environment(\.circuitContext, .kid)
        .task { await bootstrap() }
        .onChange(of: display.pendingCompleted) { _, value in
            guard value else { return }
            display.consumeCompleted()
            handleCompletion()
        }
    }

    // MARK: - Background gradient (меняется по шагу)

    private var backgroundGradient: some View {
        LinearGradient(
            colors: gradientColors(for: display.currentStep),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: display.currentStep)
    }

    private func gradientColors(for step: OnboardingStep) -> [Color] {
        switch step {
        case .welcome:
            return [ColorTokens.Brand.butter.opacity(0.25), ColorTokens.Kid.bg]
        case .role:
            return [ColorTokens.Brand.lilac.opacity(0.20), ColorTokens.Kid.bg]
        case .childName:
            return [ColorTokens.Brand.rose.opacity(0.20), ColorTokens.Kid.bg]
        case .childAge:
            return [ColorTokens.Brand.sky.opacity(0.20), ColorTokens.Kid.bg]
        case .goals:
            return [ColorTokens.Brand.mint.opacity(0.20), ColorTokens.Kid.bg]
        case .sounds:
            return [ColorTokens.Brand.primary.opacity(0.18), ColorTokens.Kid.bg]
        case .schedule:
            return [ColorTokens.Brand.sky.opacity(0.20), ColorTokens.Brand.mint.opacity(0.10)]
        case .permissions:
            return [ColorTokens.Brand.lilac.opacity(0.18), ColorTokens.Kid.bg]
        case .modelDownload:
            return [ColorTokens.Brand.sky.opacity(0.22), ColorTokens.Kid.bg]
        case .completion:
            return [ColorTokens.Brand.butter.opacity(0.30), ColorTokens.Brand.primary.opacity(0.18)]
        }
    }

    // MARK: - Header

    private var progressHeader: some View {
        VStack(spacing: SpacingTokens.tiny) {
            HStack {
                if display.currentStep != .welcome {
                    Button {
                        interactor?.goBack(.init())
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(TypographyTokens.headline(17))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(String(localized: "onboarding.a11y.back"))
                }
                Spacer()
                Text(display.progressLabel)
                    .font(TypographyTokens.mono(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.tiny)

            HSProgressBar(value: display.progress, style: .kid)
                .padding(.horizontal, SpacingTokens.screenEdge)
                .accessibilityLabel(display.progressLabel)
        }
        .padding(.bottom, SpacingTokens.small)
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        Group {
            switch display.currentStep {
            case .welcome:
                OnboardingWelcomeStep()
            case .role:
                OnboardingRoleStep(
                    selectedRole: display.profile.role,
                    onSelect: { role in
                        interactor?.setRole(.init(role: role))
                    }
                )
            case .childName:
                OnboardingNameStep(
                    profile: display.profile,
                    onChange: { name, avatar in
                        interactor?.setProfile(.init(name: name, avatar: avatar))
                    }
                )
            case .childAge:
                OnboardingAgeStep(
                    age: display.profile.childAge,
                    onChange: { age in
                        interactor?.setAge(.init(age: age))
                    }
                )
            case .goals:
                OnboardingGoalsStep(
                    selectedGoals: display.profile.goals,
                    onToggle: { id in
                        interactor?.toggleGoal(.init(goalId: id))
                    }
                )
            case .sounds:
                OnboardingSoundsStep(
                    selectedSounds: display.profile.difficultSounds,
                    onToggle: { id in
                        interactor?.toggleSound(.init(soundId: id))
                    }
                )
            case .schedule:
                OnboardingScheduleStep(
                    selectedMinutes: display.profile.dailyMinutes,
                    onSelect: { minutes in
                        interactor?.setSchedule(.init(minutes: minutes))
                    }
                )
            case .permissions:
                OnboardingPermissionsStep()
            case .modelDownload:
                OnboardingModelDownloadStep(
                    status: display.modelStatus,
                    statusLabel: display.modelStatusLabel,
                    onStart: { interactor?.startModelDownload(.init()) }
                )
            case .completion:
                OnboardingCompletionStep(profile: display.profile)
            }
        }
        .id(display.currentStep)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .animation(reduceMotion ? nil : MotionTokens.page, value: display.currentStep)
    }

    // MARK: - Footer

    @ViewBuilder
    private var actionFooter: some View {
        VStack(spacing: SpacingTokens.tiny) {
            HSButton(
                primaryButtonTitle,
                style: .primary,
                icon: primaryButtonIcon
            ) {
                if display.currentStep == .completion {
                    interactor?.completeOnboarding(.init())
                } else {
                    interactor?.advanceStep(.init(from: display.currentStep))
                }
            }
            .disabled(!display.canAdvance)
            .opacity(display.canAdvance ? 1.0 : 0.5)

            if display.currentStep.isSkippable {
                Button {
                    if display.currentStep == .permissions {
                        interactor?.skipPermissions(.init())
                    } else {
                        interactor?.advanceStep(.init(from: display.currentStep))
                    }
                } label: {
                    Text(String(localized: "onboarding.cta.skip"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }
                .accessibilityLabel(String(localized: "onboarding.cta.skip"))
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.small)
        .padding(.bottom, SpacingTokens.small)
    }

    private var primaryButtonTitle: String {
        switch display.currentStep {
        case .welcome:
            return String(localized: "onboarding.cta.start")
        case .role, .childName, .childAge, .goals, .sounds, .schedule, .permissions:
            return String(localized: "onboarding.cta.next")
        case .modelDownload:
            switch display.modelStatus {
            case .downloading: return String(localized: "onboarding.cta.downloading")
            case .completed, .skipped: return String(localized: "onboarding.cta.next")
            default: return String(localized: "onboarding.cta.startDownload")
            }
        case .completion:
            return String(localized: "onboarding.cta.enter")
        }
    }

    private var primaryButtonIcon: String {
        switch display.currentStep {
        case .completion: return "sparkles"
        case .modelDownload:
            return display.modelStatus == .completed ? "arrow.right" : "arrow.down.circle"
        default: return "arrow.right"
        }
    }

    // MARK: - Bootstrap

    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        let presenter = OnboardingPresenter()
        presenter.display = display
        let interactor = OnboardingInteractor()
        interactor.presenter = presenter
        let router = OnboardingRouter()
        router.coordinator = coordinator
        router.onCompleted = onComplete

        self.presenter = presenter
        self.interactor = interactor
        self.router = router

        interactor.loadOnboarding(.init())
        logger.info("Onboarding bootstrapped (10-step deep flow)")
    }

    private func handleCompletion() {
        router?.routeCompleted(profile: display.profile)
    }
}

// MARK: - Preview

#Preview("Onboarding 10-step") {
    OnboardingFlowView(onComplete: { _ in })
        .environment(AppCoordinator())
}

#Preview("Onboarding About Step") {
    OnboardingAboutStep()
        .background(ColorTokens.Kid.bg)
}

#Preview("Onboarding Screening Intro") {
    OnboardingScreeningIntroStep(
        onStartScreening: {},
        onSkipScreening: {}
    )
    .background(ColorTokens.Kid.bg)
}

#Preview("Onboarding Mascot Bubble") {
    OnboardingMascotBubble(text: "Привет! Я Ляля. Помогу тебе говорить красиво!")
        .padding()
        .background(ColorTokens.Kid.bg)
}
