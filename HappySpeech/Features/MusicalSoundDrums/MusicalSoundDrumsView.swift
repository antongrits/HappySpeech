import SwiftUI

// MARK: - MusicalSoundDrumsView

struct MusicalSoundDrumsView: View {

    let childId: String

    @State private var interactor: MusicalSoundDrumsInteractor?
    @Environment(\.dismiss) private var dismiss
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
                    interactor = MusicalSoundDrumsInteractor(childId: childId)
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
                    hero(state: interactor.state)
                    rhythmCard(state: interactor.state)
                    drums(interactor: interactor)
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

    private func rhythmCard(state: MusicalSoundDrumsModels.ViewState) -> some View {
        HSCard(style: .elevated) {
            VStack(spacing: SpacingTokens.sp2) {
                Text(state.targetPhoneme)
                    .font(TypographyTokens.title(28))
                    .foregroundStyle(ColorTokens.Brand.primary)
                HStack(spacing: SpacingTokens.sp2) {
                    ForEach(Array(state.rhythmPattern.enumerated()), id: \.offset) { _, drum in
                        Image(systemName: drum.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                            // Step 10 Batch G — Pattern 5: pulse on rhythm pattern.
                            .hsSymbolEffect(.pulse, value: state.beatsCount)
                    }
                }
                Text("Ударов: \(state.beatsCount)")
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
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
                .scrollTransition(.animated.threshold(.visible(0.3))) { content, phase in
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
                    .foregroundStyle(isActive ? .white : ColorTokens.Brand.primary)
                Text(drum.label)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(isActive ? .white : ColorTokens.Kid.ink)
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
        .accessibilityLabel(Text("Барабан \(drum.label)"))
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
