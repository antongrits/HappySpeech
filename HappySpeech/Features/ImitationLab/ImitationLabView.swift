import SwiftUI

// MARK: - ImitationLabView

struct ImitationLabView: View {

    let childId: String

    @State private var interactor: ImitationLabInteractor?
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [
        GridItem(.flexible(), spacing: SpacingTokens.sp2),
        GridItem(.flexible(), spacing: SpacingTokens.sp2)
    ]

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
            .navigationTitle(Text(String(localized: "imitationLab.nav.title")))
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
                    let new = ImitationLabInteractor(
                        childId: childId,
                        childRepository: container.childRepository,
                        adaptivePlanner: container.adaptivePlannerService,
                        audioService: container.audioService,
                        scorer: container.pronunciationService
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
                    hero(interactor: interactor)
                    grid(interactor: interactor)
                    if interactor.state.isComplete {
                        completeBanner(interactor: interactor)
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

    private func hero(interactor: ImitationLabInteractor) -> some View {
        // Step 10 Batch G — Pattern 2: HSLiquidGlassCard(.elevated) для hero.
        HSLiquidGlassCard(style: .elevated) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "imitationLab.hero.title"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "imitationLab.hero.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                Text(String(
                    format: String(localized: "imitationLab.hero.progress %lld %lld"),
                    interactor.state.practicedCount, interactor.state.samples.count
                ))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                    .padding(.top, 2)
            }
        }
    }

    private func grid(interactor: ImitationLabInteractor) -> some View {
        LazyVGrid(columns: columns, spacing: SpacingTokens.sp2) {
            ForEach(interactor.state.samples) { sample in
                sampleCard(
                    sample,
                    isActive: sample.id == interactor.state.currentSampleId,
                    isRecording: sample.id == interactor.recordingSampleId,
                    onPlay: {
                        hapticService.impact(.light)
                        interactor.playSample(sample.id)
                    },
                    onPracticed: {
                        hapticService.impact(.medium)
                        interactor.practice(sample.id)
                    }
                )
                // Step 10 Batch G — Pattern 3: scrollTransition stagger.
                .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] content, phase in
                    content
                        .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                        .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.9))
                }
                // Step 10 Batch G — Pattern 4: parallax drift на sample cards.
                .hsParallaxTile(factor: 0.25)
            }
        }
    }

    private func sampleCard(
        _ sample: ImitationLabModels.SoundSample,
        isActive: Bool,
        isRecording: Bool,
        onPlay: @escaping () -> Void,
        onPracticed: @escaping () -> Void
    ) -> some View {
        HSCard(style: isActive
            ? .tinted(ColorTokens.Brand.sky.opacity(0.22))
            : (sample.isPracticed
                ? .tinted(sample.didPass ? ColorTokens.Semantic.successBg : ColorTokens.Kid.surface)
                : .elevated)) {
            VStack(spacing: 6) {
                Text(sample.emoji)
                    .font(.system(size: 40))
                Text(sample.name)
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Kid.ink)
                Text(sample.onomatopoeia)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Brand.primary)
                if isRecording {
                    Label(
                        String(localized: "imitationLab.listening"),
                        systemImage: "mic.fill"
                    )
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .hsSymbolEffect(.pulse, value: isRecording)
                } else if sample.isPracticed {
                    Label(
                        sample.didPass
                            ? String(localized: "imitationLab.done")
                            : String(localized: "imitationLab.almost"),
                        systemImage: sample.didPass ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill"
                    )
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(sample.didPass ? ColorTokens.Semantic.success : ColorTokens.Brand.sky)
                    .hsSymbolEffect(.bounce, value: sample.isPracticed)
                } else {
                    HStack(spacing: SpacingTokens.sp1) {
                        Button(action: onPlay) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(ColorTokens.Brand.primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(String(localized: "imitationLab.a11y.play")))
                        Button(action: onPracticed) {
                            Image(systemName: "mic.circle")
                                .font(.system(size: 26))
                                .foregroundStyle(sample.isPlayed
                                    ? ColorTokens.Brand.primary
                                    : ColorTokens.Kid.inkSoft)
                        }
                        .buttonStyle(.plain)
                        .disabled(!sample.isPlayed)
                        .accessibilityLabel(Text(String(localized: "imitationLab.a11y.repeat")))
                    }
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sp2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("\(sample.name), \(sample.onomatopoeia)"))
    }

    private func completeBanner(interactor: ImitationLabInteractor) -> some View {
        HSCard(style: .tinted(ColorTokens.Semantic.successBg)) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .celebrating, size: 56)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "imitationLab.complete"))
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

    private func cta(interactor: ImitationLabInteractor) -> some View {
        HSButton(
            interactor.state.isComplete
                ? String(localized: "imitationLab.cta.done")
                : String(localized: "kidGame.restart"),
            style: interactor.state.isComplete ? .primary : .ghost,
            size: .large,
            icon: interactor.state.isComplete ? "checkmark" : "arrow.counterclockwise"
        ) {
            if interactor.state.isComplete {
                hapticService.notification(.success)
                dismiss()
            } else {
                hapticService.impact(.light)
                interactor.reset()
            }
        }
    }
}

// MARK: - Preview

#Preview("ImitationLab — Light") {
    ImitationLabView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("ImitationLab — Dark") {
    ImitationLabView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
