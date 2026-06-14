import SwiftUI

// MARK: - PalindromeHunterView

struct PalindromeHunterView: View {

    let childId: String

    @State private var interactor: PalindromeHunterInteractor?
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
                    interactor = PalindromeHunterInteractor(
                        childId: childId,
                        sessionPersistence: container.sessionPersistenceCoordinator
                    )
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            let state = interactor.state
            KidGameTapScaffold(
                stepLabel: state.currentRound.map {
                    String(format: String(localized: "kidGame.round %lld", defaultValue: "Раунд %lld"), $0.id + 1)
                },
                progress: state.progress,
                promptText: state.currentRound != nil
                    ? String(localized: "palindromeHunter.prompt")
                    : String(localized: "palindromeHunter.complete.title"),
                mascotState: state.currentRound != nil ? .thinking : .celebrating,
                primary: KidGamePrimaryAction(
                    title: String(localized: "palindromeHunter.cta.action"),
                    icon: "arrow.counterclockwise"
                ) {
                    hapticService.impact(.light)
                    interactor.reset()
                },
                onClose: { exitGame() }
            ) {
                if let round = state.currentRound {
                    wordOptions(round, interactor: interactor)
                } else {
                    completionCard(state: state)
                }
            }
        } else {
            ProgressView().controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func wordOptions(
        _ round: PalindromeHunterModels.Round,
        interactor: PalindromeHunterInteractor
    ) -> some View {
        VStack(spacing: SpacingTokens.small) {
            ForEach(round.words, id: \.self) { word in
                Button {
                    hapticService.impact(.light)
                    let ok = interactor.pick(word)
                    hapticService.notification(ok ? .success : .warning)
                } label: {
                    Text(word)
                        .font(TypographyTokens.kidCardTitle(18))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SpacingTokens.regular)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                                .fill(ColorTokens.Kid.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                                        .strokeBorder(ColorTokens.Kid.line, lineWidth: 1.5)
                                )
                        )
                        .kidTileShadow()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(word))
                .accessibilityAddTraits(.isButton)
            }
        }
    }

    private func completionCard(state: PalindromeHunterModels.ViewState) -> some View {
        VStack(spacing: SpacingTokens.small) {
            LyalyaMascotView(state: .celebrating, size: 72)
                .accessibilityHidden(true)
            Text(String(
                format: String(localized: "palindromeHunter.complete.score %lld %lld"),
                state.correctCount, state.rounds.count
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
                .fill(ColorTokens.Brand.mint.opacity(0.16))
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#Preview("PalindromeHunter — Light") {
    PalindromeHunterView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("PalindromeHunter — Dark") {
    PalindromeHunterView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
