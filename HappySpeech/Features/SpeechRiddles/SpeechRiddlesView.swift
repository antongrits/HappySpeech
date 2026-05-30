import SwiftUI

// MARK: - SpeechRiddlesView

struct SpeechRiddlesView: View {

    let childId: String

    @State private var interactor: SpeechRiddlesInteractor?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private let columns = Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sp2), count: 2)

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()

                // Step 10 Batch A — Pattern 1: mesh .kidCool (sky/lilac/mint) подчёркивает
                // «думающий» режим разгадывания загадок.
                HSMeshGradientBackground(palette: .kidCool, animated: true)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.28 : 0.50)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)

                content
            }
            .navigationTitle(Text(String(localized: "speechRiddles.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
            .task {
                if interactor == nil {
                    interactor = SpeechRiddlesInteractor(childId: childId)
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            ScrollView {
                VStack(spacing: SpacingTokens.sp4) {
                    hero(state: interactor.state)
                    if let current = interactor.state.current {
                        prompt(riddle: current)
                        options(riddle: current, interactor: interactor)
                    } else {
                        completionCard(state: interactor.state)
                    }
                    cta(interactor: interactor)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
                .padding(.bottom, SpacingTokens.sp6)
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    private func hero(state: SpeechRiddlesModels.ViewState) -> some View {
        // Step 10 Batch A — Pattern 2: hero обёрнут в HSLiquidGlassCard.elevated.
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.regular) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .thinking, size: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "speechRiddles.hero.title"))
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "speechRiddles.hero.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                    HSProgressBar(value: state.progress, style: .kid)
                        .frame(height: 6)
                        .padding(.top, 4)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func prompt(riddle: SpeechRiddlesModels.Riddle) -> some View {
        HSCard(style: .elevated) {
            VStack(spacing: SpacingTokens.sp2) {
                Text(riddle.targetLetter)
                    .font(TypographyTokens.titleLarge(56).weight(.bold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                Text(riddle.prompt)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func options(
        riddle: SpeechRiddlesModels.Riddle,
        interactor: SpeechRiddlesInteractor
    ) -> some View {
        // Step 10 Batch A — Pattern 3: stagger fade+scale entrance на вариантах ответов.
        LazyVGrid(columns: columns, spacing: SpacingTokens.sp2) {
            ForEach(riddle.options) { option in
                optionTile(option, riddle: riddle, interactor: interactor)
                    .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] content, phase in
                        content
                            .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                            .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.92))
                    }
            }
        }
        .animation(reduceMotion ? nil : MotionTokens.settleSpring, value: riddle.id)
    }

    private func optionTile(
        _ option: SpeechRiddlesModels.Option,
        riddle: SpeechRiddlesModels.Riddle,
        interactor: SpeechRiddlesInteractor
    ) -> some View {
        let isCorrectFeedback: Bool = {
            if case .correct = interactor.state.feedback,
               option.id == riddle.correctOptionId {
                return true
            }
            return false
        }()
        let isWrongFeedback: Bool = {
            if case .wrong(let id) = interactor.state.feedback,
               option.id == id {
                return true
            }
            return false
        }()

        return Button {
            hapticService.impact(.light)
            interactor.answer(option.id)
        } label: {
            VStack(spacing: 6) {
                Text(option.emoji).font(.system(size: 52))
                Text(option.label)
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(optionBackground(isCorrectFeedback: isCorrectFeedback, isWrongFeedback: isWrongFeedback))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        optionBorder(isCorrectFeedback: isCorrectFeedback, isWrongFeedback: isWrongFeedback),
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(option.label))
        .accessibilityAddTraits(.isButton)
    }

    private func optionBackground(isCorrectFeedback: Bool, isWrongFeedback: Bool) -> Color {
        if isCorrectFeedback { return ColorTokens.Semantic.successBg }
        if isWrongFeedback { return ColorTokens.Semantic.errorBg }
        return ColorTokens.Kid.surface
    }

    private func optionBorder(isCorrectFeedback: Bool, isWrongFeedback: Bool) -> Color {
        if isCorrectFeedback { return ColorTokens.Semantic.success }
        if isWrongFeedback { return ColorTokens.Semantic.error }
        return ColorTokens.Kid.line
    }

    private func completionCard(state: SpeechRiddlesModels.ViewState) -> some View {
        HSCard(style: .tinted(ColorTokens.Semantic.successBg)) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .celebrating, size: 56)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Все загадки разгаданы!")
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                    Text("Счёт: \(state.score) из \(state.riddles.count)")
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }
                Spacer()
            }
        }
    }

    private func cta(interactor: SpeechRiddlesInteractor) -> some View {
        HSButton(
            interactor.state.isComplete
                ? "Сыграть снова"
                : String(localized: "speechRiddles.cta.action"),
            style: .primary,
            size: .large,
            icon: interactor.state.isComplete ? "arrow.counterclockwise" : "arrow.right"
        ) {
            hapticService.notification(.success)
            if interactor.state.isComplete {
                interactor.reset()
            } else if case .wrong = interactor.state.feedback {
                interactor.advance()
            }
        }
    }
}

// MARK: - Preview

#Preview("SpeechRiddles — Light") {
    SpeechRiddlesView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("SpeechRiddles — Dark") {
    SpeechRiddlesView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
