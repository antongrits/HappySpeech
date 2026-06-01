import SwiftUI

// MARK: - WhisperGameView

struct WhisperGameView: View {

    let childId: String

    @State private var interactor: WhisperGameInteractor?
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                // Step 10 Batch C — Pattern 1: kidCool mesh палитра (тихий
                // прохладный шёпотный вайб). softLight overlay.
                HSMeshGradientBackground(palette: .kidCool, animated: true)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.18 : 0.28)
                    .blendMode(.softLight)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                content
            }
            .navigationTitle(Text(String(localized: "whisperGame.nav.title")))
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
                    let game = WhisperGameInteractor(
                        childId: childId,
                        audioService: container.audioService
                    )
                    interactor = game
                    game.startListening()
                }
            }
            .onDisappear { interactor?.stopListening() }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            ScrollView {
                VStack(spacing: SpacingTokens.sp4) {
                    hero
                    modeSelector(interactor: interactor)
                    micMeter(interactor: interactor)
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

    private var hero: some View {
        // Step 10 Batch C — Pattern 2: HSLiquidGlassCard(.elevated) — kavsoft
        // hero card поверх kidCool mesh.
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp3) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "whisperGame.hero.title"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "whisperGame.hero.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    private func modeSelector(interactor: WhisperGameInteractor) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            ForEach(WhisperGameModels.Mode.allCases, id: \.self) { mode in
                modeChip(mode, isActive: interactor.state.mode == mode) {
                    hapticService.impact(.light)
                    interactor.setMode(mode)
                    interactor.startListening()
                }
                // Step 10 Batch C — Pattern 3 + 4: scrollTransition stagger
                // + parallax drift на mode-chip tiles (даже в HStack scroll-aware).
                .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] content, phase in
                    content
                        .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                        .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.92))
                }
                .hsParallaxTile(factor: 0.25)
            }
        }
    }

    private func modeChip(
        _ mode: WhisperGameModels.Mode,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isActive ? .white : ColorTokens.Brand.primary)
                    // Step 10 Batch C — Pattern 5: bounce on mode icon when
                    // selection changes (state-reactive feedback).
                    .hsSymbolEffect(.bounce, value: isActive)
                Text(mode.title)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(isActive ? .white : ColorTokens.Kid.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sp3)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isActive ? ColorTokens.Brand.primary : ColorTokens.Kid.surface)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(mode.title))
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }

    private func micMeter(interactor: WhisperGameInteractor) -> some View {
        let state = interactor.state
        return HSCard(style: .elevated) {
            VStack(spacing: SpacingTokens.sp3) {
                Text(String(localized: "whisperGame.meter.target"))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ColorTokens.Kid.bgDeep)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ColorTokens.Brand.primary.opacity(0.30))
                            .frame(width: geo.size.width * state.mode.targetLevel)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ColorTokens.Brand.primary)
                            .frame(width: geo.size.width * min(1, state.currentLevel))
                            .animation(.easeOut(duration: 0.3), value: state.currentLevel)
                    }
                }
                .frame(height: 22)
                .accessibilityLabel(Text(String(localized: "whisperGame.meter.a11y")))
                .accessibilityValue(Text("\(Int(state.currentLevel * 100))%"))
                if interactor.isMicAvailable {
                    HStack {
                        Text(String(
                            format: String(localized: "whisperGame.meter.match"),
                            Int(state.matchAccuracy * 100)
                        ))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        Spacer()
                        Text(String(
                            format: String(localized: "whisperGame.meter.rounds"),
                            state.roundsCompleted
                        ))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                    }
                } else {
                    // Честно: без доступа к микрофону уровень не измеряется.
                    Text(String(localized: "whisperGame.meter.noMic"))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func cta(interactor: WhisperGameInteractor) -> some View {
        HSButton(
            String(localized: "whisperGame.cta.action"),
            style: .primary,
            size: .large,
            icon: "checkmark"
        ) {
            hapticService.notification(.success)
            interactor.completeRound()
        }
    }
}

// MARK: - Preview

#Preview("WhisperGame — Light") {
    WhisperGameView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("WhisperGame — Dark") {
    WhisperGameView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
