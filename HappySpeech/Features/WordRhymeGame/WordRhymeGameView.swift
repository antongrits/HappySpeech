import SwiftUI

// MARK: - WordRhymeGameView

struct WordRhymeGameView: View {

    let childId: String

    @State private var interactor: WordRhymeGameInteractor?
    @Environment(AppContainer.self) private var container
    @Environment(\.exitGame) private var exitGame
    @Environment(\.hapticService) private var hapticService

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                content
            }
            .navigationBarHidden(true)
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if interactor.state.isEmpty {
                emptyState
            } else {
                let state = interactor.state
                KidGameTapScaffold(
                    progress: state.progress,
                    promptText: state.current != nil
                        ? String(localized: "wordRhyme.target.hint")
                        : String(localized: "wordRhyme.complete.title"),
                    mascotState: state.current != nil ? .singing : .celebrating,
                    feedback: currentFeedback(state),
                    primary: primaryAction(interactor: interactor),
                    onClose: { exitGame() }
                ) {
                    if let current = state.current {
                        targetCard(round: current)
                        optionsGrid(round: current, interactor: interactor)
                    } else {
                        completionCard(state: state)
                    }
                }
            }
        } else {
            ProgressView().controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(SpacingTokens.screenEdge)
    }

    private func currentFeedback(_ state: WordRhymeGameModels.ViewState) -> KidGameFeedback? {
        switch state.feedback {
        case .correct:
            return KidGameFeedback(.correct, String(localized: "wordRhyme.target.hint"))
        case .wrong:
            return KidGameFeedback(.incorrect, String(localized: "wordRhyme.target.hint"))
        default:
            return nil
        }
    }

    private func primaryAction(interactor: WordRhymeGameInteractor) -> KidGamePrimaryAction? {
        let state = interactor.state
        if state.isComplete {
            return KidGamePrimaryAction(
                title: String(localized: "wordRhyme.cta.again"),
                icon: "arrow.counterclockwise"
            ) {
                hapticService.notification(.success)
                Task { await interactor.load() }
            }
        }
        if case .wrong = state.feedback {
            return KidGamePrimaryAction(
                title: String(localized: "wordRhyme.cta.action"),
                icon: "arrow.right"
            ) {
                hapticService.notification(.success)
                interactor.advance()
            }
        }
        return nil
    }

    private func targetCard(round: WordRhymeGameModels.Round) -> some View {
        VStack(spacing: SpacingTokens.tiny) {
            HSContentSymbol(round.targetAsset ?? "music.note", size: 56)
                .accessibilityHidden(true)
            Text(round.targetWord)
                .font(TypographyTokens.titleLarge(28).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(nil)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.regular)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .fill(ColorTokens.Brand.butter.opacity(0.18))
        )
        .accessibilityElement(children: .combine)
    }

    private func optionsGrid(
        round: WordRhymeGameModels.Round,
        interactor: WordRhymeGameInteractor
    ) -> some View {
        LazyVGrid(columns: KidGameTapScaffold<EmptyView>.twoColumnGrid, spacing: SpacingTokens.small) {
            ForEach(round.options) { option in
                optionCard(option, round: round, interactor: interactor)
            }
        }
    }

    private func optionCard(
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
        let locked: Bool = {
            if case .none = interactor.state.feedback { return false }
            return true
        }()
        let state: KidGameCardState = isCorrect ? .correct : (isWrong ? .wrong : .neutral)
        return KidGameTapCard(
            symbol: option.asset ?? "music.note",
            word: option.word,
            state: state,
            isLocked: locked,
            onTap: {
                hapticService.impact(.light)
                interactor.answer(option.id)
            }
        )
    }

    private func completionCard(state: WordRhymeGameModels.ViewState) -> some View {
        VStack(spacing: SpacingTokens.small) {
            LyalyaMascotView(state: .celebrating, size: 72)
                .accessibilityHidden(true)
            Text(String(
                format: String(localized: "wordRhyme.complete.score %lld %lld"),
                state.score, state.rounds.count
            ))
            .font(TypographyTokens.headline(18))
            .foregroundStyle(ColorTokens.Kid.ink)
            .lineLimit(nil)
            .minimumScaleFactor(0.85)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.large)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .fill(ColorTokens.Semantic.successBg)
        )
        .accessibilityElement(children: .combine)
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
