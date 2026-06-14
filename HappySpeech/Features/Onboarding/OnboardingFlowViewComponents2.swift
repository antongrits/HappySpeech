import SwiftUI

// MARK: - OnboardingFlowViewComponents2
//
// Подкомпоненты шагов 7–10 + вспомогательные view. Все структуры — `internal`.

// MARK: - Step 7: Schedule

struct OnboardingScheduleStep: View {
    let selectedMinutes: Int
    let onSelect: (Int) -> Void

    var body: some View {
        // SE-fix: шапка (маскот в круге) + 4 карточки расписания переполняют
        // 375×667 → footer «Далее» уезжал за нижний край и был недостижим.
        // Обёртка в ScrollView гарантирует достижимость footer на SE; на 16/17
        // Pro контент влезает и скролл не появляется (scrollBounceBehavior).
        ScrollView {
            VStack(spacing: SpacingTokens.medium) {
                OnboardingStepHeader(
                    mascotState: .happy,
                    title: String(localized: "onboarding.schedule.title"),
                    subtitle: String(localized: "onboarding.schedule.subtitle"),
                    mascotSize: 96
                )
                .padding(.top, SpacingTokens.small)

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
                .padding(.bottom, SpacingTokens.small)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.leading)
                    // Подзаголовок ОБЯЗАН переноситься целиком (без «…»): lineLimit(nil)
                    // + fixedSize(vertical) заставляют текст занять нужную высоту вместо
                    // обрезки. Раньше карточка сжималась и .lineLimit(2) усекал строку.
                    Text(preset.subtitle)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: SpacingTokens.tiny)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(isSelected ? ColorTokens.Brand.primary : ColorTokens.Kid.line)
                    .accessibilityHidden(true)
            }
            // Компактнее по вертикали (small вместо medium), чтобы 4 карточки +
            // маскот занимали меньше высоты на SE.
            .padding(.horizontal, SpacingTokens.medium)
            .padding(.vertical, SpacingTokens.small)
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

/// Plan v21 Block A.fix — permissions запрашиваются ТОЛЬКО на явный tap
/// пользователя по «Разрешить ...» CTA на карточке. На arrival шаг просто
/// показывает три карточки c кнопками — никакой iOS modal не открывается
/// без explicit user action. Callbacks дёргают `OnboardingInteractor`,
/// который запускает соответствующий системный API (AVAudioApplication /
/// AVCaptureDevice / UNUserNotificationCenter).
///
/// Опциональные callbacks: если nil — кнопки скрываются (для Preview).
struct OnboardingPermissionsStep: View {

    let onRequestMicrophone: (() -> Void)?
    let onRequestCamera: (() -> Void)?
    let onRequestNotifications: (() -> Void)?
    /// Текущий статус выданных разрешений (из Interactor через display).
    let micGranted: Bool
    let cameraGranted: Bool
    let notificationsGranted: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        onRequestMicrophone: (() -> Void)? = nil,
        onRequestCamera: (() -> Void)? = nil,
        onRequestNotifications: (() -> Void)? = nil,
        micGranted: Bool = false,
        cameraGranted: Bool = false,
        notificationsGranted: Bool = false
    ) {
        self.onRequestMicrophone = onRequestMicrophone
        self.onRequestCamera = onRequestCamera
        self.onRequestNotifications = onRequestNotifications
        self.micGranted = micGranted
        self.cameraGranted = cameraGranted
        self.notificationsGranted = notificationsGranted
    }

