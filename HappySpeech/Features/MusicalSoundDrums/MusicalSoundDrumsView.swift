import SwiftUI

// MARK: - MusicalSoundDrumsView

struct MusicalSoundDrumsView: View {

    let childId: String

    @State private var interactor: MusicalSoundDrumsInteractor?
    @Environment(AppContainer.self) private var container
    @Environment(\.exitGame) private var exitGame
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                // Step 10 Batch G — Pattern 1: kidWarm mesh палитра.
                HSMeshGradientBackground(palette: .kidWarm, animated: true)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.20 : 0.30)
                    .blendMode(.softLight)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                content
            }
            .navigationTitle(Text(String(localized: "musicalDrums.nav.title")))
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
                    let new = MusicalSoundDrumsInteractor(
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
                    rhythmCard(interactor: interactor)
                    if interactor.isGameComplete {
                        completeBanner(interactor: interactor)
                    } else if interactor.state.roundComplete {
                        roundDoneBanner(interactor: interactor)
                    } else {
                        drums(interactor: interactor)
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

    private func hero(state: MusicalSoundDrumsModels.ViewState) -> some View {
        // Step 10 Batch G — Pattern 2: HSLiquidGlassCard(.elevated) для hero.
        HSLiquidGlassCard(style: .elevated) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "musicalDrums.hero.title"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "musicalDrums.hero.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    private func rhythmCard(interactor: MusicalSoundDrumsInteractor) -> some View {
        let state = interactor.state
        return HSCard(style: .elevated) {
            VStack(spacing: SpacingTokens.sp2) {
                Text(String(localized: "musicalDrums.repeatPrompt"))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                HStack(spacing: SpacingTokens.sp2) {
                    ForEach(Array(state.pattern.enumerated()), id: \.offset) { idx, syllable in
                        let isDone = idx < state.progressIndex
                        let isNext = idx == state.progressIndex && !state.roundComplete
                        Text(syllable.text)
                            .font(TypographyTokens.title(syllable.drum == .high ? 28 : 20))
                            .foregroundStyle(isDone
                                ? ColorTokens.Semantic.success
                                : (isNext ? ColorTokens.Brand.primary : ColorTokens.Kid.inkSoft))
                            .hsSymbolEffect(.bounce, value: state.progressIndex)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(String(
                    format: String(localized: "musicalDrums.a11y.pattern %@"),
                    state.patternText
                )))
                Text(String(
                    format: String(localized: "musicalDrums.round %lld %lld"),
                    state.roundsPlayed + (interactor.isGameComplete ? 0 : 1),
                    MusicalSoundDrumsInteractor.totalRounds
                ))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
        }
    }

    private func roundDoneBanner(interactor: MusicalSoundDrumsInteractor) -> some View {
        HSCard(style: .tinted(ColorTokens.Semantic.successBg)) {
            VStack(spacing: SpacingTokens.sp2) {
                HStack(spacing: SpacingTokens.sp3) {
                    LyalyaMascotView(state: .celebrating, size: 48)
                        .accessibilityHidden(true)
                    Text(String(localized: "musicalDrums.roundDone"))
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                    Spacer()
                }
                HSButton(
                    String(localized: "musicalDrums.next"),
                    style: .primary,
                    size: .medium,
                    icon: "arrow.right.circle.fill"
                ) {
                    hapticService.impact(.light)
                    interactor.nextRound()
                }
            }
        }
    }

    private func completeBanner(interactor: MusicalSoundDrumsInteractor) -> some View {
        HSCard(style: .tinted(ColorTokens.Semantic.successBg)) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .celebrating, size: 56)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "musicalDrums.gameDone"))
                        .font(TypographyTokens.headline(16))
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
    }

    private func drums(interactor: MusicalSoundDrumsInteractor) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            ForEach(MusicalSoundDrumsModels.DrumId.allCases, id: \.self) { drum in
                drumButton(drum, isActive: interactor.state.lastDrumId == drum) {
                    hapticService.impact(.medium)
                    interactor.tap(drum)
                }
                // Step 10 Batch G — Pattern 3: scrollTransition stagger.
                .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] content, phase in
                    content
                        .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                        .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.9))
                }
                // Step 10 Batch G — Pattern 4: parallax drift на drum tiles.
                .hsParallaxTile(factor: 0.25)
            }
        }
    }

    private func drumButton(
        _ drum: MusicalSoundDrumsModels.DrumId,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: drum.icon)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(isActive ? ColorTokens.Overlay.onAccent : ColorTokens.Brand.primary)
                Text(drum.label)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(isActive ? ColorTokens.Overlay.onAccent : ColorTokens.Kid.ink)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isActive ? ColorTokens.Brand.primary : ColorTokens.Kid.surface)
            )
            .scaleEffect(isActive ? 0.97 : 1.0)
            .animation(.spring(duration: 0.2), value: isActive)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(String(
            format: String(localized: "musicalDrums.a11y.drum %@"),
            drum.label
        )))
        .accessibilityAddTraits(.isButton)
    }

    private func cta(interactor: MusicalSoundDrumsInteractor) -> some View {
        HSButton(
            String(localized: "musicalDrums.cta.action"),
            style: .primary,
            size: .large,
            icon: "arrow.counterclockwise"
        ) {
            hapticService.notification(.success)
            interactor.reset()
        }
    }
}

// MARK: - Preview

#Preview("MusicalSoundDrums — Light") {
    MusicalSoundDrumsView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("MusicalSoundDrums — Dark") {
    MusicalSoundDrumsView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
