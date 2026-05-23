import SwiftUI

// MARK: - PalindromeHunterView

struct PalindromeHunterView: View {

    let childId: String

    @State private var interactor: PalindromeHunterInteractor?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
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
        HSCard(style: .tinted(ColorTokens.Brand.mint.opacity(0.18))) {
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