    var body: some View {
        // SE-fix: шапка (маскот в круге) + 3 карточки разрешений могут переполнить
        // 375×667 (особенно с раскрытыми grantedBadge) → footer уезжал за край.
        // Обёртка в ScrollView гарантирует достижимость footer на SE; на 16/17 Pro
        // скролла нет (scrollBounceBehavior(.basedOnSize)).
        ScrollView {
            VStack(spacing: SpacingTokens.medium) {
                OnboardingStepHeader(
                    mascotState: .pointing,
                    title: String(localized: "onboarding.permissions.title"),
                    subtitle: String(localized: "onboarding.permissions.subtitle"),
                    mascotSize: 92
                )
                .padding(.top, SpacingTokens.small)

                VStack(spacing: SpacingTokens.small) {
                    permissionCard(
                        icon: "mic.circle.fill",
                        texts: (
                            title: String(localized: "onboarding.permissions.mic.title"),
                            body: String(localized: "onboarding.permissions.mic.body"),
                            allowLabel: String(localized: "permissions.mic.allow")
                        ),
                        color: ColorTokens.Brand.primary,
                        granted: micGranted,
                        action: onRequestMicrophone
                    )
                    permissionCard(
                        icon: "camera.circle.fill",
                        texts: (
                            title: String(localized: "onboarding.permissions.camera.title"),
                            body: String(localized: "onboarding.permissions.camera.body"),
                            allowLabel: String(localized: "permissions.camera.allow")
                        ),
                        color: ColorTokens.Brand.lilac,
                        granted: cameraGranted,
                        action: onRequestCamera
                    )
                    permissionCard(
                        icon: "bell.circle.fill",
                        texts: (
                            title: String(localized: "onboarding.permissions.notifications.title"),
                            body: String(localized: "onboarding.permissions.notifications.body"),
                            allowLabel: String(localized: "permissions.notif.allow")
                        ),
                        color: ColorTokens.Brand.butter,
                        granted: notificationsGranted,
                        action: onRequestNotifications
                    )
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.small)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func permissionCard(
        icon: String,
        texts: (title: String, body: String, allowLabel: String),
        color: Color,
        granted: Bool,
        action: (() -> Void)?
    ) -> some View {
        HSLiquidGlassCard(style: .tinted(color), padding: SpacingTokens.medium) {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                HStack(alignment: .top, spacing: SpacingTokens.medium) {
                    Image(systemName: icon)
                        .font(TypographyTokens.display(32))
                        .foregroundStyle(color)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                        Text(texts.title)
                            .font(TypographyTokens.headline(16))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        // Причина разрешения переносится целиком (без «…») —
                        // карточка в ScrollView, высоты хватает.
                        Text(texts.body)
                            .font(TypographyTokens.body(13))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.85)
                    }
                    Spacer()
                }

                // Granted: показываем чек-пилюлю «Разрешено» (Semantic.success —
                // мелкий семантический акцент). Иначе — CTA «Разрешить ...», который
                // дёргает callback только при явном tap (iOS modal после tap).
                if granted {
                    grantedBadge
                } else if let action {
                    Button(action: action) {
                        Text(texts.allowLabel)
                            .font(TypographyTokens.headline(14))
                            .foregroundStyle(color)
                            .padding(.horizontal, SpacingTokens.medium)
                            .padding(.vertical, SpacingTokens.tiny)
                            .background(
                                Capsule()
                                    .fill(color.opacity(0.14))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(texts.allowLabel)
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
        // Плавная смена CTA «Разрешить» → бейдж «Разрешено» при изменении `granted`.
        // Анимация по `value: granted` дополнительно гарантирует ре-композицию
        // карточки сразу после публикации статуса из Interactor (карточка больше
        // не «застревает» на кнопке «Разрешить» после выдачи доступа).
        .animation(reduceMotion ? nil : MotionTokens.spring, value: granted)
        .accessibilityElement(children: .contain)
        .accessibilityValue(granted ? String(localized: "onboarding.permissions.mic.granted") : "")
    }

    private var grantedBadge: some View {
        HStack(spacing: SpacingTokens.micro) {
            Image(systemName: "checkmark.seal.fill")
                .font(TypographyTokens.headline(15))
                .foregroundStyle(ColorTokens.Semantic.success)
                .accessibilityHidden(true)
            Text(String(localized: "onboarding.permissions.mic.granted"))
                .font(TypographyTokens.headline(14))
                .foregroundStyle(ColorTokens.Semantic.success)
        }
        .padding(.horizontal, SpacingTokens.medium)
        .padding(.vertical, SpacingTokens.tiny)
        .background(
            Capsule()
                .fill(ColorTokens.Semantic.success.opacity(0.14))
        )
        .accessibilityLabel(String(localized: "onboarding.permissions.mic.granted"))
    }
}

// MARK: - Step 10: Completion

struct OnboardingCompletionStep: View {
    let profile: OnboardingProfile
    /// Текущее состояние чекбокса родительского согласия.
    let privacyAccepted: Bool
    /// Callback при изменении состояния чекбокса (вызывает interactor).
    let onTogglePrivacy: (Bool) -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // Спокойный статичный праздник: маскот в круге + аватар-бейдж + заголовок
        // с именем + согласие. БЕЗ хаотичной анимации падающих звёзд (убрана —
        // выглядела неряшливо). Контент влезает на SE без скролла.
        ScrollView {
            VStack(spacing: SpacingTokens.medium) {
                Spacer(minLength: SpacingTokens.small)

                celebrationMedallion

                VStack(spacing: SpacingTokens.small) {
                    Text(String(
                        format: String(localized: "onboarding.completion.title"),
                        profile.childName.isEmpty
                            ? String(localized: "onboarding.completion.placeholderName")
                            : profile.childName
                    ))
                    .font(TypographyTokens.title(26))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .accessibilityAddTraits(.isHeader)

                    Text(String(localized: "onboarding.completion.subtitle"))
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .padding(.horizontal, SpacingTokens.large)
                        .lineSpacing(4)
                }

                // MARK: Родительское согласие (COPPA)
                // Чекбокс обязателен: completeOnboarding проверяет profile.privacyAccepted.
                // Данные обрабатываются ЛОКАЛЬНО — без облака и внешних сервисов.
                privacyConsentToggle

                Spacer(minLength: SpacingTokens.small)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, SpacingTokens.screenEdge)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(reduceMotion ? nil : MotionTokens.spring, value: appeared)
        }
        .scrollBounceBehavior(.basedOnSize)
        .task { appeared = true }
    }

    // MARK: - Celebration medallion

    /// Маскот Ляля в мягком круге с маленьким бейджем выбранного аватара.
    private var celebrationMedallion: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                Circle()
                    .fill(ColorTokens.Kid.surface)
                    .overlay(
                        Circle()
                            .strokeBorder(ColorTokens.Brand.primary.opacity(0.18), lineWidth: 2)
                    )
                    .frame(width: 168, height: 168)
                    .shadow(
                        color: ColorTokens.Brand.primary.opacity(colorScheme == .dark ? 0.10 : 0.14),
                        radius: 12, x: 0, y: 5
                    )
                LyalyaHeroView(state: .celebrating, size: 144)
                    .opacity(colorScheme == .dark ? 0.94 : 1.0)
            }

            avatarBadge
                .offset(x: 4, y: 4)
        }
        .accessibilityHidden(true)
    }

    /// Бейдж выбранного аватара ребёнка — чистый SF Symbol по style-id.
    private var avatarBadge: some View {
        ZStack {
            Circle()
                .fill(ColorTokens.Brand.primary)
                .frame(width: 46, height: 46)
                .overlay(Circle().strokeBorder(ColorTokens.Kid.bg, lineWidth: 3))
            Image(systemName: OnboardingProfile.avatarSymbol(for: profile.childAvatar))
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(ColorTokens.Overlay.onAccent)
        }
    }

    // MARK: - Privacy consent toggle

    private var privacyConsentToggle: some View {
        Button {
            onTogglePrivacy(!privacyAccepted)
        } label: {
            HStack(alignment: .top, spacing: SpacingTokens.small) {
                // Квадратный чекбокс с SF Symbol
                ZStack {
                    RoundedRectangle(cornerRadius: RadiusTokens.xs, style: .continuous)
                        .fill(privacyAccepted
                              ? ColorTokens.Brand.primary
                              : ColorTokens.Kid.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: RadiusTokens.xs, style: .continuous)
                                .strokeBorder(
                                    privacyAccepted
                                        ? ColorTokens.Brand.primary
                                        : ColorTokens.Kid.line,
                                    lineWidth: 1.5
                                )
                        )
                        .frame(width: 24, height: 24)
                    if privacyAccepted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .animation(
                    reduceMotion ? nil : MotionTokens.spring,
                    value: privacyAccepted
                )
                .accessibilityHidden(true)

                Text(String(localized: "onboarding.completion.privacyConsent"))
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(SpacingTokens.medium)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .fill(privacyAccepted
                          ? ColorTokens.Brand.primary.opacity(0.08)
                          : ColorTokens.Kid.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                            .strokeBorder(
                                privacyAccepted
                                    ? ColorTokens.Brand.primary.opacity(0.4)
                                    : ColorTokens.Kid.line.opacity(0.5),
                                lineWidth: 1
                            )
                    )
            )
            .animation(reduceMotion ? nil : MotionTokens.spring, value: privacyAccepted)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "onboarding.completion.privacyConsent"))
        .accessibilityHint(String(localized: "onboarding.completion.privacyConsent.hint"))
        .accessibilityValue(privacyAccepted
                            ? String(localized: "accessibility.checkbox.checked")
                            : String(localized: "accessibility.checkbox.unchecked"))
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - OnboardingStepHeader
//
// Единая компактная «шапка» шага онбординга по эталону onboarding-step.png:
// компактный маскот Ляля в мягком кремовом круге сверху → заголовок →
// подзаголовок. Заменяет прежний гигантский 200pt-маскот + отдельный
// плавающий пузырь, который перекрывал интерактив. Маскот ~104pt влезает на
// SE 375×667 вместе с контентом и CTA без скролла.

struct OnboardingStepHeader: View {
    let mascotState: LyalyaState
    let title: String
    let subtitle: String
    var mascotSize: CGFloat = 104

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: SpacingTokens.small) {
            mascotMedallion

            Text(title)
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, SpacingTokens.medium)
                .accessibilityAddTraits(.isHeader)

            Text(subtitle)
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, SpacingTokens.large)
                .lineSpacing(2)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(reduceMotion ? nil : MotionTokens.spring, value: appeared)
        .task { appeared = true }
    }

    private var mascotMedallion: some View {
        ZStack {
            Circle()
                .fill(ColorTokens.Kid.surface)
                .overlay(
                    Circle()
                        .strokeBorder(ColorTokens.Brand.primary.opacity(0.18), lineWidth: 1.5)
                )
                .frame(width: mascotSize + 20, height: mascotSize + 20)
                .shadow(
                    color: ColorTokens.Brand.primary.opacity(colorScheme == .dark ? 0.08 : 0.12),
                    radius: 10, x: 0, y: 4
                )

            LyalyaMascotView(state: mascotState, size: mascotSize)
                .opacity(colorScheme == .dark ? 0.94 : 1.0)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - OnboardingMascotBubble

struct OnboardingMascotBubble: View {
    let text: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.small) {
            LyalyaMascotView(state: .explaining, size: 52)
                // F.tier1 v21: mascot чуть мягче в dark.
                .opacity(colorScheme == .dark ? 0.92 : 1.0)
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
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)

                Text(feature.description)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
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
    @Environment(\.colorScheme) private var colorScheme

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

            // Block I v19: scaleEffect убран с 2D Ляли.
            // F.tier1 v21: hero opacity для dark — чуть мягче, чтобы не слепил.
            LyalyaMascotView(state: .thinking, size: 130)
                .opacity(appeared ? (colorScheme == .dark ? 0.92 : 1.0) : 0)
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
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
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
