import SwiftUI

// MARK: - SentenceBuilderKidView

struct SentenceBuilderKidView: View {

    let childId: String

    @State private var interactor: SentenceBuilderKidInteractor?
    @Environment(AppContainer.self) private var container
    @Environment(\.exitGame) private var exitGame
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                // Step 10 Batch G — Pattern 1: kidCool mesh палитра (sentence-building).
                HSMeshGradientBackground(palette: .kidCool, animated: true)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.20 : 0.30)
                    .blendMode(.softLight)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                content
            }
            .navigationTitle(Text(String(localized: "sentenceBuilder.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exitGame()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
            .task {
                if interactor == nil {
                    let new = SentenceBuilderKidInteractor(
                        childId: childId,
                        childRepository: container.childRepository,
                        adaptivePlanner: container.adaptivePlannerService
                    )
                    interactor = new
                    await new.load()
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor, interactor.state.isLoaded {
            ScrollView {
                VStack(spacing: SpacingTokens.sp4) {
                    hero
                    assembledZone(interactor: interactor)
                    availableZone(interactor: interactor)
                    if interactor.state.isFull {
                        resultCard(state: interactor.state)
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

    private var hero: some View {
        // Step 10 Batch G — Pattern 2: HSLiquidGlassCard(.elevated) для hero.
        HSLiquidGlassCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .explaining, size: 56)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "sentenceBuilder.hero.title"))
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "sentenceBuilder.hero.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func assembledZone(interactor: SentenceBuilderKidInteractor) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            KidSectionLabel(String(localized: "sentenceBuilder.yourSentence"))
            assembledCard(interactor: interactor)
        }
    }

    private func assembledCard(interactor: SentenceBuilderKidInteractor) -> some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                if interactor.state.assembled.isEmpty {
                    Text(String(localized: "sentenceBuilder.tapWords"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkSoft)
                        .padding(.vertical, SpacingTokens.sp2)
                } else {
                    flowLayout(chips: interactor.state.assembled, isAssembled: true) { id in
                        hapticService.impact(.light)
                        interactor.removeFromAssembled(id)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        }
    }

    private func availableZone(interactor: SentenceBuilderKidInteractor) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            KidSectionLabel(String(localized: "sentenceBuilder.availableWords"))
            KidTrayContainer {
                Group {
                    if interactor.state.available.isEmpty {
                        Text(String(localized: "sentenceBuilder.allUsed"))
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                            .frame(maxWidth: .infinity, minHeight: 56)
                    } else {
                        flowLayout(chips: interactor.state.available, isAssembled: false) { id in
                            hapticService.impact(.light)
                            interactor.pickFromAvailable(id)
                        }
                        .frame(minHeight: 56)
                    }
                }
            }
        }
    }

    /// Простой wrap-flow для чипов — используем `FlowLayout`-like через HStack
    /// внутри `LazyVStack` нельзя; пока маленькое количество чипов — обёртываем
    /// руками через 2 HStack-строки.
    private func flowLayout(
        chips: [SentenceBuilderKidModels.WordChip],
        isAssembled: Bool,
        onTap: @escaping (UUID) -> Void
    ) -> some View {
        // Простая wrap-имитация: ScrollView horizontal с HStack.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.sp2) {
                ForEach(chips) { chip in
                    chipView(chip, isAssembled: isAssembled) {
                        onTap(chip.id)
                    }
                    // Step 10 Batch G — Pattern 3: scrollTransition stagger.
                    .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] content, phase in
                        content
                            .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                            .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.9))
                    }
                    // Step 10 Batch G — Pattern 4: parallax drift на word chips.
                    .hsParallaxTile(factor: 0.15)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func chipView(
        _ chip: SentenceBuilderKidModels.WordChip,
        isAssembled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(chip.text)
                .font(TypographyTokens.headline(16).weight(.semibold))
                .foregroundStyle(
                    isAssembled ? ColorTokens.Overlay.onAccent : ColorTokens.Kid.ink
                )
                .padding(.horizontal, SpacingTokens.sp3)
                .padding(.vertical, SpacingTokens.sp2)
                .background(
                    Capsule().fill(
                        isAssembled ? ColorTokens.Brand.primary : ColorTokens.Kid.surface
                    )
                )
                .overlay(
                    Capsule().stroke(
                        isAssembled ? Color.clear : ColorTokens.Kid.line,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(chip.text))
        .accessibilityHint(Text(isAssembled
            ? String(localized: "sentenceBuilder.a11y.remove")
            : String(localized: "sentenceBuilder.a11y.add")))
        .accessibilityAddTraits(.isButton)
    }

    private func resultCard(state: SentenceBuilderKidModels.ViewState) -> some View {
        HSCard(style: .tinted(state.isCorrect ? ColorTokens.Semantic.successBg : ColorTokens.Semantic.errorBg)) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: state.isCorrect ? .celebrating : .thinking, size: 48)
                    .accessibilityHidden(true)
                Text(state.isCorrect
                     ? String(localized: "sentenceBuilder.result.correct")
                     : String(localized: "sentenceBuilder.result.retry"))
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Kid.ink)
                Spacer()
                // Step 10 Batch G — Pattern 5: bounce on result state.
                Image(systemName: state.isCorrect ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill")
                    .font(.title3)
                    .foregroundStyle(state.isCorrect ? ColorTokens.Brand.mint : ColorTokens.Brand.butter)
                    .hsSymbolEffect(.bounce, value: state.isCorrect)
            }
        }
    }

    @ViewBuilder
    private func cta(interactor: SentenceBuilderKidInteractor) -> some View {
        if interactor.state.isGameComplete {
            HSCard(style: .tinted(ColorTokens.Semantic.successBg)) {
                HStack(spacing: SpacingTokens.sp3) {
                    LyalyaMascotView(state: .celebrating, size: 48)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "sentenceBuilder.gameDone"))
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Kid.ink)
                        Text(String(
                            format: String(localized: "kidGame.stars %lld"),
                            interactor.state.stars
                        ))
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(ColorTokens.Semantic.warning)
                    }
                    Spacer()
                }
            }
        } else if interactor.state.isCorrect {
            HSButton(
                String(localized: "sentenceBuilder.cta.next"),
                style: .primary,
                size: .large,
                icon: "arrow.right"
            ) {
                hapticService.notification(.success)
                interactor.next()
            }
        } else {
            HSButton(
                String(localized: "sentenceBuilder.cta.action"),
                style: .secondary,
                size: .large,
                icon: "arrow.counterclockwise"
            ) {
                hapticService.impact(.light)
                interactor.reset()
            }
        }
    }
}

// MARK: - Preview

#Preview("SentenceBuilderKid — Light") {
    SentenceBuilderKidView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("SentenceBuilderKid — Dark") {
    SentenceBuilderKidView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
