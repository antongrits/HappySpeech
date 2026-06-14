import SwiftUI

// MARK: - VisualVocabularyFlipView

struct VisualVocabularyFlipView: View {

    let childId: String

    @State private var interactor: VisualVocabularyFlipInteractor?
    @Environment(AppContainer.self) private var container
    @Environment(\.exitGame) private var exitGame
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.small), count: 2)

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                content
            }
            .navigationBarHidden(true)
            .task {
                if interactor == nil {
                    interactor = VisualVocabularyFlipInteractor(
                        childId: childId,
                        sessionPersistence: container.sessionPersistenceCoordinator
                    )
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    /// Фиксирует сессию вовлечённости и выходит из игры.
    private func finishAndExit(_ interactor: VisualVocabularyFlipInteractor) {
        Task { await interactor.finish() }
        exitGame()
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            KidGameTapScaffold(
                promptText: String(localized: "vocabFlip.hero.subtitle"),
                mascotState: .happy,
                primary: KidGamePrimaryAction(
                    title: String(localized: "vocabFlip.cta.start"),
                    icon: "play.fill"
                ) {
                    hapticService.notification(.success)
                    finishAndExit(interactor)
                },
                onClose: { finishAndExit(interactor) }
            ) {
                filterBar(interactor: interactor)
                grid(interactor: interactor)
            }
        } else {
            ProgressView().controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func filterBar(interactor: VisualVocabularyFlipInteractor) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.tiny) {
                ForEach(VisualVocabularyFlipModels.SoundFilter.allCases) { f in
                    chip(f, interactor: interactor)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func chip(
        _ f: VisualVocabularyFlipModels.SoundFilter,
        interactor: VisualVocabularyFlipInteractor
    ) -> some View {
        let selected = interactor.filter == f
        return Button {
            hapticService.impact(.light)
            interactor.setFilter(f)
        } label: {
            Text(f.rawValue)
                .font(TypographyTokens.labelRounded(13, weight: .semibold))
                .foregroundStyle(selected
                                 ? ColorTokens.Overlay.onAccent
                                 : ColorTokens.Kid.ink)
                .lineLimit(1)
                .padding(.horizontal, SpacingTokens.small)
                .padding(.vertical, SpacingTokens.tiny)
                .background(
                    Capsule().fill(selected
                                   ? ColorTokens.Brand.primary
                                   : ColorTokens.Kid.surface)
                    .overlay(
                        Capsule().strokeBorder(
                            selected ? Color.clear : ColorTokens.Kid.line, lineWidth: 1
                        )
                    )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(f.rawValue))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func grid(interactor: VisualVocabularyFlipInteractor) -> some View {
        LazyVGrid(columns: columns, spacing: SpacingTokens.small) {
            ForEach(interactor.deck) { card in
                flipCard(card, interactor: interactor)
            }
        }
    }

    private func flipCard(
        _ card: VisualVocabularyFlipModels.Card,
        interactor: VisualVocabularyFlipInteractor
    ) -> some View {
        let flipped = interactor.flippedIds.contains(card.id)
        return Button {
            hapticService.impact(.light)
            withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.75)) {
                interactor.toggle(card.id)
            }
        } label: {
            ZStack {
                if flipped {
                    cardBack(card)
                } else {
                    cardFront(card)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 148)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .fill(flipped
                          ? ColorTokens.Brand.primary.opacity(0.10)
                          : ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .strokeBorder(flipped ? ColorTokens.Brand.primary.opacity(0.5) : ColorTokens.Kid.line, lineWidth: 1.5)
            )
            .kidTileShadow()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(flipped
            ? String(format: String(localized: "vocabFlip.card.flipped.a11y %@ %@",
                                    defaultValue: "Слово: %@. Звук %@"), card.word, card.targetSound)
            : String(format: String(localized: "vocabFlip.card.front.a11y %@",
                                    defaultValue: "Карточка %@"), card.word)))
        .accessibilityHint(Text(String(localized: "vocabFlip.card.hint",
                                        defaultValue: "Двойное касание перевернёт")))
    }

    private func cardFront(_ card: VisualVocabularyFlipModels.Card) -> some View {
        VStack(spacing: SpacingTokens.tiny) {
            HSContentSymbol(card.symbol, size: 56, tint: ColorTokens.Brand.primary)
                .frame(width: 84, height: 84)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .fill(ColorTokens.Kid.surfaceAlt)
                )
                .accessibilityHidden(true)
            Text(String(localized: "vocabFlip.cta.flip"))
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Kid.inkSoft)
        }
        .padding(SpacingTokens.small)
    }

    private func cardBack(_ card: VisualVocabularyFlipModels.Card) -> some View {
        VStack(spacing: SpacingTokens.micro) {
            Text(card.word.capitalized)
                .font(TypographyTokens.kidCardTitle(20))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(nil)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
            Text(String(format: String(localized: "vocabFlip.card.sound %@",
                                        defaultValue: "Звук: %@"), card.targetSound))
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .padding(SpacingTokens.small)
    }
}

// MARK: - Preview

#Preview("VisualVocabularyFlip — Light") {
    VisualVocabularyFlipView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("VisualVocabularyFlip — Dark") {
    VisualVocabularyFlipView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
