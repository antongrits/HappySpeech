import SwiftUI

// MARK: - VisualVocabularyFlipView

struct VisualVocabularyFlipView: View {

    let childId: String

    @State private var interactor: VisualVocabularyFlipInteractor?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private let columns = Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sp2), count: 2)

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                // Step 10 Batch G — Pattern 1: kidCool mesh палитра (vocabulary).
                HSMeshGradientBackground(palette: .kidCool, animated: true)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.20 : 0.30)
                    .blendMode(.softLight)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                content
            }
            .navigationTitle(Text(String(localized: "vocabFlip.nav.title")))
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
                    interactor = VisualVocabularyFlipInteractor(childId: childId)
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            ScrollView {
                VStack(spacing: SpacingTokens.sp3) {
                    hero
                    filterBar(interactor: interactor)
                    grid(interactor: interactor)
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
        // Step 10 Batch G — Pattern 2: HSLiquidGlassCard(.elevated) для hero.
        HSLiquidGlassCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .happy, size: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "vocabFlip.hero.title"))
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "vocabFlip.hero.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func filterBar(interactor: VisualVocabularyFlipInteractor) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.sp2) {
                ForEach(VisualVocabularyFlipModels.SoundFilter.allCases) { f in
                    chip(f, interactor: interactor)
                }
            }
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
                .font(TypographyTokens.body(13).weight(.semibold))
                .foregroundStyle(selected
                                 ? ColorTokens.Overlay.onAccent
                                 : ColorTokens.Kid.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(selected
                                   ? ColorTokens.Brand.primary
                                   : ColorTokens.Kid.bgSoft)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(f.rawValue))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func grid(interactor: VisualVocabularyFlipInteractor) -> some View {
        LazyVGrid(columns: columns, spacing: SpacingTokens.sp2) {
            ForEach(interactor.deck) { card in
                flipCard(card, interactor: interactor)
                    // Step 10 Batch G — Pattern 3: scrollTransition stagger.
                    .scrollTransition(.animated.threshold(.visible(0.3))) { content, phase in
                        content
                            .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                            .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.9))
                    }
                    // Step 10 Batch G — Pattern 4: parallax drift на flip cards.
                    .hsParallaxTile(factor: 0.25)
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
            .frame(maxWidth: .infinity, minHeight: 140)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(flipped
                          ? ColorTokens.Brand.primary.opacity(0.12)
                          : ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(ColorTokens.Kid.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(flipped ? "Слово: \(card.word). Звук \(card.targetSound)" : "Карточка \(card.word)"))
        .accessibilityHint(Text("Двойное касание перевернёт"))
    }

    private func cardFront(_ card: VisualVocabularyFlipModels.Card) -> some View {
        VStack(spacing: SpacingTokens.sp1) {
            Image(systemName: card.symbol)
                .resizable()
                .scaledToFit()
                .frame(height: 60)
                .foregroundStyle(ColorTokens.Brand.primary)
                // Step 10 Batch G — Pattern 5: pulse on card symbol.
                .hsSymbolEffect(.pulse, value: card.id)
                .accessibilityHidden(true)
            Text("Перевернуть")
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Kid.inkSoft)
        }
        .padding(SpacingTokens.sp2)
    }

    private func cardBack(_ card: VisualVocabularyFlipModels.Card) -> some View {
        VStack(spacing: 4) {
            Text(card.word.capitalized)
                .font(TypographyTokens.title(20).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("Звук: \(card.targetSound)")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .padding(SpacingTokens.sp2)
    }

    private func cta(interactor: VisualVocabularyFlipInteractor) -> some View {
        HSButton(
            String(localized: "vocabFlip.cta.start"),
            style: .primary,
            size: .large,
            icon: "play.circle.fill"
        ) {
            hapticService.notification(.success)
            dismiss()
        }
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
