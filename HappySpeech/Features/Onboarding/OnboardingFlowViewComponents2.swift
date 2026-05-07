import SwiftUI

// MARK: - OnboardingFlowViewComponents2
//
// Подкомпоненты шагов 7–10 + вспомогательные view. Все структуры — `internal`.

// MARK: - Step 7: Schedule

struct OnboardingScheduleStep: View {
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

struct ScheduleRow: View {
    let preset: DailySchedulePreset
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: SpacingTokens.medium) {
                Image(systemName: "clock.fill")
                    .font(TypographyTokens.title(24))
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
                    .font(TypographyTokens.title(22))
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

struct OnboardingPermissionsStep: View {

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
                    .font(TypographyTokens.display(32))
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

struct OnboardingModelDownloadStep: View {
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
                    .font(TypographyTokens.kidDisplay(56))
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

struct OnboardingCompletionStep: View {
    let profile: OnboardingProfile

    @State private var confettiAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Block D v16: эмодзи-частицы заменены на SF Symbol particles + tinted ColorTokens.
    private let confettiSymbols: [(systemName: String, tint: Color)] = [
        ("party.popper.fill", ColorTokens.Brand.gold),
        ("sparkles",          ColorTokens.Brand.primary),
        ("star.fill",         ColorTokens.Brand.gold),
        ("sparkle",           ColorTokens.Brand.lilac),
        ("heart.fill",        ColorTokens.Brand.rose),
        ("star.fill",         ColorTokens.Brand.sky)
    ]

    var body: some View {
        ZStack {
            ForEach(0..<confettiSymbols.count * 3, id: \.self) { i in
                let particle = confettiSymbols[i % confettiSymbols.count]
                Image(systemName: particle.systemName)
                    .font(.system(size: CGFloat.random(in: 22...32), weight: .regular))
                    .foregroundStyle(particle.tint)
                    .offset(
                        x: CGFloat.random(in: -160...160),
                        y: confettiAppeared ? CGFloat.random(in: 200...500) : -CGFloat.random(in: 200...400)
                    )
                    .opacity(confettiAppeared ? 0.9 : 0)
                    .accessibilityHidden(true)
            }

            VStack(spacing: SpacingTokens.large) {
                Spacer()

                LyalyaHeroView(state: .celebrating, mood: 1.0, size: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .accessibilityHidden(true)

                // Block D v16: avatar string is now an Asset name (illustrationName).
                // Backward-compat: если в строке legacy эмодзи — фолбэк на mascot_lyalya_happy.
                Image(profile.childAvatar.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
                      ? profile.childAvatar
                      : "mascot_lyalya_happy")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .accessibilityHidden(true)

                VStack(spacing: SpacingTokens.small) {
                    Text(String(
                        format: String(localized: "onboarding.completion.title"),
                        profile.childName.isEmpty
                            ? String(localized: "onboarding.completion.placeholderName")
                            : profile.childName
                    ))
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

struct OnboardingMascotBubble: View {
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

struct OnboardingAboutStep: View {

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
                        .font(TypographyTokens.headline(20))
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

struct OnboardingScreeningIntroStep: View {
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
                            .font(TypographyTokens.headline(18))
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
