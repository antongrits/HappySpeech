import SwiftUI
import OSLog

// MARK: - OnboardingFlowView
//
// 7-шаговый онбординг (welcome → role → profile → goals → permissions →
// modelDownload → completion).
//
// Сигнатура `init(onComplete:)` опциональна: если onComplete не передан,
// View использует `AppCoordinator.navigate(to: .parentHome)` (бывший дефолт).

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
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                progressHeader

                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                actionFooter
            }
        }
        .environment(\.circuitContext, .kid)
        .task { await bootstrap() }
        .onChange(of: display.pendingCompleted) { _, value in
            guard value else { return }
            display.consumeCompleted()
            handleCompletion()
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
                            .font(.system(size: 17, weight: .semibold))
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

            stepIndicator
                .padding(.horizontal, SpacingTokens.screenEdge)
        }
        .padding(.bottom, SpacingTokens.small)
    }

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                Circle()
                    .fill(circleColor(for: step))
                    .frame(width: step == display.currentStep ? 12 : 8,
                           height: step == display.currentStep ? 12 : 8)
                    .animation(reduceMotion ? nil : MotionTokens.spring, value: display.currentStep)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(display.progressLabel)
    }

    private func circleColor(for step: OnboardingStep) -> Color {
        if step.rawValue < display.currentStep.rawValue {
            return ColorTokens.Brand.primary
        }
        if step == display.currentStep {
            return ColorTokens.Brand.primary
        }
        return ColorTokens.Kid.line
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
            case .childProfile:
                OnboardingProfileStep(
                    profile: display.profile,
                    onChange: { name, age, avatar in
                        interactor?.setProfile(.init(name: name, age: age, avatar: avatar))
                    }
                )
            case .goals:
                OnboardingGoalsStep(
                    selectedGoals: display.profile.goals,
                    onToggle: { id in
                        interactor?.toggleGoal(.init(goalId: id))
                    }
                )
            case .permissions:
                OnboardingPermissionsStep(
                    onSkip: { interactor?.skipPermissions(.init()) }
                )
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

            if display.currentStep == .permissions || display.currentStep == .modelDownload {
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
        .padding(.bottom, SpacingTokens.large)
    }

    private var primaryButtonTitle: String {
        switch display.currentStep {
        case .welcome:        return String(localized: "onboarding.cta.start")
        case .role, .childProfile, .goals, .permissions:
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
        router.onCompleted = { profile in
            handleRouteCompletion(with: profile)
        }

        self.presenter = presenter
        self.interactor = interactor
        self.router = router

        interactor.loadOnboarding(.init())
    }

    private func handleCompletion() {
        router?.routeCompleted(profile: display.profile)
        if onComplete == nil {
            handleRouteCompletion(with: display.profile)
        }
    }

    private func handleRouteCompletion(with profile: OnboardingProfile) {
        if let onComplete {
            onComplete(profile)
            return
        }
        // Default behaviour from coordinator integration:
        switch profile.role {
        case .parent:     coordinator.navigate(to: .parentHome)
        case .specialist: coordinator.navigate(to: .specialistHome)
        case .child:      coordinator.navigate(to: .childHome(childId: "primary-child"))
        }
    }
}

// MARK: - Step 1: Welcome

private struct OnboardingWelcomeStep: View {
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer()
            HSMascotView(mood: .waving, size: 180)
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)
                .accessibilityHidden(true)

            VStack(spacing: SpacingTokens.small) {
                Text(String(localized: "onboarding.welcome.title"))
                    .font(TypographyTokens.title(28))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(String(localized: "onboarding.welcome.subtitle"))
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpacingTokens.large)
                    .lineSpacing(4)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            Spacer()
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : MotionTokens.spring.delay(0.15)) {
                appeared = true
            }
        }
    }
}

// MARK: - Step 2: Role

private struct OnboardingRoleStep: View {
    let selectedRole: UserRole
    let onSelect: (UserRole) -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.medium) {
            Text(String(localized: "onboarding.role.title"))
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.ink)
                .padding(.top, SpacingTokens.large)
                .accessibilityAddTraits(.isHeader)

            Text(String(localized: "onboarding.role.subtitle"))
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.large)

            Spacer()

            VStack(spacing: SpacingTokens.small) {
                ForEach(UserRole.allCases) { role in
                    OnboardingRoleCard(
                        role: role,
                        isSelected: role == selectedRole,
                        onTap: { onSelect(role) }
                    )
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)

            Spacer()
        }
    }
}

