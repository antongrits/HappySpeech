import SwiftUI

// MARK: - WordRhymeGameView

struct WordRhymeGameView: View {

    let childId: String

    @State private var interactor: WordRhymeGameInteractor?
    @Environment(AppContainer.self) private var container
    @Environment(\.exitGame) private var exitGame
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                // Step 10 Batch C — Pattern 1: kidWarm mesh палитра (тёплый
                // poetic вайб рифм). softLight overlay для глубины.
                HSMeshGradientBackground(palette: .kidWarm, animated: true)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.20 : 0.32)
                    .blendMode(.softLight)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                content
            }
            .navigationTitle(Text(String(localized: "wordRhyme.nav.title")))
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
                    let game = WordRhymeGameInteractor(
                        childId: childId,
                        worker: WordRhymeGameWorker(childRepository: container.childRepository),
                        adaptivePlanner: container.adaptivePlannerService
                    )
                    interactor = game
                    await game.load()
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            if !interactor.state.isLoaded {
                ProgressView().controlSize(.large)
            } else if interactor.state.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: SpacingTokens.sp4) {
                        hero(state: interactor.state)
                        if let current = interactor.state.current {
                            target(round: current)
                            optionsRow(round: current, interactor: interactor)
                        } else {
                            completionCard(state: interactor.state)
                        }
                        cta(interactor: interactor)
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.top, SpacingTokens.sp3)
                    .padding(.bottom, SpacingTokens.sp6)
                }
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.sp3) {
            LyalyaMascotView(state: .idle, size: 80)
                .accessibilityHidden(true)
            Text(String(localized: "wordRhyme.empty.title"))
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
        }
        .padding(SpacingTokens.screenEdge)
    }

    private func hero(state: WordRhymeGameModels.ViewState) -> some View {
        // Step 10 Batch C — Pattern 2: HSLiquidGlassCard(.elevated) — kavsoft
        // hero card поверх kidWarm mesh.
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp3) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .singing, size: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "wordRhyme.hero.title"))
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "wordRhyme.hero.subtitle"))
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

    private func target(round: WordRhymeGameModels.Round) -> some View {
        HSCard(style: .tinted(ColorTokens.Brand.butter.opacity(0.18))) {
            VStack(spacing: 6) {
                HSContentSymbol(round.targetAsset ?? "music.note", size: 60)
                Text(round.targetWord)
                    .font(TypographyTokens.titleLarge(28).weight(.bold))
                    .foregroundStyle(ColorTokens.Kid.ink)
                Text(String(localized: "wordRhyme.target.hint"))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
        }
    }

    private func optionsRow(
        round: WordRhymeGameModels.Round,
        interactor: WordRhymeGameInteractor
    ) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            ForEach(round.options) { option in
                optionRow(option, round: round, interactor: interactor)
                    // Step 10 Batch C — Pattern 3 + 4: scrollTransition stagger
                    // + parallax drift на rhyme option rows.
                    .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] content, phase in
                        content
                            .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                            .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.94))
                    }
                    .hsParallaxTile(factor: 0.25)
            }
        }
    }

    private func optionRow(
        _ option: WordRhymeGameModels.RhymeOption,
        round: WordRhymeGameModels.Round,
        interactor: WordRhymeGameInteractor
    ) -> some View {
        let isCorrect: Bool = {
            if case .correct = interactor.state.feedback,
               option.id == round.correctOptionId {
                return true
            }
            return false
        }()
        let isWrong: Bool = {
            if case .wrong(let id) = interactor.state.feedback, option.id == id {
                return true
            }
            return false
        }()

        return Button {
            hapticService.impact(.light)
            interactor.answer(option.id)
        } label: {
            HSCard(style: backgroundStyle(isCorrect: isCorrect, isWrong: isWrong)) {
                HStack(spacing: SpacingTokens.sp3) {
                    HSContentSymbol(option.asset ?? "music.note", size: 32)
                    Text(option.word)
                        .font(TypographyTokens.headline(18))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer()
                    if isCorrect {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(ColorTokens.Semantic.success)
                            // Step 10 Batch C — Pattern 5: bounce on correct
                            // (state-reactive feedback).
                            .hsSymbolEffect(.bounce, value: isCorrect)
                    } else if isWrong {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(ColorTokens.Semantic.error)
                            // Step 10 Batch C — Pattern 5: bounce on wrong
                            // (state-reactive feedback).
                            .hsSymbolEffect(.bounce, value: isWrong)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(option.word))
        .accessibilityAddTraits(.isButton)
    }

    private func backgroundStyle(isCorrect: Bool, isWrong: Bool) -> HSCardStyle {
        if isCorrect { return .tinted(ColorTokens.Semantic.successBg) }
        if isWrong { return .tinted(ColorTokens.Semantic.errorBg) }
        return .elevated
    }

    private func completionCard(state: WordRhymeGameModels.ViewState) -> some View {
        HSCard(style: .tinted(ColorTokens.Semantic.successBg)) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .celebrating, size: 56)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "wordRhyme.complete.title"))
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                    Text(String(
                        format: String(localized: "wordRhyme.complete.score %lld %lld"),
                        state.score, state.rounds.count
                    ))
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }
                Spacer()
            }
        }
    }

    private func cta(interactor: WordRhymeGameInteractor) -> some View {
        HSButton(
            interactor.state.isComplete
                ? String(localized: "wordRhyme.cta.again")
                : String(localized: "wordRhyme.cta.action"),
            style: .primary,
            size: .large,
            icon: interactor.state.isComplete ? "arrow.counterclockwise" : "arrow.right"
        ) {
            hapticService.notification(.success)
            if interactor.state.isComplete {
                Task { await interactor.load() }
            } else if case .wrong = interactor.state.feedback {
                interactor.advance()
            }
        }
    }
}

// MARK: - Preview

#Preview("WordRhymeGame — Light") {
    WordRhymeGameView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("WordRhymeGame — Dark") {
    WordRhymeGameView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
