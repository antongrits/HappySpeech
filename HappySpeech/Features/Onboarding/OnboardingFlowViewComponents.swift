import SwiftUI

// MARK: - OnboardingFlowViewComponents
//
// Подкомпоненты шагов 1–6 онбординга. Все структуры — `internal`.

// MARK: - Step 1: Welcome

struct OnboardingWelcomeStep: View {
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer()
            // Block I v19: scaleEffect убран с 2D Ляли (требование: 2D без анимаций).
            // Оставлен только opacity-вход (fade-in) — минимально допустимый UX-переход.
            // F.tier1 v21: hero — мягче в dark.
            LyalyaHeroView(state: .waving, size: 240)
                .opacity(appeared ? (colorScheme == .dark ? 0.92 : 1.0) : 0)
                .accessibilityHidden(true)

            VStack(spacing: SpacingTokens.small) {
                Text(String(localized: "onboarding.welcome.title"))
                    .font(TypographyTokens.title(28))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, SpacingTokens.medium)
                    .accessibilityAddTraits(.isHeader)

                Text(String(localized: "onboarding.welcome.subtitle"))
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
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

struct OnboardingRoleStep: View {
    let selectedRole: UserRole
    let onSelect: (UserRole) -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // P1-01 v25: обёрнут в ScrollView (как соседние шаги childName/goals/sounds) —
        // маскот 200pt + 3 карточки переполняли экран iPhone SE (667pt),
        // карточка «Ребёнок» и кнопка «Далее» уходили за нижний край без прокрутки.
        ScrollView {
            VStack(spacing: SpacingTokens.medium) {
                Spacer(minLength: SpacingTokens.small)

                // Block I v19: scaleEffect убран с 2D Ляли.
                LyalyaHeroView(state: .pointing, size: 200)
                    .opacity(appeared ? 1 : 0)
                    .accessibilityHidden(true)

                Text(String(localized: "onboarding.role.title"))
                    .font(TypographyTokens.title(24))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, SpacingTokens.medium)
                    .accessibilityAddTraits(.isHeader)

                Text(String(localized: "onboarding.role.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, SpacingTokens.large)

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

                Spacer(minLength: SpacingTokens.medium)
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : MotionTokens.spring.delay(0.1)) {
                appeared = true
            }
        }
    }
}

struct OnboardingRoleCard: View {
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
                    Image(systemName: role.systemImageName)
                        .font(.system(size: 36, weight: .regular))
                        .foregroundStyle(ColorTokens.Brand.primary)
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
                        .font(TypographyTokens.title(22))
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

struct OnboardingNameStep: View {
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

                // E v21: Step 3 child name — .encouraging (3D Ляля поддерживает выбор имени).
                LyalyaHeroView(state: .encouraging, size: 200)
                    .accessibilityHidden(true)

                Text(String(localized: "onboarding.name.title"))
                    .font(TypographyTokens.title(24))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, SpacingTokens.medium)
                    .accessibilityAddTraits(.isHeader)

                Text(String(localized: "onboarding.name.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, SpacingTokens.large)

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
                        .onChange(of: name) { _, newValue in onChange(newValue, avatar) }
                        .onSubmit { nameFocused = false }
                        .accessibilityLabel(String(localized: "onboarding.profile.name.label"))
                }
                .padding(.horizontal, SpacingTokens.screenEdge)

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

struct AvatarOption: View {
    /// Block D v16: parameter `emoji` оставлен по имени для совместимости callsites,
    /// но его значение теперь — Asset name из Assets.xcassets.
    let emoji: String
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            Image(emoji)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(SpacingTokens.micro)
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
                .clipShape(Circle())
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(reduceMotion ? nil : MotionTokens.spring, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(format: String(localized: "onboarding.a11y.avatar"), emoji))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Step 4: Age

struct OnboardingAgeStep: View {
    let age: Int
    let onChange: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer(minLength: SpacingTokens.medium)

            LyalyaHeroView(state: .thinking, size: 200)
                .accessibilityHidden(true)

            VStack(spacing: SpacingTokens.small) {
                Text(String(localized: "onboarding.age.title"))
                    .font(TypographyTokens.title(24))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, SpacingTokens.medium)
                    .accessibilityAddTraits(.isHeader)

                Text(String(localized: "onboarding.age.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, SpacingTokens.large)
            }

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

            VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                Text(String(localized: "onboarding.age.other.label"))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .textCase(.uppercase)
                    .tracking(0.6)

                Picker(
                    String(localized: "onboarding.profile.age.label"),
                    selection: Binding(get: { age }, set: { onChange($0) })
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

struct AgeBubble: View {
    let value: Int
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text("\(value)")
                    .font(TypographyTokens.title(28))
                    .foregroundStyle(isSelected ? ColorTokens.Overlay.onAccent : ColorTokens.Kid.ink)
                Text(String(localized: "onboarding.age.years.short"))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(isSelected ? ColorTokens.Overlay.onAccent : ColorTokens.Kid.ink)
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

struct OnboardingGoalsStep: View {
    let selectedGoals: Set<String>
    let onToggle: (String) -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: SpacingTokens.medium) {
            // E v21: Step 5 goals — .thinking (3D Ляля размышляет над целями).
            LyalyaHeroView(state: .thinking, size: 200)
                .opacity(appeared ? 1 : 0)
                .accessibilityHidden(true)
                .padding(.top, SpacingTokens.small)

            Text(String(localized: "onboarding.goals.title"))
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, SpacingTokens.medium)
                .accessibilityAddTraits(.isHeader)

            Text(String(localized: "onboarding.goals.subtitle"))
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
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
        .onAppear {
            withAnimation(reduceMotion ? nil : MotionTokens.spring.delay(0.1)) {
                appeared = true
            }
        }
    }
}

struct GoalChipRow: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: SpacingTokens.small) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? ColorTokens.Brand.primary : ColorTokens.Kid.line)
                    .font(TypographyTokens.title(22))
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

// MARK: - Step 6: Sounds

struct OnboardingSoundsStep: View {
    let selectedSounds: Set<String>
    let onToggle: (String) -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = [
        GridItem(.adaptive(minimum: 70, maximum: 90), spacing: SpacingTokens.tiny)
    ]

    var body: some View {
        VStack(spacing: SpacingTokens.medium) {
            // Block I v19: scaleEffect убран с 2D Ляли.
            LyalyaHeroView(state: .explaining, size: 200)
                .opacity(appeared ? 1 : 0)
                .accessibilityHidden(true)
                .padding(.top, SpacingTokens.small)

            Text(String(localized: "onboarding.sounds.title"))
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.top, SpacingTokens.medium)
                .padding(.horizontal, SpacingTokens.medium)
                .accessibilityAddTraits(.isHeader)

            Text(String(localized: "onboarding.sounds.subtitle"))
                .font(TypographyTokens.body(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
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
        .onAppear {
            withAnimation(reduceMotion ? nil : MotionTokens.spring.delay(0.1)) {
                appeared = true
            }
        }
    }
}

struct SoundChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(TypographyTokens.title(22))
                .foregroundStyle(isSelected ? ColorTokens.Overlay.onAccent : ColorTokens.Kid.ink)
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
