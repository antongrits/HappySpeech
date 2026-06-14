import SwiftUI

// MARK: - AudioMemoryGameView

struct AudioMemoryGameView: View {

    let childId: String

    @State private var interactor: AudioMemoryGameInteractor?
    @Environment(AppContainer.self) private var container
    @Environment(\.exitGame) private var exitGame
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sp2), count: 4)

    var body: some View {
        Group {
            if let interactor, interactor.isLoaded {
                KidGameCanvasScaffold(
                    title: Text(String(localized: "audioMemory.hero.title")),
                    subtitle: memorySubtitle(interactor: interactor),
                    progress: interactor.pairCount > 0
                        ? Double(interactor.matchedCount) / Double(interactor.pairCount)
                        : 0,
                    palette: .kidWarm,
                    onExit: { exitGame() }
                ) {
                    canvasContent(interactor: interactor)
                } toolbar: {
                    KidGameCTAButton(
                        title: interactor.isComplete
                            ? String(localized: "audioMemory.cta.start")
                            : String(localized: "audioMemory.cta.shuffle"),
                        systemImage: "shuffle"
                    ) {
                        hapticService.notification(.success)
                        interactor.restart()
                    }
                }
            } else {
                ZStack {
                    KidGameCanvasBackground(palette: .kidWarm)
                    ProgressView().controlSize(.large)
                }
            }
        }
        .task {
            if interactor == nil {
                let new = AudioMemoryGameInteractor(
                    childId: childId,
                    childRepository: container.childRepository,
                    adaptivePlanner: container.adaptivePlannerService
                )
                interactor = new
                await new.load()
            }
        }
        .environment(\.circuitContext, .kid)
    }

    private func memorySubtitle(interactor: AudioMemoryGameInteractor) -> String {
        String(
            format: String(localized: "audioMemory.hero.progress %lld %lld %lld"),
            interactor.moves, interactor.matchedCount, interactor.pairCount
        )
    }

    // MARK: - Canvas content (внутри холста)

    private func canvasContent(interactor: AudioMemoryGameInteractor) -> some View {
        VStack(spacing: SpacingTokens.small) {
            grid(interactor: interactor)

            Spacer(minLength: 0)

            if interactor.isComplete {
                completeBanner
            } else {
                HStack(alignment: .bottom) {
                    KidGameMascotBubble(
                        message: String(localized: "audioMemory.hero.subtitle"),
                        state: .pointing,
                        size: 48
                    )
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(SpacingTokens.small)
    }

    private func grid(interactor: AudioMemoryGameInteractor) -> some View {
        LazyVGrid(columns: columns, spacing: SpacingTokens.sp2) {
            ForEach(Array(interactor.tiles.enumerated()), id: \.element.id) { idx, tile in
                tileButton(tile, index: idx, interactor: interactor)
            }
        }
        .animation(reduceMotion ? nil : MotionTokens.settleSpring, value: interactor.tiles.count)
    }

    private func tileButton(
        _ tile: AudioMemoryGameModels.Tile,
        index: Int,
        interactor: AudioMemoryGameInteractor
    ) -> some View {
        Button {
            hapticService.impact(.light)
            interactor.tap(at: index)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(tileBackground(tile))
                if tile.isFlipped || tile.isMatched {
                    Text(tile.pairKey)
                        .font(TypographyTokens.headline(16).weight(.bold))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.6)
                        .multilineTextAlignment(.center)
                        .padding(2)
                } else {
                    // Pattern 5: pulse при изменении состояния карточки.
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .hsSymbolEffect(.pulse, value: tile.isFlipped)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 72)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(tile.isFlipped || tile.isMatched
            ? tile.pairKey
            : String(localized: "audioMemory.a11y.closed")))
        .accessibilityAddTraits(.isButton)
    }

    private func tileBackground(_ tile: AudioMemoryGameModels.Tile) -> Color {
        // Совпавшая пара — мягкий мятный акцент в одном семействе с холст-играми
        // (SoundHunter / ObjectHunt), а не сплошная зелёная заливка.
        if tile.isMatched { return ColorTokens.Feedback.correct.opacity(0.18) }
        if tile.isFlipped { return ColorTokens.Kid.surface }
        return ColorTokens.Brand.primary
    }

    private var completeBanner: some View {
        HSCard(style: .tinted(ColorTokens.Brand.mint.opacity(0.12))) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .celebrating, size: 56)
                    .accessibilityHidden(true)
                Text(String(localized: "audioMemory.complete"))
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Preview

#Preview("AudioMemoryGame — Light") {
    AudioMemoryGameView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("AudioMemoryGame — Dark") {
    AudioMemoryGameView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
