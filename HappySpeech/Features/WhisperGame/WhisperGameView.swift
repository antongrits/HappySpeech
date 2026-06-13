import SwiftUI

// MARK: - WhisperGameView

struct WhisperGameView: View {

    let childId: String

    @State private var interactor: WhisperGameInteractor?
    @Environment(AppContainer.self) private var container
    @Environment(\.exitGame) private var exitGame
    @Environment(\.hapticService) private var hapticService

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                content
            }
            .navigationBarHidden(true)
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
            KidGameTapScaffold(
                promptText: String(localized: "whisperGame.hero.subtitle"),
                mascotState: .thinking,
                primary: KidGamePrimaryAction(
                    title: String(localized: "whisperGame.cta.action"),
                    icon: "checkmark"
                ) {
                    hapticService.notification(.success)
                    interactor.completeRound()
                },
                onClose: { exitGame() }
            ) {
                modeSelector(interactor: interactor)
                micMeter(interactor: interactor)
            }
        } else {
            ProgressView().controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func modeSelector(interactor: WhisperGameInteractor) -> some View {
        HStack(spacing: SpacingTokens.tiny) {
            ForEach(WhisperGameModels.Mode.allCases, id: \.self) { mode in
                modeChip(mode, isActive: interactor.state.mode == mode) {
                    hapticService.impact(.light)
                    interactor.setMode(mode)
                    interactor.startListening()
                }
            }
        }
    }

    private func modeChip(
        _ mode: WhisperGameModels.Mode,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: SpacingTokens.micro) {
                Image(systemName: mode.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isActive ? ColorTokens.Overlay.onAccent : ColorTokens.Brand.primary)
                    .hsSymbolEffect(.bounce, value: isActive)
                Text(mode.title)
                    .font(TypographyTokens.labelRounded(12, weight: .semibold))
                    .foregroundStyle(isActive ? ColorTokens.Overlay.onAccent : ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.small)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .fill(isActive ? ColorTokens.Brand.primary : ColorTokens.Kid.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                            .strokeBorder(isActive ? Color.clear : ColorTokens.Kid.line, lineWidth: 1)
                    )
            )
            .kidTileShadow()
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
                        // Показывать совпадение только после первой попытки —
                        // до записи «совпадение» не имеет смысла.
                        if state.roundsCompleted > 0 {
                            Text(String(
                                format: String(localized: "whisperGame.meter.match"),
                                Int(state.matchAccuracy * 100)
                            ))
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Kid.ink)
                        } else {
                            Text(String(localized: "whisperGame.meter.matchIdle"))
                                .font(TypographyTokens.caption(12))
                                .foregroundStyle(ColorTokens.Kid.inkMuted)
                        }
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
