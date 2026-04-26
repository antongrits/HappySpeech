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
        .padding(.bottom, SpacingTokens.large)
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

// MARK: - Step 1: Welcome

private struct OnboardingWelcomeStep: View {
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer()
            LyalyaMascotView(state: .waving, size: 180)
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
            HSLiquidGlassCard(
                style: isSelected ? .tinted(ColorTokens.Brand.primary) : .primary,
                padding: SpacingTokens.medium
            ) {
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
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isSelected ? ColorTokens.Brand.primary : ColorTokens.Kid.line)
                        .accessibilityHidden(true)
                }
            }
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(reduceMotion ? nil : MotionTokens.spring, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(role.displayName). \(role.description)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Step 3: ChildName + Avatar

private struct OnboardingNameStep: View {
    let profile: OnboardingProfile
    let onChange: (String, String) -> Void

    @State private var name: String
    @State private var avatar: String
    @FocusState private var nameFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(profile: OnboardingProfile, onChange: @escaping (String, String) -> Void) {
        self.profile = profile
        self.onChange = onChange
        _name = State(initialValue: profile.childName)
        _avatar = State(initialValue: profile.childAvatar)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.large) {
                Spacer(minLength: SpacingTokens.medium)

                LyalyaMascotView(state: .pointing, size: 100)
                    .accessibilityHidden(true)

                Text(String(localized: "onboarding.name.title"))
                    .font(TypographyTokens.title(24))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpacingTokens.large)
                    .accessibilityAddTraits(.isHeader)

                Text(String(localized: "onboarding.name.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpacingTokens.xLarge)

                // Name field
                VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                    Text(String(localized: "onboarding.profile.name.label"))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    TextField(String(localized: "onboarding.name.placeholder"), text: $name)
                        .font(TypographyTokens.headline(18))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .padding(.vertical, SpacingTokens.medium)
                        .padding(.horizontal, SpacingTokens.large)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                                .fill(ColorTokens.Kid.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                                        .strokeBorder(
                                            nameFocused ? ColorTokens.Brand.primary : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        )
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .onChange(of: name) { _, newValue in
                            onChange(newValue, avatar)
                        }
                        .onSubmit {
                            nameFocused = false
                        }
                        .accessibilityLabel(String(localized: "onboarding.profile.name.label"))
                }
                .padding(.horizontal, SpacingTokens.screenEdge)

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
                                    onChange(name, avatar)
                                }
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - Step 4: Age

private struct OnboardingAgeStep: View {
    let age: Int
    let onChange: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer(minLength: SpacingTokens.medium)

            LyalyaMascotView(state: .thinking, size: 110)
                .accessibilityHidden(true)

            VStack(spacing: SpacingTokens.small) {
                Text(String(localized: "onboarding.age.title"))
                    .font(TypographyTokens.title(24))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpacingTokens.large)
                    .accessibilityAddTraits(.isHeader)

                Text(String(localized: "onboarding.age.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpacingTokens.xLarge)
            }

            // Большие круглые кнопки 5/6/7/8 + строка «другое»
            HStack(spacing: SpacingTokens.small) {
                ForEach(OnboardingProfile.recommendedAgeRange, id: \.self) { value in
                    AgeBubble(
                        value: value,
                        isSelected: age == value,
                        onTap: { onChange(value) }
                    )
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)

            // Picker для нестандартных возрастов (3-4, 9-12)
            VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                Text(String(localized: "onboarding.age.other.label"))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .textCase(.uppercase)
                    .tracking(0.6)

                Picker(
                    String(localized: "onboarding.profile.age.label"),
                    selection: Binding(
                        get: { age },
                        set: { onChange($0) }
                    )
                ) {
                    ForEach(OnboardingProfile.availableAges, id: \.self) { value in
                        Text(String(format: String(localized: "onboarding.profile.age.years"), value))
                            .tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 110)
                .accessibilityLabel(String(localized: "onboarding.profile.age.label"))
            }
            .padding(.horizontal, SpacingTokens.screenEdge)

            Spacer(minLength: SpacingTokens.medium)
        }
    }
}

private struct AgeBubble: View {
    let value: Int
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text("\(value)")
                    .font(TypographyTokens.title(28))
                    .foregroundStyle(isSelected ? .white : ColorTokens.Kid.ink)
                Text(String(localized: "onboarding.age.years.short"))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(isSelected ? Color.white : ColorTokens.Kid.ink)
            }
            .frame(width: 70, height: 70)
            .background(
                Circle()
                    .fill(isSelected ? ColorTokens.Brand.primary : ColorTokens.Kid.surface)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isSelected ? Color.clear : ColorTokens.Kid.line,
                                lineWidth: 1.5
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.08 : 1.0)
            .animation(reduceMotion ? nil : MotionTokens.spring, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(format: String(localized: "onboarding.profile.age.years"), value))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Step 5: Goals

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

// MARK: - Step 6: Sounds (NEW)

private struct OnboardingSoundsStep: View {
    let selectedSounds: Set<String>
    let onToggle: (String) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 70, maximum: 90), spacing: SpacingTokens.tiny)
    ]

    var body: some View {
        VStack(spacing: SpacingTokens.medium) {
            Text(String(localized: "onboarding.sounds.title"))
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
                .padding(.top, SpacingTokens.medium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.large)
                .accessibilityAddTraits(.isHeader)

            Text(String(localized: "onboarding.sounds.subtitle"))
                .font(TypographyTokens.body(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.large)

            ScrollView {
                LazyVGrid(columns: columns, spacing: SpacingTokens.tiny) {
                    ForEach(OnboardingProfile.availableSounds, id: \.id) { sound in
                        SoundChip(
                            label: sound.label,
                            isSelected: selectedSounds.contains(sound.id),
                            onTap: { onToggle(sound.id) }
                        )
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.tiny)
            }

            Text(String(format: String(localized: "onboarding.sounds.selectedCount"), selectedSounds.count))
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .accessibilityLabel(
                    String(format: String(localized: "onboarding.sounds.selectedCount"), selectedSounds.count)
                )
        }
    }
}

private struct SoundChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(TypographyTokens.title(22))
                .foregroundStyle(isSelected ? .white : ColorTokens.Kid.ink)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(isSelected ? ColorTokens.Brand.primary : ColorTokens.Kid.surface)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    isSelected ? Color.clear : ColorTokens.Kid.line,
                                    lineWidth: 1.5
                                )
                        )
                )
                .scaleEffect(isSelected ? 1.06 : 1.0)
                .animation(reduceMotion ? nil : MotionTokens.spring, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(format: String(localized: "onboarding.a11y.sound"), label))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Step 7: Schedule (NEW)

