import SwiftUI

// MARK: - ARZoneTutorialSheetView

/// Modal sheet с инструкцией перед запуском AR-игры.
///
/// Показывается при первом запуске каждой AR-игры.
/// Содержит:
/// - SF Symbol анимацию (symbolEffect — без Lottie зависимости)
/// - Заголовок + короткое описание (1–2 предложения)
/// - До 3 шагов инструкции с SF Symbol иконками
/// - CTA «Начать» (≥ 56pt, kid-safe)
/// - Кнопку «Пропустить» (для повторных сессий)
///
/// Lottie: планируется замена `symbolEffect` на `HSLottieContainer`
/// после подключения LottieFiles SDK. Путь: Resources/Animations/Tutorials/{gameId}.json.
struct ARZoneTutorialSheetView: View {

    let tutorial: ARTutorial
    let onStart: () -> Void
    let onSkip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var symbolBounce: Int = 0
    @State private var stepsVisible: Bool = false

    private var accentColors: [Color] { ARCardPalette.gradient(for: tutorial.accentColorIndex) }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            dragHandle

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: SpacingTokens.large) {
                    heroSymbol
                    titleBlock
                    stepsBlock
                    Spacer(minLength: SpacingTokens.xLarge)
                    actionButtons
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.medium)
                .padding(.bottom, SpacingTokens.xxxLarge)
            }
        }
        .background(ColorTokens.Kid.bg.ignoresSafeArea())
        .onAppear {
            guard !reduceMotion else {
                stepsVisible = true
                return
            }
            withAnimation(MotionTokens.bounce.delay(0.15)) {
                symbolBounce += 1
            }
            withAnimation(MotionTokens.spring.delay(0.3)) {
                stepsVisible = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(String(localized: String.LocalizationValue(tutorial.titleKey))))
    }

    // MARK: - Drag handle

    private var dragHandle: some View {
        Capsule()
            .fill(ColorTokens.Kid.line.opacity(0.4))
            .frame(width: 36, height: 4)
            .padding(.top, SpacingTokens.small)
            .accessibilityHidden(true)
    }

    // MARK: - Hero SF Symbol (Lottie-ready placeholder)

    private var heroSymbol: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: accentColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .shadow(
                    color: accentColors.first?.opacity(0.35) ?? .clear,
                    radius: reduceMotion ? 0 : 18, x: 0, y: 8
                )

            Image(systemName: tutorial.animationSystemSymbol)
                .font(TypographyTokens.kidDisplay(52))
                .foregroundStyle(.white)
                .symbolEffect(.bounce.down, value: symbolBounce)
                .accessibilityHidden(true)
        }
        .padding(.top, SpacingTokens.large)
    }

    // MARK: - Title block

    private var titleBlock: some View {
        VStack(spacing: SpacingTokens.small) {
            Text(String(localized: String.LocalizationValue(tutorial.titleKey)))
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.8)

            Text(String(localized: String.LocalizationValue(tutorial.bodyKey)))
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, SpacingTokens.small)
    }

    // MARK: - Steps block

    @ViewBuilder
    private var stepsBlock: some View {
        if !tutorial.steps.isEmpty {
            HSLiquidGlassCard(style: .primary, padding: SpacingTokens.regular) {
                VStack(alignment: .leading, spacing: SpacingTokens.regular) {
                    ForEach(tutorial.steps.indices, id: \.self) { i in
                        let step = tutorial.steps[i]
                        tutorialStepRow(step: step, index: i)
                            .opacity(stepsVisible ? 1 : 0)
                            .offset(y: stepsVisible ? 0 : 12)
                            .animation(
                                reduceMotion ? nil : MotionTokens.spring.delay(Double(i) * 0.08),
                                value: stepsVisible
                            )
                    }
                }
            }
        }
    }

    private func tutorialStepRow(step: ARTutorialStep, index: Int) -> some View {
        HStack(alignment: .center, spacing: SpacingTokens.regular) {
            // Шаговый бейдж
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: accentColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                Image(systemName: step.icon)
                    .font(TypographyTokens.headline(18))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }

            Text(String(localized: String.LocalizationValue(step.textKey)))
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text("\(index + 1). \(String(localized: String.LocalizationValue(step.textKey)))")
        )
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        VStack(spacing: SpacingTokens.small) {
            // «Начать» — primary CTA, kid-safe ≥56pt
            Button(action: onStart) {
                HStack(spacing: SpacingTokens.small) {
                    Image(systemName: "play.fill")
                        .accessibilityHidden(true)
                    Text("ar.tutorial.cta.start")
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .font(TypographyTokens.headline(17).weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 56)
                .background(
                    LinearGradient(
                        colors: accentColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(RadiusTokens.button)
                .shadow(
                    color: accentColors.first?.opacity(0.3) ?? .clear,
                    radius: reduceMotion ? 0 : 10, x: 0, y: 5
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("ar.tutorial.cta.start"))

            // «Пропустить» — вторичная кнопка, меньше, полупрозрачная
            Button(action: onSkip) {
                Text("ar.tutorial.cta.skip")
                    .font(TypographyTokens.body(14).weight(.medium))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("ar.tutorial.cta.skip"))
        }
    }
}

// MARK: - Preview

#Preview("Tutorial Sheet — ARMirror") {
    ARZoneTutorialSheetView(
        tutorial: ARTutorialCatalog.tutorial(for: "ar-mirror"),
        onStart: {},
        onSkip: {}
    )
    .environment(AppContainer.preview())
}

#Preview("Tutorial Sheet — SoundAndFace") {
    ARZoneTutorialSheetView(
        tutorial: ARTutorialCatalog.tutorial(for: "sound-and-face"),
        onStart: {},
        onSkip: {}
    )
    .environment(AppContainer.preview())
}
