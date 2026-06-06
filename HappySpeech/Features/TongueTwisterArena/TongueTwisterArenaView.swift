import SwiftUI

// MARK: - TongueTwisterArenaView

struct TongueTwisterArenaView: View {

    let childId: String

    @State private var interactor: TongueTwisterArenaInteractor?
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
                // performance-вайб скороговорки).
                HSMeshGradientBackground(palette: .kidWarm, animated: true)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.20 : 0.32)
                    .blendMode(.softLight)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                content
            }
            .navigationTitle(Text(String(localized: "tongueTwister.nav.title")))
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
                    let arena = TongueTwisterArenaInteractor(
                        childId: childId,
                        audioService: container.audioService,
                        asrService: container.asrService,
                        adaptivePlanner: container.adaptivePlannerService,
                        childRepository: container.childRepository
                    )
                    interactor = arena
                    await arena.load()
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            if let selected = interactor.state.selected {
                ScrollView {
                    VStack(spacing: SpacingTokens.sp4) {
                        detail(twister: selected, interactor: interactor)
                        if case .result(let stars, _) = interactor.state.phase {
                            resultCard(stars: stars)
                        }
                        recordCTA(interactor: interactor)
                        backCTA(interactor: interactor)
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.top, SpacingTokens.sp3)
                    .padding(.bottom, SpacingTokens.sp6)
                }
            } else {
                ScrollView {
                    VStack(spacing: SpacingTokens.sp4) {
                        hero
                        list(interactor: interactor)
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

    private var hero: some View {
        // Step 10 Batch C — Pattern 2: HSLiquidGlassCard(.elevated) — kavsoft
        // hero card поверх kidWarm mesh.
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp3) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .singing, size: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "tongueTwister.hero.title"))
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "tongueTwister.hero.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func list(interactor: TongueTwisterArenaInteractor) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            ForEach(interactor.state.twisters) { twister in
                Button {
                    hapticService.impact(.light)
                    interactor.select(twister)
                } label: {
                    HSCard(style: .elevated) {
                        HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                            Text(twister.targetSound)
                                .font(TypographyTokens.headline(16).weight(.bold))
                                .foregroundStyle(ColorTokens.Brand.primary)
                                .frame(width: 44, alignment: .leading)
                            Text(twister.text)
                                .font(TypographyTokens.body(14))
                                .foregroundStyle(ColorTokens.Kid.ink)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ColorTokens.Kid.inkSoft)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(String(
                    format: String(localized: "tongueTwister.row.a11y %@ %@"),
                    twister.targetSound, twister.text
                )))
                .accessibilityAddTraits(.isButton)
                // Step 10 Batch C — Pattern 3 + 4: scrollTransition stagger
                // + parallax drift на twister list rows.
                .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] content, phase in
                    content
                        .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                        .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.94))
                }
                .hsParallaxTile(factor: 0.25)
            }
        }
    }

    private func detail(
        twister: TongueTwisterArenaModels.Twister,
        interactor: TongueTwisterArenaInteractor
    ) -> some View {
        HSCard(style: .tinted(ColorTokens.Brand.butter.opacity(0.18))) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                Text(twister.targetSound)
                    .font(TypographyTokens.headline(16).weight(.bold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                Text(twister.text)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
            }
        }
    }

    private func resultCard(stars: Int) -> some View {
        HSCard(style: .tinted(ColorTokens.Semantic.successBg)) {
            VStack(spacing: SpacingTokens.sp2) {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: index < stars ? "star.fill" : "star")
                            .font(.system(size: 28))
                            .foregroundStyle(ColorTokens.Brand.gold)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(String(
                    format: String(localized: "tongueTwister.result.a11y %lld"),
                    stars
                )))
                Text(String(localized: "tongueTwister.result.caption"))
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func recordCTA(interactor: TongueTwisterArenaInteractor) -> some View {
        if interactor.canRecord {
            HSButton(
                recordTitle(phase: interactor.state.phase),
                style: interactor.state.isRecording ? .danger : .primary,
                size: .large,
                icon: recordIcon(phase: interactor.state.phase)
            ) {
                hapticService.notification(.success)
                interactor.toggleRecord()
            }
            .disabled(interactor.state.isScoring)
        }
    }

    private func recordTitle(phase: TongueTwisterArenaModels.AttemptPhase) -> String {
        switch phase {
        case .recording: return String(localized: "tongueTwister.cta.stop")
        case .scoring:   return String(localized: "tongueTwister.cta.scoring")
        case .result:    return String(localized: "tongueTwister.cta.again")
        case .idle:      return String(localized: "tongueTwister.cta.action")
        }
    }

    private func recordIcon(phase: TongueTwisterArenaModels.AttemptPhase) -> String {
        switch phase {
        case .recording: return "stop.circle.fill"
        case .scoring:   return "hourglass"
        default:         return "mic.fill"
        }
    }

    private func backCTA(interactor: TongueTwisterArenaInteractor) -> some View {
        HSButton(
            String(localized: "tongueTwister.cta.back"),
            style: .ghost,
            size: .medium,
            icon: "arrow.left"
        ) {
            hapticService.impact(.light)
            interactor.back()
        }
    }
}

// MARK: - Preview

#Preview("TongueTwisterArena — Light") {
    TongueTwisterArenaView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("TongueTwisterArena — Dark") {
    TongueTwisterArenaView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