private struct OnboardingRoleCard: View {
    let role: UserRole
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: SpacingTokens.medium) {
                Text(role.emoji)
                    .font(.system(size: 40))
                    .frame(width: 56)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(role.displayName)
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Kid.ink)
                    Text(role.description)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? ColorTokens.Brand.primary : ColorTokens.Kid.line)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.medium)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                            .strokeBorder(
                                isSelected ? ColorTokens.Brand.primary : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(reduceMotion ? nil : MotionTokens.spring, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(role.displayName). \(role.description)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Step 3: Profile

private struct OnboardingProfileStep: View {
    let profile: OnboardingProfile
    let onChange: (String, Int, String) -> Void

    @State private var name: String
    @State private var age: Int
    @State private var avatar: String
    @FocusState private var nameFocused: Bool

    init(profile: OnboardingProfile, onChange: @escaping (String, Int, String) -> Void) {
        self.profile = profile
        self.onChange = onChange
        _name = State(initialValue: profile.childName)
        _age = State(initialValue: profile.childAge)
        _avatar = State(initialValue: profile.childAvatar)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.large) {
                Text(String(localized: "onboarding.profile.title"))
                    .font(TypographyTokens.title(24))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .padding(.top, SpacingTokens.medium)
                    .accessibilityAddTraits(.isHeader)

                // Avatar selection
                VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                    Text(String(localized: "onboarding.profile.avatar.label"))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    HStack(spacing: SpacingTokens.tiny) {
                        ForEach(OnboardingProfile.availableAvatars, id: \.self) { option in
                            AvatarOption(
                                emoji: option,
                                isSelected: avatar == option,
                                onTap: {
                                    avatar = option
                                    onChange(name, age, avatar)
                                }
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, SpacingTokens.screenEdge)

                // Name field
                VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                    Text(String(localized: "onboarding.profile.name.label"))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    TextField(String(localized: "onboarding.profile.name.placeholder"), text: $name)
                        .font(TypographyTokens.headline(18))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .padding(.vertical, SpacingTokens.medium)
                        .padding(.horizontal, SpacingTokens.large)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                                .fill(ColorTokens.Kid.surface)
                        )
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .onChange(of: name) { _, newValue in
                            onChange(newValue, age, avatar)
                        }
                        .onSubmit {
                            nameFocused = false
                        }
                        .accessibilityLabel(String(localized: "onboarding.profile.name.label"))
                }
                .padding(.horizontal, SpacingTokens.screenEdge)

                // Age picker
                VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                    Text(String(localized: "onboarding.profile.age.label"))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    Picker(String(localized: "onboarding.profile.age.label"), selection: $age) {
                        ForEach(OnboardingProfile.availableAges, id: \.self) { value in
                            Text(String(format: String(localized: "onboarding.profile.age.years"), value))
                                .tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 110)
                    .onChange(of: age) { _, newValue in
                        onChange(name, newValue, avatar)
                    }
                    .accessibilityLabel(String(localized: "onboarding.profile.age.label"))
                }
                .padding(.horizontal, SpacingTokens.screenEdge)

                Spacer(minLength: SpacingTokens.large)
            }
        }
    }
}

private struct AvatarOption: View {
    let emoji: String
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            Text(emoji)
                .font(.system(size: 36))
                .frame(width: 52, height: 52)
                .background(
                    Circle()
                        .fill(isSelected ? ColorTokens.Brand.primary.opacity(0.15) : ColorTokens.Kid.surface)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    isSelected ? ColorTokens.Brand.primary : Color.clear,
                                    lineWidth: 2
                                )
                        )
                )
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(reduceMotion ? nil : MotionTokens.spring, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(format: String(localized: "onboarding.a11y.avatar"), emoji))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Step 4: Goals

private struct OnboardingGoalsStep: View {
    let selectedGoals: Set<String>
    let onToggle: (String) -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.medium) {
            Text(String(localized: "onboarding.goals.title"))
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.ink)
                .padding(.top, SpacingTokens.medium)
                .accessibilityAddTraits(.isHeader)

            Text(String(localized: "onboarding.goals.subtitle"))
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.large)

            ScrollView {
                VStack(spacing: SpacingTokens.small) {
                    ForEach(OnboardingProfile.availableGoals, id: \.id) { goal in
                        GoalChipRow(
                            label: goal.label,
                            isSelected: selectedGoals.contains(goal.id),
                            onTap: { onToggle(goal.id) }
                        )
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
            }
        }
    }
}

