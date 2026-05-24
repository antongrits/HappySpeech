import SwiftUI

// MARK: - WordOfTheDayView

struct WordOfTheDayView: View {

    let childId: String

    @State private var interactor: WordOfTheDayInteractor?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                // Step 10 Batch G — Pattern 1: kidWarm mesh палитра (daily word).
                HSMeshGradientBackground(palette: .kidWarm, animated: true)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.20 : 0.30)
                    .blendMode(.softLight)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                content
            }
            .navigationTitle(Text(String(localized: "wotd.nav.title")))
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
                    interactor = WordOfTheDayInteractor(childId: childId)
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
                    hero(interactor: interactor)
                    illustration(interactor: interactor)
                    feedback(interactor: interactor)
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

    private func hero(interactor: WordOfTheDayInteractor) -> some View {
        // Step 10 Batch G — Pattern 2: HSLiquidGlassCard(.elevated) для hero word-of-day.
        HSLiquidGlassCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .singing, size: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "wotd.hero.title"))
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "wotd.hero.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func illustration(interactor: WordOfTheDayInteractor) -> some View {
        HSCard(style: .elevated) {
            VStack(spacing: SpacingTokens.sp3) {
                Image(systemName: interactor.card.illustrationSymbol)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .foregroundStyle(ColorTokens.Brand.primary)
                    // Step 10 Batch G — Pattern 5: pulse on illustration.
                    .hsSymbolEffect(.pulse, value: interactor.card.word)
                    .accessibilityHidden(true)
                Text(interactor.card.word.capitalized)
                    .font(TypographyTokens.titleLarge(32))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(interactor.card.hint)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text("Звук: \(interactor.card.targetSound)")
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sp2)
        }
    }

    @ViewBuilder
    private func feedback(interactor: WordOfTheDayInteractor) -> some View {
        switch interactor.phase {
        case .idle:
            EmptyView()
        case .recording:
            HStack(spacing: SpacingTokens.sp2) {
                ProgressView().controlSize(.regular)
                Text("Слушаю…")
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
        case .scored(let stars):
            HStack(spacing: SpacingTokens.sp1) {
                ForEach(0..<3, id: \.self) { idx in
                    Image(systemName: idx < stars ? "star.fill" : "star")
                        .foregroundStyle(ColorTokens.Brand.gold)
                        .font(.system(size: 28))
                        // Step 10 Batch G — Pattern 3: scrollTransition stagger
                        // (also acts as reveal на stars).
                        .scrollTransition(.animated.threshold(.visible(0.3))) { content, phase in
                            content
                                .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                                .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.9))
                        }
                        // Step 10 Batch G — Pattern 5: bounce on score reveal.
                        .hsSymbolEffect(.bounce, value: stars)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Оценка: \(stars) из 3"))
        }
    }

    private func cta(interactor: WordOfTheDayInteractor) -> some View {
        HSButton(
            String(localized: "wotd.cta.speak"),
            style: .primary,
            size: .large,
            icon: "mic.fill"
        ) {
            hapticService.impact(.medium)
            interactor.startRecording()
        }
        .disabled(interactor.phase == .recording)
    }
}

// MARK: - Preview

#Preview("WordOfTheDay — Light") {
    WordOfTheDayView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("WordOfTheDay — Dark") {
    WordOfTheDayView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
