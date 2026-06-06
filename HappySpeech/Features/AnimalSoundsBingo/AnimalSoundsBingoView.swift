import SwiftUI

// MARK: - AnimalSoundsBingoView

struct AnimalSoundsBingoView: View {

    let childId: String

    @State private var interactor: AnimalSoundsBingoInteractor?
    @Environment(AppContainer.self) private var container
    @Environment(\.exitGame) private var exitGame
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private let columns = Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sp2), count: 4)

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                // Step 10 Batch C — Pattern 1: kidWarm mesh палитра поверх
                // плоского cream baseline создаёт «дышащий» kid-фон.
                HSMeshGradientBackground(palette: .kidWarm, animated: true)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.20 : 0.32)
                    .blendMode(.softLight)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                content
            }
            .navigationTitle(Text(String(localized: "animalBingo.nav.title")))
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
            ScrollView {
                VStack(spacing: SpacingTokens.sp4) {
                    hero(state: interactor.state)
                    calledOutCard(interactor: interactor)
                    grid(interactor: interactor)
                    if interactor.state.isBingo {
                        bingoBanner
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

    private func hero(state: AnimalSoundsBingoModels.ViewState) -> some View {
        // Step 10 Batch C — Pattern 2: HSLiquidGlassCard(.elevated) для hero.
        // ultraThickMaterial + butter tint поверх mesh — kavsoft-style.
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp3) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .pointing, size: 56)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "animalBingo.hero.title"))
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "animalBingo.hero.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                    Text(String(
                        format: String(localized: "animalBingo.hero.progress %lld %lld"),
                        state.markedCount, state.cells.count
                    ))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkSoft)
                        .padding(.top, 2)
                    if state.bestStars > 0 {
                        Text(String(
                            format: String(localized: "kidGame.bestStars %lld"),
                            state.bestStars
                        ))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Semantic.warning)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func calledOutCard(interactor: AnimalSoundsBingoInteractor) -> some View {
        if let id = interactor.state.calledOutId,
           let cell = interactor.state.cells.first(where: { $0.id == id }) {
            HSCard(style: .tinted(ColorTokens.Brand.sky.opacity(0.18))) {
                HStack(spacing: SpacingTokens.sp3) {
                    Text(cell.emoji).font(.system(size: 36))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(
                            format: String(localized: "animalBingo.called.question %@"),
                            cell.soundDescription
                        ))
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Kid.ink)
                        Text(String(localized: "animalBingo.called.hint"))
                            .font(TypographyTokens.body(13))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                    }
                    Spacer()
                }
            }
        }
    }

    private func grid(interactor: AnimalSoundsBingoInteractor) -> some View {
        LazyVGrid(columns: columns, spacing: SpacingTokens.sp2) {
            ForEach(interactor.state.cells) { cell in
                cellTile(cell, interactor: interactor)
                    // Step 10 Batch C — Pattern 3: scrollTransition stagger
                    // fade+scale на bingo cells, gated by reduceMotion.
                    .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] content, phase in
                        content
                            .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                            .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.9))
                    }
                    // Step 10 Batch C — Pattern 4: parallax drift на bingo tiles.
                    .hsParallaxTile(factor: 0.25)
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
                RoundedRectangle(cornerRadius: 14)
                    .fill(cell.isMarked
                          ? ColorTokens.Semantic.successBg
                          : ColorTokens.Kid.surface)
                Text(cell.emoji).font(.system(size: 30))
                if cell.isMarked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(ColorTokens.Semantic.success)
                        // Step 10 Batch C — Pattern 5: bounce on checkmark
                        // when cell flips to marked (state-reactive).
                        .hsSymbolEffect(.bounce, value: cell.isMarked)
                        .padding(4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isCalled ? ColorTokens.Brand.primary : Color.clear, lineWidth: 2.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(cell.label))
        .accessibilityValue(Text(cell.isMarked
            ? String(localized: "animalBingo.a11y.marked")
            : String(localized: "animalBingo.a11y.unmarked")))
        .accessibilityAddTraits(.isButton)
    }

    private var bingoBanner: some View {
        HSCard(style: .tinted(ColorTokens.Semantic.successBg)) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .celebrating, size: 48)
                    .accessibilityHidden(true)
                Text(String(localized: "animalBingo.bingo"))
                    .font(TypographyTokens.titleLarge(26).weight(.bold))
                    .foregroundStyle(ColorTokens.Kid.ink)
                Spacer()
            }
        }
    }

    private func cta(interactor: AnimalSoundsBingoInteractor) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            HSButton(
                String(localized: "animalBingo.cta.action"),
                style: .primary,
                size: .large,
                icon: "play.circle.fill"
            ) {
                hapticService.notification(.success)
                interactor.callRandom()
            }
            HSButton(
                String(localized: "kidGame.restart"),
                style: .ghost,
                size: .medium,
                icon: "arrow.counterclockwise"
            ) {
                hapticService.impact(.light)
                interactor.reset()
            }
        }
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