private struct GoalChipRow: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: SpacingTokens.small) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? ColorTokens.Brand.primary : ColorTokens.Kid.line)
                    .font(.system(size: 22, weight: .semibold))
                    .accessibilityHidden(true)
                Text(label)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Kid.ink)
                Spacer()
            }
            .padding(SpacingTokens.medium)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                            .strokeBorder(
                                isSelected ? ColorTokens.Brand.primary : Color.clear,
                                lineWidth: 1.5
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.01 : 1.0)
            .animation(reduceMotion ? nil : MotionTokens.spring, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Step 5: Permissions

private struct OnboardingPermissionsStep: View {
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.medium) {
            Text(String(localized: "onboarding.permissions.title"))
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.ink)
                .padding(.top, SpacingTokens.medium)
                .accessibilityAddTraits(.isHeader)

            Text(String(localized: "onboarding.permissions.subtitle"))
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.large)

            VStack(spacing: SpacingTokens.small) {
                permissionCard(
                    icon: "mic.circle.fill",
                    title: String(localized: "onboarding.permissions.mic.title"),
                    body: String(localized: "onboarding.permissions.mic.body"),
                    color: ColorTokens.Brand.primary
                )
                permissionCard(
                    icon: "camera.circle.fill",
                    title: String(localized: "onboarding.permissions.camera.title"),
                    body: String(localized: "onboarding.permissions.camera.body"),
                    color: ColorTokens.Brand.lilac
                )
                permissionCard(
                    icon: "bell.circle.fill",
                    title: String(localized: "onboarding.permissions.notifications.title"),
                    body: String(localized: "onboarding.permissions.notifications.body"),
                    color: ColorTokens.Brand.butter
                )
            }
            .padding(.horizontal, SpacingTokens.screenEdge)

            Spacer()
        }
    }

    private func permissionCard(icon: String, title: String, body: String, color: Color) -> some View {
        HSCard(style: .elevated, padding: SpacingTokens.medium) {
            HStack(alignment: .top, spacing: SpacingTokens.medium) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(title)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                    Text(body)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                }
                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(body)")
    }
}

// MARK: - Step 6: Model Download

private struct OnboardingModelDownloadStep: View {
    let status: ModelDownloadStatus
    let statusLabel: String
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer()

            ZStack {
                Circle()
                    .fill(ColorTokens.Brand.sky.opacity(0.15))
                    .frame(width: 140, height: 140)
                Image(systemName: iconName)
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(ColorTokens.Brand.sky)
                    .accessibilityHidden(true)
            }

            VStack(spacing: SpacingTokens.small) {
                Text(String(localized: "onboarding.model.title"))
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(String(localized: "onboarding.model.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpacingTokens.large)
            }

            // Status / progress
            VStack(spacing: SpacingTokens.tiny) {
                Text(statusLabel)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .frame(maxWidth: .infinity)

                if case .downloading(let progress) = status {
                    HSProgressBar(value: progress, style: .kid)
                        .padding(.horizontal, SpacingTokens.large)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(statusLabel)

            // Auto-start CTA when idle
            if status == .idle {
                HSButton(
                    String(localized: "onboarding.cta.startDownload"),
                    style: .secondary,
                    size: .medium,
                    icon: "arrow.down.circle",
                    action: onStart
                )
                .padding(.horizontal, SpacingTokens.xLarge)
            }

            Spacer()
        }
    }

    private var iconName: String {
        switch status {
        case .completed: return "checkmark.circle.fill"
        case .downloading: return "arrow.down.circle"
        case .failed: return "exclamationmark.triangle.fill"
        case .skipped: return "forward.circle"
        case .idle: return "arrow.down.circle"
        }
    }
}

// MARK: - Step 7: Completion

private struct OnboardingCompletionStep: View {
    let profile: OnboardingProfile

    @State private var confettiAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let confettiEmojis = ["🎉", "✨", "🌟", "💫", "🎊", "⭐"]

    var body: some View {
        ZStack {
            ForEach(0..<confettiEmojis.count * 3, id: \.self) { i in
                let emoji = confettiEmojis[i % confettiEmojis.count]
                Text(emoji)
                    .font(.system(size: CGFloat.random(in: 22...32)))
                    .offset(
                        x: CGFloat.random(in: -160...160),
                        y: confettiAppeared ? CGFloat.random(in: 200...500) : -CGFloat.random(in: 200...400)
                    )
                    .opacity(confettiAppeared ? 0.9 : 0)
                    .accessibilityHidden(true)
            }

            VStack(spacing: SpacingTokens.large) {
                Spacer()

                Text(profile.childAvatar)
                    .font(.system(size: 100))
                    .accessibilityHidden(true)

                VStack(spacing: SpacingTokens.small) {
                    Text(String(format: String(localized: "onboarding.completion.title"), profile.childName.isEmpty ? "🙂" : profile.childName))
                        .font(TypographyTokens.title(28))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    Text(String(localized: "onboarding.completion.subtitle"))
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SpacingTokens.large)
                        .lineSpacing(4)
                }

                Spacer()
            }
        }
        .onAppear {
            if reduceMotion {
                confettiAppeared = true
            } else {
                withAnimation(.easeOut(duration: 1.6)) {
                    confettiAppeared = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Onboarding") {
    OnboardingFlowView(onComplete: { _ in })
        .environment(AppCoordinator())
}
