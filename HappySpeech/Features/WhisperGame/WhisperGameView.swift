import SwiftUI

// MARK: - WhisperGameView

struct WhisperGameView: View {

    let childId: String

    @State private var interactor: WhisperGameInteractor?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
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
                    interactor = WhisperGameInteractor(childId: childId)
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
                    modeSelector(interactor: interactor)
                    micMeter(state: interactor.state)
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
        HSCard(style: .tinted(ColorTokens.Brand.mint.opacity(0.18))) {
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
            VStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isActive ? .white : ColorTokens.Brand.primary)
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

    private func micMeter(state: WhisperGameModels.ViewState) -> some View {
        HSCard(style: .elevated) {
            VStack(spacing: SpacingTokens.sp3) {
                Text("Целевой уровень")
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
                HStack {
                    Text("Совпадение: \(Int(state.matchAccuracy * 100))%")
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.ink)
                    Spacer()
                    Text("Раундов: \(state.roundsCompleted)")
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
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
