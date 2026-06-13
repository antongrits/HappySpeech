import SwiftUI

// MARK: - ColorAndSoundView

struct ColorAndSoundView: View {

    let childId: String

    @State private var interactor: ColorAndSoundInteractor?
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
                    let new = ColorAndSoundInteractor(
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
            let state = interactor.state
            KidGameTapScaffold(
                soundLetter: state.sound,
                soundTitle: String(format: String(localized: "Звук %@"), state.sound),
                stepLabel: String(
                    format: String(localized: "colorAndSound.round %lld %lld"),
                    min(state.roundIndex + 1, state.totalRounds), state.totalRounds
                ),
                progress: state.totalRounds > 0
                    ? Double(min(state.roundIndex + 1, state.totalRounds)) / Double(state.totalRounds)
                    : nil,
                promptText: String(
                    format: String(localized: "colorAndSound.prompt %@ %@"),
                    state.sound, state.soundColor.name
                ),
                mascotState: state.isGameComplete ? .celebrating : .pointing,
                feedback: completeFeedback(state),
                primary: primaryAction(interactor: interactor),
                onClose: { exitGame() }
            ) {
                if !state.isGameComplete {
                    grid(interactor: interactor)
                }
            }
        } else {
            ProgressView().controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func completeFeedback(_ state: ColorAndSoundModels.ViewState) -> KidGameFeedback? {
        guard state.isGameComplete else { return nil }
        return KidGameFeedback(
            .correct,
            String(localized: "colorAndSound.complete") + " " +
            String(format: String(localized: "kidGame.stars %lld"), state.stars)
        )
    }

    private func primaryAction(interactor: ColorAndSoundInteractor) -> KidGamePrimaryAction? {
        let state = interactor.state
        if state.isGameComplete {
            return KidGamePrimaryAction(
                title: String(localized: "imitationLab.cta.done"),
                icon: "checkmark"
            ) { exitGame() }
        }
        if state.roundComplete {
            return KidGamePrimaryAction(
                title: String(localized: "colorAndSound.cta.next"),
                icon: "arrow.right"
            ) {
                hapticService.notification(.success)
                interactor.next()
            }
        }
        return nil
    }

    private func grid(interactor: ColorAndSoundInteractor) -> some View {
        LazyVGrid(columns: KidGameTapScaffold<EmptyView>.twoColumnGrid, spacing: SpacingTokens.small) {
            ForEach(Array(interactor.state.cards.enumerated()), id: \.element.id) { _, card in
                wordCard(card, soundColor: interactor.state.soundColor) {
                    hapticService.impact(.light)
                    interactor.toggle(card.id)
                }
            }
        }
    }

    private func wordCard(
        _ card: ColorAndSoundModels.WordCard,
        soundColor: ColorAndSoundModels.SoundColor,
        action: @escaping () -> Void
    ) -> some View {
        // После выбора: верное слово — мятная галочка (correct); неверное —
        // мягко-нейтральное (errorless: dimmed, без «красного»).
        let state: KidGameCardState = card.isSelected
            ? (card.belongs ? .correct : .dimmed)
            : .neutral
        return KidGameTapCard(
            symbol: card.asset ?? "textformat.abc",
            word: card.text,
            state: state,
            isLocked: card.isSelected,
            onTap: action
        )
        .accessibilityValue(Text(card.isSelected
            ? (card.belongs
                ? String(localized: "colorAndSound.a11y.right")
                : String(localized: "colorAndSound.a11y.wrong"))
            : String(localized: "colorAndSound.a11y.notChosen")))
    }
}

// MARK: - Preview

#Preview("ColorAndSound — Light") {
    ColorAndSoundView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("ColorAndSound — Dark") {
    ColorAndSoundView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