private struct OnboardingScheduleStep: View {
    let selectedMinutes: Int
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.medium) {
            Spacer(minLength: SpacingTokens.medium)

            LyalyaMascotView(state: .happy, size: 100)
                .accessibilityHidden(true)

            Text(String(localized: "onboarding.schedule.title"))
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.large)
                .accessibilityAddTraits(.isHeader)

            Text(String(localized: "onboarding.schedule.subtitle"))
                .font(TypographyTokens.body(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.xLarge)

            VStack(spacing: SpacingTokens.small) {
                ForEach(DailySchedulePreset.allPresets) { preset in
                    ScheduleRow(
                        preset: preset,
                        isSelected: preset.minutes == selectedMinutes,
                        onTap: { onSelect(preset.minutes) }
                    )
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)

            Spacer(minLength: SpacingTokens.medium)
        }
    }
}

private struct ScheduleRow: View {
    let preset: DailySchedulePreset
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: SpacingTokens.medium) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? ColorTokens.Brand.primary : ColorTokens.Kid.inkMuted)
                    .frame(width: 36)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(preset.title)
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Kid.ink)
                    Text(preset.subtitle)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? ColorTokens.Brand.primary : ColorTokens.Kid.line)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.medium)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                            .strokeBorder(
                                isSelected ? ColorTokens.Brand.primary : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.01 : 1.0)
            .animation(reduceMotion ? nil : MotionTokens.spring, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(preset.title). \(preset.subtitle)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Step 8: Permissions

private struct OnboardingPermissionsStep: View {

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
        HSLiquidGlassCard(style: .tinted(color), padding: SpacingTokens.medium) {
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

// MARK: - Step 9: Model Download

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
        case .completed:   return "checkmark.circle.fill"
        case .downloading: return "arrow.down.circle"
        case .failed:      return "exclamationmark.triangle.fill"
        case .skipped:     return "forward.circle"
        case .idle:        return "arrow.down.circle"
        }
    }
}

// MARK: - Step 10: Completion

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

                LyalyaMascotView(state: .celebrating, size: 150)
                    .accessibilityHidden(true)

                Text(profile.childAvatar)
                    .font(.system(size: 60))
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

// MARK: - OnboardingMascotBubble
//
// Небольшой пузырёк с фразой Ляли — отображается под шагами,
// где `display.mascotText` непустой.

private struct OnboardingMascotBubble: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.small) {
            LyalyaMascotView(state: .explaining, size: 52)
                .accessibilityHidden(true)

            Text(text)
                .font(TypographyTokens.body(13))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SpacingTokens.small)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .fill(ColorTokens.Kid.surface)
                )
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}

// MARK: - OnboardingAboutStep
//
// 4 feature-карточки в сетке 2×2, описывающие ключевые возможности приложения.
// Показывается после Welcome или Role (в зависимости от UX-решения).

