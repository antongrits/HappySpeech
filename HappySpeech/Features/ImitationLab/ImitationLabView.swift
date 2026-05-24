import SwiftUI

// MARK: - ImitationLabView

struct ImitationLabView: View {

    let childId: String

    @State private var interactor: ImitationLabInteractor?
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
                    interactor = ImitationLabInteractor(childId: childId)
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            ScrollView {
                VStack(spacing: SpacingTokens.sp4) {
                    hero
                    grid(interactor: interactor)
                    cta
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
                .padding(.bottom, SpacingTokens.sp6)
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    private var hero: some View {
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
            }
        }
    }

    private func grid(interactor: ImitationLabInteractor) -> some View {
        LazyVGrid(columns: columns, spacing: SpacingTokens.sp2) {
            ForEach(interactor.state.samples) { sample in
                sampleCard(sample, isActive: sample.id == interactor.state.currentSampleId) {
                    hapticService.impact(.light)
                    interactor.playSample(sample.id)
                }
                // Step 10 Batch G — Pattern 3: scrollTransition stagger.
                .scrollTransition(.animated.threshold(.visible(0.3))) { content, phase in
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
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HSCard(style: isActive ? .tinted(ColorTokens.Brand.mint.opacity(0.22)) : .elevated) {
                VStack(spacing: 6) {
                    Text(sample.emoji)
                        .font(.system(size: 40))
                    Text(sample.name)
                        .font(TypographyTokens.headline(15))
                        .foregroundStyle(ColorTokens.Kid.ink)
                    Text(sample.onomatopoeia)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Brand.primary)
                    if sample.isPlayed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(ColorTokens.Brand.primary)
                            // Step 10 Batch G — Pattern 5: bounce on played check.
                            .hsSymbolEffect(.bounce, value: sample.isPlayed)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, SpacingTokens.sp2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(sample.name), \(sample.onomatopoeia)"))
        .accessibilityAddTraits(.isButton)
    }

    private var cta: some View {
        HSButton(
            String(localized: "imitationLab.cta.action"),
            style: .primary,
            size: .large,
            icon: "mic.fill"
        ) {
            hapticService.notification(.success)
            dismiss()
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
