import SwiftUI

// MARK: - PalindromeHunterView

struct PalindromeHunterView: View {

    let childId: String

    @State private var interactor: PalindromeHunterInteractor?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                // Step 10 Batch C — Pattern 1: kidWarm mesh палитра (тёплый
                // hunt-вайб). softLight overlay для глубины.
                HSMeshGradientBackground(palette: .kidWarm, animated: true)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.20 : 0.32)
                    .blendMode(.softLight)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                content
            }
            .navigationTitle(Text(String(localized: "palindromeHunter.nav.title")))
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
                    interactor = PalindromeHunterInteractor(childId: childId)
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
                    if let round = interactor.state.currentRound {
                        roundCard(round, interactor: interactor)
                    } else {
                        completionCard(state: interactor.state)
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

    private func hero(state: PalindromeHunterModels.ViewState) -> some View {
        // Step 10 Batch C — Pattern 2: HSLiquidGlassCard(.elevated) — kavsoft
        // hero card поверх kidWarm mesh.
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp3) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "palindromeHunter.hero.title"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "palindromeHunter.hero.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                HSProgressBar(value: state.progress, style: .kid)
                    .frame(height: 8)
                    .padding(.top, 4)
            }
        }
    }

    private func roundCard(
        _ round: PalindromeHunterModels.Round,
        interactor: PalindromeHunterInteractor
    ) -> some View {
        HSCard(style: .elevated) {
            VStack(spacing: SpacingTokens.sp3) {
                Text("Раунд \(round.id + 1)")
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                Text("Какое слово — палиндром?")
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Kid.ink)
                VStack(spacing: SpacingTokens.sp2) {
                    ForEach(round.words, id: \.self) { word in
                        Button {
                            hapticService.impact(.light)
                            let ok = interactor.pick(word)
                            hapticService.notification(ok ? .success : .warning)
                        } label: {
                            Text(word)
                                .font(TypographyTokens.headline(17))
                                .foregroundStyle(ColorTokens.Kid.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, SpacingTokens.sp3)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(ColorTokens.Kid.surface)
                                )
                        }
                        .buttonStyle(.plain)
                        // Step 10 Batch C — Pattern 3 + 4: scrollTransition stagger
                        // + parallax drift на word-option tiles.
                        .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] content, phase in
                            content
                                .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                                .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.94))
                        }
                        .hsParallaxTile(factor: 0.25)
                    }
                }
            }
        }
    }

    private func completionCard(state: PalindromeHunterModels.ViewState) -> some View {
        HSCard(style: .tinted(ColorTokens.Semantic.successBg)) {
            VStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    // Step 10 Batch C — Pattern 5: bounce on completion seal
                    // (kid celebration when round finishes).
                    .hsSymbolEffect(.bounce, value: state.correctCount)
                Text("Завершено!")
                    .font(TypographyTokens.title(18))
                    .foregroundStyle(ColorTokens.Kid.ink)
                Text("Правильно: \(state.correctCount) из \(state.rounds.count)")
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sp3)
        }
    }

    private func cta(interactor: PalindromeHunterInteractor) -> some View {
        HSButton(
            String(localized: "palindromeHunter.cta.action"),
            style: .primary,
            size: .large,
            icon: "arrow.counterclockwise"
        ) {
            hapticService.impact(.light)
            interactor.reset()
        }
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
