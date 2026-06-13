import SwiftUI

// MARK: - SpeechRiddlesView

struct SpeechRiddlesView: View {

    let childId: String

    @State private var interactor: SpeechRiddlesInteractor?
    @Environment(AppContainer.self) private var container
    @Environment(\.exitGame) private var exitGame
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.small), count: 2)

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                content
            }
            .navigationBarHidden(true)
            .task {
                if interactor == nil {
                    let game = SpeechRiddlesInteractor(
                        childId: childId,
                        worker: SpeechRiddlesWorker(childRepository: container.childRepository),
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
                    soundLetter: state.current?.targetLetter,
                    soundTitle: state.current.map {
                        String(format: String(localized: "Звук %@"), $0.targetLetter)
                    },
                    progress: state.progress,
                    promptText: state.current?.prompt
                        ?? String(localized: "speechRiddles.complete.title"),
                    mascotState: state.current != nil ? .thinking : .celebrating,
                    feedback: currentFeedback(state),
                    primary: primaryAction(interactor: interactor),
                    onClose: { exitGame() }
                ) {
                    if let current = state.current {
                        options(riddle: current, interactor: interactor)
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
            Text(String(localized: "speechRiddles.empty.title"))
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(SpacingTokens.screenEdge)
    }

    private func currentFeedback(_ state: SpeechRiddlesModels.ViewState) -> KidGameFeedback? {
        switch state.feedback {
        case .correct:
            return KidGameFeedback(.correct, String(localized: "speechRiddles.hero.subtitle"))
        case .wrong:
            return KidGameFeedback(.incorrect, String(localized: "speechRiddles.hero.subtitle"))
        default:
            return nil
        }
    }

    private func primaryAction(interactor: SpeechRiddlesInteractor) -> KidGamePrimaryAction? {
        let state = interactor.state
        if state.isComplete {
            return KidGamePrimaryAction(
                title: String(localized: "speechRiddles.cta.again"),
                icon: "arrow.counterclockwise"
            ) {
                hapticService.notification(.success)
                Task { await interactor.load() }
            }
        }
        if case .wrong = state.feedback {
            return KidGamePrimaryAction(
                title: String(localized: "speechRiddles.cta.action"),
                icon: "arrow.right"
            ) {
                hapticService.notification(.success)
                interactor.advance()
            }
        }
        return nil
    }

    private func options(
        riddle: SpeechRiddlesModels.Riddle,
        interactor: SpeechRiddlesInteractor
    ) -> some View {
        LazyVGrid(columns: columns, spacing: SpacingTokens.small) {
            ForEach(riddle.options) { option in
                optionTile(option, riddle: riddle, interactor: interactor)
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
        let locked: Bool = {
            if case .none = interactor.state.feedback { return false }
            return true
        }()
        let cardState: KidGameCardState =
            isCorrectFeedback ? .correct : (isWrongFeedback ? .wrong : .neutral)

        return KidGameTapCard(
            symbol: option.asset ?? "questionmark.circle",
            word: option.label,
            state: cardState,
            isLocked: locked,
            onTap: {
                hapticService.impact(.light)
                interactor.answer(option.id)
            }
        )
    }

    private func completionCard(state: SpeechRiddlesModels.ViewState) -> some View {
        VStack(spacing: SpacingTokens.small) {
            LyalyaMascotView(state: .celebrating, size: 72)
                .accessibilityHidden(true)
            Text(String(
                format: String(localized: "speechRiddles.complete.score %lld %lld"),
                state.score, state.riddles.count
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
