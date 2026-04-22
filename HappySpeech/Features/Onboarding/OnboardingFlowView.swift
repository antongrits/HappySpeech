import SwiftUI

// MARK: - OnboardingFlowView

struct OnboardingFlowView: View {
    @State private var currentStep = 0
    @State private var childName = ""
    @State private var childAge = 6
    @State private var selectedSounds: Set<String> = []
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let totalSteps = 4

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress
                progressHeader

                // Content
                TabView(selection: $currentStep) {
                    WelcomeStep(onContinue: nextStep)
                        .tag(0)

                    ChildNameStep(name: $childName, onContinue: nextStep)
                        .tag(1)

                    ChildAgeStep(age: $childAge, onContinue: nextStep)
                        .tag(2)

                    SoundSelectionStep(
                        selectedSounds: $selectedSounds,
                        onComplete: completeOnboarding
                    )
                    .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : MotionTokens.page, value: currentStep)
            }
        }
    }

    private var progressHeader: some View {
        VStack(spacing: SpacingTokens.sp3) {
            // Back button
            HStack {
                if currentStep > 0 {
                    Button {
                        withAnimation(reduceMotion ? nil : MotionTokens.page) {
                            currentStep -= 1
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .padding(SpacingTokens.sp3)
                    }
                    .accessibilityLabel(String(localized: "Назад"))
                }
                Spacer()
                Text("\(currentStep + 1) / \(totalSteps)")
                    .font(TypographyTokens.mono(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp3)

            // Progress bar
            HSProgressBar(value: Double(currentStep + 1) / Double(totalSteps), style: .kid)
                .padding(.horizontal, SpacingTokens.screenEdge)
        }
    }

    private func nextStep() {
        guard currentStep < totalSteps - 1 else { return }
        withAnimation(reduceMotion ? nil : MotionTokens.page) {
            currentStep += 1
        }
    }

    private func completeOnboarding() {
        coordinator.navigate(to: .parentHome)
    }
}

// MARK: - Step 0: Welcome

private struct WelcomeStep: View {
    let onContinue: () -> Void
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            HSMascotView(mood: .happy, size: 150)
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)

            VStack(spacing: SpacingTokens.sp3) {
                Text(String(localized: "Привет! Я Ляля —\nтвоя подружка-бабочка"))
                    .font(TypographyTokens.title(26))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, SpacingTokens.sp8)

                Text(String(localized: "Вместе мы будем учиться говорить звонко, красиво и весело."))
                    .font(TypographyTokens.body())
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpacingTokens.sp8)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            Spacer()

            HSButton(String(localized: "Продолжить"), icon: "arrow.right", action: onContinue)
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.sp8)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : MotionTokens.spring.delay(0.2)) {
                appeared = true
            }
        }
    }
}

// MARK: - Step 1: Child Name

private struct ChildNameStep: View {
    @Binding var name: String
    let onContinue: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: SpacingTokens.sp3) {
                Text(String(localized: "Как зовут ребёнка?"))
                    .font(TypographyTokens.title(24))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .padding(.top, SpacingTokens.sp8)

                Text(String(localized: "Введите имя, как обращаетесь дома"))
                    .font(TypographyTokens.body())
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)

            Spacer()

            HSMascotView(mood: isFocused ? .happy : .idle, size: 100)

            Spacer()

            VStack(spacing: SpacingTokens.sp5) {
                // Name input
                TextField(String(localized: "Например: Миша"), text: $name)
                    .font(TypographyTokens.headline(22))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .padding(.vertical, SpacingTokens.sp5)
                    .padding(.horizontal, SpacingTokens.sp6)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                            .fill(ColorTokens.Kid.surface)
                            .kidCardShadow()
                    )
                    .focused($isFocused)
                    .submitLabel(.next)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .onSubmit { if name.isValidChildName { onContinue() } }

                HSButton(
                    String(localized: "Продолжить"),
                    style: .primary,
                    icon: "arrow.right"
                ) {
                    isFocused = false
                    onContinue()
                }
                .disabled(!name.isValidChildName)
                .opacity(name.isValidChildName ? 1 : 0.5)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp8)
        }
        .onAppear { isFocused = true }
    }
}