private struct OnboardingAboutStep: View {

    private struct Feature: Identifiable {
        let id: Int
        let icon: String
        let title: String
        let description: String
        let color: Color
    }

    private let features: [Feature] = [
        .init(
            id: 1,
            icon: "gamecontroller.fill",
            title: String(localized: "onboarding.about.feature1.title"),
            description: String(localized: "onboarding.about.feature1.desc"),
            color: ColorTokens.Brand.primary
        ),
        .init(
            id: 2,
            icon: "waveform.badge.mic",
            title: String(localized: "onboarding.about.feature2.title"),
            description: String(localized: "onboarding.about.feature2.desc"),
            color: ColorTokens.Brand.lilac
        ),
        .init(
            id: 3,
            icon: "wifi.slash",
            title: String(localized: "onboarding.about.feature3.title"),
            description: String(localized: "onboarding.about.feature3.desc"),
            color: ColorTokens.Brand.sky
        ),
        .init(
            id: 4,
            icon: "person.2.fill",
            title: String(localized: "onboarding.about.feature4.title"),
            description: String(localized: "onboarding.about.feature4.desc"),
            color: ColorTokens.Brand.mint
        )
    ]

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: SpacingTokens.medium) {
            Text(String(localized: "onboarding.about.title"))
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.large)
                .padding(.top, SpacingTokens.medium)
                .accessibilityAddTraits(.isHeader)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: SpacingTokens.small
            ) {
                ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                    featureCard(feature, delay: Double(index) * 0.08)
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : MotionTokens.spring.delay(0.1)) {
                appeared = true
            }
        }
    }

    private func featureCard(_ feature: Feature, delay: Double) -> some View {
        HSLiquidGlassCard(style: .tinted(feature.color), padding: SpacingTokens.medium) {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                ZStack {
                    RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                        .fill(feature.color.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: feature.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(feature.color)
                        .accessibilityHidden(true)
                }

                Text(feature.title)
                    .font(TypographyTokens.headline(14))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)

                Text(feature.description)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(feature.title). \(feature.description)")
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(
            reduceMotion ? nil : MotionTokens.spring.delay(delay + 0.15),
            value: appeared
        )
    }
}

// MARK: - OnboardingScreeningIntroStep
//
// Вводный экран скрининга: маскот Ляля + описание + 2 CTA.
// «Пройти скрининг» → переходим к скрининговым вопросам (следующий шаг).
// «Пропустить» → Interactor пропускает шаг.
//
// Скрининг — опциональная диагностическая пауза между Schedule и Permissions.
// Она помогает подобрать первый content pack точнее.

private struct OnboardingScreeningIntroStep: View {
    let onStartScreening: () -> Void
    let onSkipScreening: () -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let features: [(icon: String, text: String)] = [
        ("checkmark.circle.fill",
         String(localized: "onboarding.about.feature1.desc")),
        ("mic.circle.fill",
         String(localized: "onboarding.about.feature2.desc")),
        ("clock.badge.checkmark.fill",
         String(localized: "onboarding.screening.subtitle"))
    ]

    var body: some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer(minLength: SpacingTokens.small)

            LyalyaMascotView(state: .thinking, size: 130)
                .scaleEffect(appeared ? 1 : 0.7)
                .opacity(appeared ? 1 : 0)
                .accessibilityHidden(true)

            VStack(spacing: SpacingTokens.small) {
                Text(String(localized: "onboarding.screening.title"))
                    .font(TypographyTokens.title(24))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpacingTokens.large)
                    .accessibilityAddTraits(.isHeader)

                Text(String(localized: "onboarding.mascot.complete"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpacingTokens.xLarge)
                    .lineSpacing(3)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)

            VStack(spacing: SpacingTokens.small) {
                ForEach(features.indices, id: \.self) { index in
                    HStack(spacing: SpacingTokens.small) {
                        Image(systemName: features[index].icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .frame(width: 28)
                            .accessibilityHidden(true)
                        Text(features[index].text)
                            .font(TypographyTokens.body(13))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, SpacingTokens.tiny)
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: SpacingTokens.tiny) {
                HSButton(
                    String(localized: "onboarding.screening.cta"),
                    style: .primary,
                    icon: "checkmark"
                ) {
                    onStartScreening()
                }
                .padding(.horizontal, SpacingTokens.screenEdge)

                Button {
                    onSkipScreening()
                } label: {
                    Text(String(localized: "onboarding.screening.skip"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .padding(.vertical, SpacingTokens.tiny)
                }
                .accessibilityLabel(String(localized: "onboarding.screening.skip"))
            }

            Spacer(minLength: SpacingTokens.small)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : MotionTokens.spring.delay(0.1)) {
                appeared = true
            }
        }
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
