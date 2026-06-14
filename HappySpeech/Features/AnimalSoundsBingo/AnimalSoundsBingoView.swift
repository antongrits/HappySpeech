import SwiftUI

// MARK: - AnimalSoundsBingoView

struct AnimalSoundsBingoView: View {

    let childId: String

    @State private var interactor: AnimalSoundsBingoInteractor?
    @Environment(AppContainer.self) private var container
    @Environment(\.exitGame) private var exitGame
    @Environment(\.hapticService) private var hapticService

    private let columns = Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.tiny), count: 4)

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                content
            }
            .navigationBarHidden(true)
            .task {
                if interactor == nil {
                    let new = AnimalSoundsBingoInteractor(
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
                stepLabel: String(
                    format: String(localized: "animalBingo.hero.progress %lld %lld"),
                    state.markedCount, state.cells.count
                ),
                progress: state.cells.isEmpty ? nil
                    : Double(state.markedCount) / Double(state.cells.count),
                promptText: promptText(state),
                mascotState: state.isBingo ? .celebrating : .pointing,
                feedback: state.isBingo
                    ? KidGameFeedback(.correct, String(localized: "animalBingo.bingo"))
                    : nil,
                primary: KidGamePrimaryAction(
                    title: String(localized: "animalBingo.cta.action"),
                    icon: "speaker.wave.2.fill"
                ) {
                    hapticService.notification(.success)
                    interactor.callRandom()
                },
                onClose: { exitGame() }
            ) {
                grid(interactor: interactor)
                resetButton(interactor: interactor)
            }
        } else {
            ProgressView().controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func promptText(_ state: AnimalSoundsBingoModels.ViewState) -> String {
        if let id = state.calledOutId,
           let cell = state.cells.first(where: { $0.id == id }) {
            return String(
                format: String(localized: "animalBingo.called.question %@"),
                cell.soundDescription
            )
        }
        return String(localized: "animalBingo.hero.subtitle")
    }

    private func grid(interactor: AnimalSoundsBingoInteractor) -> some View {
        LazyVGrid(columns: columns, spacing: SpacingTokens.tiny) {
            ForEach(interactor.state.cells) { cell in
                cellTile(cell, interactor: interactor)
            }
        }
    }

    private func cellTile(
        _ cell: AnimalSoundsBingoModels.Cell,
        interactor: AnimalSoundsBingoInteractor
    ) -> some View {
        let isCalled = interactor.state.calledOutId == cell.id
        return Button {
            hapticService.impact(.light)
            interactor.toggle(cell.id)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .fill(cell.isMarked
                          ? ColorTokens.Semantic.successBg
                          : ColorTokens.Kid.surface)
                Text(cell.emoji).font(.system(size: 30))
                if cell.isMarked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(ColorTokens.Semantic.success)
                        .hsSymbolEffect(.bounce, value: cell.isMarked)
                        .padding(SpacingTokens.micro)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .strokeBorder(
                        isCalled
                            ? ColorTokens.Brand.primary
                            : (cell.isMarked ? ColorTokens.Semantic.success : ColorTokens.Kid.line),
                        lineWidth: isCalled || cell.isMarked ? 2.5 : 1
                    )
            )
            .kidTileShadow()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(cell.label))
        .accessibilityValue(Text(cell.isMarked
            ? String(localized: "animalBingo.a11y.marked")
            : String(localized: "animalBingo.a11y.unmarked")))
        .accessibilityAddTraits(.isButton)
    }

    private func resetButton(interactor: AnimalSoundsBingoInteractor) -> some View {
        Button {
            hapticService.impact(.light)
            interactor.reset()
        } label: {
            Label(String(localized: "kidGame.restart"), systemImage: "arrow.counterclockwise")
                .font(TypographyTokens.labelRounded(14, weight: .semibold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Preview

#Preview("AnimalSoundsBingo — Light") {
    AnimalSoundsBingoView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("AnimalSoundsBingo — Dark") {
    AnimalSoundsBingoView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