// MARK: - Step 2: Child Age

private struct ChildAgeStep: View {
    @Binding var age: Int
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: SpacingTokens.sp3) {
                Text(String(localized: "Сколько лет ребёнку?"))
                    .font(TypographyTokens.title(24))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .padding(.top, SpacingTokens.sp8)

                Text(String(localized: "От этого зависит сложность заданий"))
                    .font(TypographyTokens.body())
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)

            Spacer()

            // Age selector: 4–8
            HStack(spacing: SpacingTokens.sp4) {
                ForEach(4...8, id: \.self) { ageValue in
                    AgeTile(value: ageValue, isSelected: age == ageValue) {
                        age = ageValue
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)

            Spacer()

            HSButton(String(localized: "Продолжить"), icon: "arrow.right", action: onContinue)
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.sp8)
        }
    }
}

private struct AgeTile: View {
    let value: Int
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text("\(value)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? .white : ColorTokens.Kid.inkMuted)
                .frame(width: 56, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .fill(isSelected ? ColorTokens.Brand.primary : ColorTokens.Kid.surface)
                )
                .scaleEffect(isSelected ? 1.08 : 1.0)
                .animation(reduceMotion ? nil : MotionTokens.spring, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(value) лет")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Step 3: Sound Selection

private struct SoundSelectionStep: View {
    @Binding var selectedSounds: Set<String>
    let onComplete: () -> Void

    private let soundGroups: [(family: SoundFamily, sounds: [String])] = [
        (.whistling, ["С", "З", "Ц"]),
        (.hissing, ["Ш", "Ж", "Ч", "Щ"]),
        (.sonorant, ["Р", "Рь", "Л", "Ль"]),
        (.velar, ["К", "Г", "Х"]),
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: SpacingTokens.sp3) {
                Text(String(localized: "Какие звуки тренируем?"))
                    .font(TypographyTokens.title(24))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .padding(.top, SpacingTokens.sp5)

                Text(String(localized: "Выберите один или несколько звуков. Можно добавить позже."))
                    .font(TypographyTokens.body())
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpacingTokens.sp8)
            }

            ScrollView {
                VStack(spacing: SpacingTokens.sp5) {
                    ForEach(soundGroups, id: \.family) { group in
                        SoundGroupRow(
                            family: group.family,
                            sounds: group.sounds,
                            selectedSounds: $selectedSounds
                        )
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.vertical, SpacingTokens.sp5)
            }

            HSButton(
                selectedSounds.isEmpty
                    ? String(localized: "Пропустить")
                    : String(localized: "Начать занятия"),
                style: selectedSounds.isEmpty ? .ghost : .primary,
                icon: "arrow.right",
                action: onComplete
            )
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp8)
        }
    }
}

private struct SoundGroupRow: View {
    let family: SoundFamily
    let sounds: [String]
    @Binding var selectedSounds: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            Text(family.displayName)
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.SoundFamilyColors.hue(for: family))
                .textCase(.uppercase)
                .tracking(1)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 60)), count: 4), spacing: SpacingTokens.sp3) {
                ForEach(sounds, id: \.self) { sound in
                    SoundChip(
                        sound: sound,
                        isSelected: selectedSounds.contains(sound),
                        accentColor: ColorTokens.SoundFamilyColors.hue(for: family)
                    ) {
                        if selectedSounds.contains(sound) {
                            selectedSounds.remove(sound)
                        } else {
                            selectedSounds.insert(sound)
                        }
                    }
                }
            }
        }
        .padding(SpacingTokens.sp4)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .fill(ColorTokens.SoundFamilyColors.background(for: family).opacity(0.5))
        )
    }
}

private struct SoundChip: View {
    let sound: String
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text(sound)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? .white : accentColor)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .fill(isSelected ? accentColor : accentColor.opacity(0.12))
                )
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .animation(reduceMotion ? nil : MotionTokens.bounce, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Звук \(sound)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Preview

#Preview("Onboarding") {
    OnboardingFlowView()
        .environment(AppCoordinator())
}
