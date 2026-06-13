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
            Spacer(minLength: SpacingTokens.medium)

            // Welcome — единственный шаг с крупным приветственным маскотом в
            // мягком круге. Контент ВСЕГДА видим (без opacity-гейта), вход —
            // мягкий offset-settle через `.task`.
            ZStack {
                Circle()
                    .fill(ColorTokens.Kid.surface)
                    .overlay(
                        Circle()
                            .strokeBorder(ColorTokens.Brand.primary.opacity(0.16), lineWidth: 2)
                    )
                    .frame(width: 196, height: 196)
                    .shadow(
                        color: ColorTokens.Brand.primary.opacity(colorScheme == .dark ? 0.10 : 0.14),
                        radius: 14, x: 0, y: 6
                    )
                LyalyaHeroView(state: .waving, size: 168)
                    .opacity(colorScheme == .dark ? 0.94 : 1.0)
            }
            .accessibilityHidden(true)

            VStack(spacing: SpacingTokens.small) {
                Text(String(localized: "onboarding.welcome.title"))
                    .font(TypographyTokens.title(28))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
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
            .offset(y: appeared ? 0 : 14)
            .animation(reduceMotion ? nil : MotionTokens.spring, value: appeared)

            Spacer(minLength: SpacingTokens.medium)
        }
        .task {
            appeared = true
        }
    }
}

// MARK: - Step 2: Role

struct OnboardingRoleStep: View {
    let selectedRole: UserRole
    let onSelect: (UserRole) -> Void

    var body: some View {
        // Компактная вёрстка по эталону onboarding-step: шапка (маскот в круге +
        // заголовок + подзаголовок) + 3 карточки ролей. Всё влезает на SE 375×667
        // без скролла — гигантский 200pt-маскот заменён на 96pt-медальон.
        VStack(spacing: SpacingTokens.medium) {
            OnboardingStepHeader(
                mascotState: .pointing,
                title: String(localized: "onboarding.role.title"),
                subtitle: String(localized: "onboarding.role.subtitle"),
                mascotSize: 96
            )
            .padding(.top, SpacingTokens.small)

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

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
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
                            .minimumScaleFactor(0.85)
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
        VStack(spacing: SpacingTokens.medium) {
            OnboardingStepHeader(
                mascotState: .encouraging,
                title: String(localized: "onboarding.name.title"),
                subtitle: String(localized: "onboarding.name.subtitle"),
                mascotSize: 96
            )
            .padding(.top, SpacingTokens.small)

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
                                        nameFocused ? ColorTokens.Brand.primary : ColorTokens.Kid.line,
                                        lineWidth: nameFocused ? 2 : 1
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

            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                Text(String(localized: "onboarding.profile.avatar.label"))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .textCase(.uppercase)
                    .tracking(0.6)

                // Single-select: каждый аватар имеет УНИКАЛЬНЫЙ id (sf:cat … sf:hare),
                // выбор одного снимает остальные. 6 различимых животных в равномерной
                // сетке с симметричными отступами.
                HStack(spacing: SpacingTokens.small) {
                    ForEach(Array(OnboardingProfile.availableAvatars.enumerated()), id: \.offset) { index, option in
                        AvatarOption(
                            avatarToken: option,
                            tint: Self.avatarTint(index: index),
                            isSelected: avatar == option,
                            onTap: {
                                avatar = option
                                onChange(name, avatar)
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        // Закрытие клавиатуры по тапу ФОНА — на заднем слое, чтобы НЕ перехватывать
        // тапы по кнопкам-аватарам (раньше parent .onTapGesture глотал их выбор).
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { nameFocused = false }
        )
    }

    /// Тёплый акцент аватара по индексу — циклически из палитры приложения.
    private static func avatarTint(index: Int) -> Color {
        let palette: [Color] = [
            ColorTokens.Brand.primary,
            ColorTokens.Brand.lilac,
            ColorTokens.Brand.rose,
            ColorTokens.Brand.butter,
            ColorTokens.Brand.gold,
            ColorTokens.Brand.primaryHi
        ]
        return palette[index % palette.count]
    }
}

struct AvatarOption: View {
    /// Канонический style-id аватара (`cat`/`fox`/…) — совместим со всем
    /// приложением. Рисуется чистым SF Symbol'ом без растровой бахромы.
    let avatarToken: String
    let tint: Color
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(isSelected ? tint.opacity(0.18) : ColorTokens.Kid.surface)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isSelected ? tint : ColorTokens.Kid.line,
                                lineWidth: isSelected ? 2.5 : 1
                            )
                    )

                // Чистый векторный глиф — без растровой бахромы/обрезки.
                Image(systemName: OnboardingProfile.avatarSymbol(for: avatarToken))
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(isSelected ? tint : ColorTokens.Kid.inkMuted)
            }
            .frame(width: 56, height: 56)
            .scaleEffect(isSelected ? 1.08 : 1.0)
            .animation(reduceMotion ? nil : MotionTokens.spring, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(format: String(localized: "onboarding.a11y.avatar"), avatarToken))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Step 4: Age

struct OnboardingAgeStep: View {
    let age: Int
    let onChange: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Компактная вёрстка без скролла: шапка + ряд рекомендованных возрастов
        // (5–8) + компактный wheel-picker для прочих возрастов. На SE влезает.
        VStack(spacing: SpacingTokens.medium) {
            OnboardingStepHeader(
                mascotState: .thinking,
                title: String(localized: "onboarding.age.title"),
                subtitle: String(localized: "onboarding.age.subtitle"),
                mascotSize: 96
            )
            .padding(.top, SpacingTokens.small)

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
                .frame(height: 100)
                .clipped()
                .accessibilityLabel(String(localized: "onboarding.profile.age.label"))
            }
            .padding(.horizontal, SpacingTokens.screenEdge)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
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

    var body: some View {
        VStack(spacing: SpacingTokens.medium) {
            OnboardingStepHeader(
                mascotState: .thinking,
                title: String(localized: "onboarding.goals.title"),
                subtitle: String(localized: "onboarding.goals.subtitle"),
                mascotSize: 96
            )
            .padding(.top, SpacingTokens.small)

            // 5 целей — ScrollView включается только если контент реально
            // переполняет экран (basedOnSize). На 16 Pro скролла нет.
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
                .padding(.bottom, SpacingTokens.small)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity)
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

    // Фиксированная сетка 4 колонки: 12 звуков → 3 ряда, влезают на SE без
    // скролла. Равномерные симметричные отступы (flexible колонки).
    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: SpacingTokens.small),
        count: 4
    )

    var body: some View {
        VStack(spacing: SpacingTokens.medium) {
            OnboardingStepHeader(
                mascotState: .explaining,
                title: String(localized: "onboarding.sounds.title"),
                subtitle: String(localized: "onboarding.sounds.subtitle"),
                mascotSize: 92
            )
            .padding(.top, SpacingTokens.small)

            LazyVGrid(columns: columns, spacing: SpacingTokens.small) {
                ForEach(OnboardingProfile.availableSounds, id: \.id) { sound in
                    SoundChip(
                        label: sound.label,
                        isSelected: selectedSounds.contains(sound.id),
                        onTap: { onToggle(sound.id) }
                    )
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)

            Text(String(format: String(localized: "onboarding.sounds.selectedCount"), selectedSounds.count))
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .accessibilityLabel(
                    String(format: String(localized: "onboarding.sounds.selectedCount"), selectedSounds.count)
                )

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
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
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
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
