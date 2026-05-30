import SwiftUI

// MARK: - AudioMemoryGameView

struct AudioMemoryGameView: View {

    let childId: String

    @State private var interactor: AudioMemoryGameInteractor?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private let columns = Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sp2), count: 4)

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()

                // Step 10 Batch A — Pattern 1: mesh .kidWarm палитра — тёплая «игровая» атмосфера.
                HSMeshGradientBackground(palette: .kidWarm, animated: true)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.28 : 0.50)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)

                content
            }
            .navigationTitle(Text(String(localized: "audioMemory.nav.title")))
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
                    interactor = AudioMemoryGameInteractor(childId: childId)
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            ScrollView {
                VStack(spacing: SpacingTokens.sp3) {
                    hero(interactor: interactor)
                    grid(interactor: interactor)
                    if interactor.isComplete {
                        completeBanner
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

    private func hero(interactor: AudioMemoryGameInteractor) -> some View {
        // Step 10 Batch A — Pattern 2: hero обёрнут в HSLiquidGlassCard.elevated.
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.regular) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .pointing, size: 56)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "audioMemory.hero.title"))
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "audioMemory.hero.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                    Text("Ходы: \(interactor.moves)   Пары: \(interactor.matchedCount)/\(AudioMemoryGameModels.pairKeys.count)")
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkSoft)
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func grid(interactor: AudioMemoryGameInteractor) -> some View {
        // Step 10 Batch A — Pattern 3: stagger fade+scale entrance.
        LazyVGrid(columns: columns, spacing: SpacingTokens.sp2) {
            ForEach(Array(interactor.tiles.enumerated()), id: \.element.id) { idx, tile in
                tileButton(tile, index: idx, interactor: interactor)
                    .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] content, phase in
                        content
                            .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                            .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.90))
                    }
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
                        .font(TypographyTokens.titleLarge(30).weight(.bold))
                        .foregroundStyle(ColorTokens.Kid.ink)
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
                                 ? "Звук \(tile.pairKey)" : "Закрытая карточка"))
        .accessibilityAddTraits(.isButton)
    }

    private func tileBackground(_ tile: AudioMemoryGameModels.Tile) -> Color {
        if tile.isMatched { return ColorTokens.Semantic.successBg }
        if tile.isFlipped { return ColorTokens.Kid.surface }
        return ColorTokens.Brand.primary
    }

    private var completeBanner: some View {
        HSCard(style: .tinted(ColorTokens.Semantic.successBg)) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .celebrating, size: 56)
                    .accessibilityHidden(true)
                Text("Все пары собраны!")
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Kid.ink)
                Spacer()
            }
        }
    }

    private func cta(interactor: AudioMemoryGameInteractor) -> some View {
        HSButton(
            interactor.isComplete
                ? String(localized: "audioMemory.cta.start")
                : "Перемешать заново",
            style: interactor.isComplete ? .primary : .secondary,
            size: .large,
            icon: "shuffle"
        ) {
            hapticService.notification(.success)
            interactor.restart()
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
