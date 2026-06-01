import SwiftUI

// MARK: - ColorAndSoundView

struct ColorAndSoundView: View {

    let childId: String

    @State private var interactor: ColorAndSoundInteractor?
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = [
        GridItem(.flexible(), spacing: SpacingTokens.sp2),
        GridItem(.flexible(), spacing: SpacingTokens.sp2)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                HSMeshGradientBackground(palette: .kidCool, animated: !reduceMotion)
                    .ignoresSafeArea()
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                content
            }
            .navigationTitle(Text(String(localized: "colorAndSound.nav.title")))
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
                    let new = ColorAndSoundInteractor(
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
                    hero(interactor: interactor)
                    if interactor.state.isGameComplete {
                        completeBanner(interactor: interactor)
                    } else {
                        grid(interactor: interactor)
                        if interactor.state.roundComplete {
                            nextButton(interactor: interactor)
                        }
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
                .padding(.bottom, SpacingTokens.sp6)
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    private func hero(interactor: ColorAndSoundInteractor) -> some View {
        let state = interactor.state
        return HSLiquidGlassCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                Circle()
                    .fill(state.soundColor.color)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Text(state.sound)
                            .font(TypographyTokens.title(26).weight(.bold))
                            .foregroundStyle(ColorTokens.Overlay.onAccent)
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(
                        format: String(localized: "colorAndSound.prompt %@ %@"),
                        state.sound, state.soundColor.name
                    ))
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                    Text(String(
                        format: String(localized: "colorAndSound.round %lld %lld"),
                        min(state.roundIndex + 1, state.totalRounds), state.totalRounds
                    ))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func grid(interactor: ColorAndSoundInteractor) -> some View {
        LazyVGrid(columns: columns, spacing: SpacingTokens.sp2) {
            ForEach(Array(interactor.state.cards.enumerated()), id: \.element.id) { index, card in
                wordCard(card, soundColor: interactor.state.soundColor) {
                    hapticService.impact(.light)
                    interactor.toggle(card.id)
                }
                .scrollTransition(.animated(reduceMotion ? .linear(duration: 0) : .spring(response: 0.5, dampingFraction: 0.85))) { content, phase in
                    content
                        .opacity(phase.isIdentity ? 1 : 0)
                        .scaleEffect(phase.isIdentity ? 1 : 0.92)
                }
                .hsParallaxTile(factor: 0.2)
                .zIndex(Double(interactor.state.cards.count - index))
            }
        }
    }

    private func wordCard(
        _ card: ColorAndSoundModels.WordCard,
        soundColor: ColorAndSoundModels.SoundColor,
        action: @escaping () -> Void
    ) -> some View {
        // После выбора: верное слово подсвечивается «своим цветом» (успех),
        // неверное — мягко-нейтрально (errorless, без «красного»).
        let style: HSCardStyle = card.isSelected
            ? (card.belongs ? .tinted(soundColor.color.opacity(0.28)) : .tinted(ColorTokens.Kid.bgSoft))
            : .elevated
        return Button(action: action) {
            HSCard(style: style) {
                VStack(spacing: SpacingTokens.sp2) {
                    if let asset = card.asset {
                        HSContentSymbol(asset, size: 48)
                    } else {
                        Image(systemName: "textformat.abc")
                            .font(.system(size: 32))
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    Text(card.text)
                        .font(TypographyTokens.headline(15))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if card.isSelected {
                        Image(systemName: card.belongs ? "checkmark.circle.fill" : "minus.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(card.belongs ? ColorTokens.Semantic.success : ColorTokens.Kid.inkSoft)
                            .hsSymbolEffect(.bounce, value: card.isSelected)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, SpacingTokens.sp2)
            }
        }
        .buttonStyle(.plain)
        .disabled(card.isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(card.text))
        .accessibilityValue(Text(card.isSelected
            ? (card.belongs
                ? String(localized: "colorAndSound.a11y.right")
                : String(localized: "colorAndSound.a11y.wrong"))
            : String(localized: "colorAndSound.a11y.notChosen")))
        .accessibilityAddTraits(.isButton)
    }

    private func nextButton(interactor: ColorAndSoundInteractor) -> some View {
        HSButton(
            String(localized: "colorAndSound.cta.next"),
            style: .primary,
            size: .large,
            icon: "arrow.right.circle.fill"
        ) {
            hapticService.notification(.success)
            interactor.next()
        }
    }

    private func completeBanner(interactor: ColorAndSoundInteractor) -> some View {
        HSCard(style: .tinted(ColorTokens.Semantic.successBg)) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .celebrating, size: 56)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "colorAndSound.complete"))
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
                HSButton(
                    String(localized: "imitationLab.cta.done"),
                    style: .ghost,
                    size: .medium,
                    icon: "checkmark"
                ) {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("ColorAndSound — Light") {
    ColorAndSoundView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("ColorAndSound — Dark") {
    ColorAndSoundView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
