import SwiftUI

// MARK: - WordOfTheDayView

struct WordOfTheDayView: View {

    let childId: String

    @State private var interactor: WordOfTheDayInteractor?
    @Environment(AppContainer.self) private var container
    @Environment(\.exitGame) private var exitGame
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                // kid-sound-detail: статичный тёплый kidWarm mesh (без волн).
                HSMeshGradientBackground(palette: .kidWarm, animated: false)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.18 : 0.30)
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
                        exitGame()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
            .task {
                if interactor == nil {
                    interactor = WordOfTheDayInteractor(
                        childId: childId,
                        audioService: container.audioService,
                        scorer: container.pronunciationService,
                        adaptivePlanner: container.adaptivePlannerService
                    )
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
                    hero(interactor: interactor)
                    illustration(interactor: interactor)
                    howTo(interactor: interactor)
                    feedback(interactor: interactor)
                    cta(interactor: interactor)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
                .padding(.bottom, SpacingTokens.sp6)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaPadding(.bottom, SpacingTokens.sp2)
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
                        .fixedSize(horizontal: false, vertical: true)
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
        // P1.3: градиентная карточка warmSunset + слово-герой kidDisplay(40).
        HSCard(style: .gradientTinted(GradientTokens.cardCoralButter)) {
            VStack(spacing: SpacingTokens.sp3) {
                // P1-FIX: показываем реальную картинку слова (word_* из
                // word_manifest), а не абстрактный SF-символ. HSContentSymbol
                // сам выбирает ассет vs SF-фолбэк по имени displaySymbol.
                HSContentSymbol(
                    interactor.card.displaySymbol,
                    size: 132,
                    tint: ColorTokens.Brand.primary
                )
                .frame(width: 140, height: 140)
                .hsSymbolEffect(.pulse, value: interactor.card.word)
                .accessibilityHidden(true)
                // P3: целевое слово — главный элемент экрана, kidDisplay(40)
                Text(interactor.card.word.capitalized)
                    .font(TypographyTokens.kidDisplay(40))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(interactor.card.hint)
                    .font(TypographyTokens.kidBody(15))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                // Целевой звук — маленький тёплый чип
                Text(String(format: String(localized: "wotd.target.format"), interactor.card.targetSound))
                    .font(TypographyTokens.caption(12).weight(.semibold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .padding(.horizontal, SpacingTokens.sp2)
                    .padding(.vertical, SpacingTokens.micro)
                    .background(Capsule().fill(ColorTokens.Brand.primaryLo.opacity(0.18)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sp2)
        }
    }

    private func howTo(interactor: WordOfTheDayInteractor) -> some View {
        // kid-sound-detail «как сказать»: маленькая иконка-панель + тёплая
        // дружеская подсказка (реальное card.hint), не клинично.
        HSCard(style: .flat, padding: SpacingTokens.sp3) {
            HStack(spacing: SpacingTokens.sp3) {
                ZStack {
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .fill(ColorTokens.Brand.rose.opacity(0.14))
                        .frame(width: 64, height: 64)
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .symbolRenderingMode(.hierarchical)
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text("wotd.howto.label")
                        .font(TypographyTokens.caption(11).weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(ColorTokens.Kid.inkSoft)
                    Text(interactor.card.hint)
                        .font(TypographyTokens.kidCardTitle(15))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func feedback(interactor: WordOfTheDayInteractor) -> some View {
        switch interactor.phase {
        case .idle:
            EmptyView()
        case .recording:
            HStack(spacing: SpacingTokens.sp2) {
                ProgressView().controlSize(.regular)
                Text(String(localized: "wotd.listening", defaultValue: "Слушаю…"))
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
                        .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] content, phase in
                            content
                                .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                                .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.9))
                        }
                        // Step 10 Batch G — Pattern 5: bounce on score reveal.
                        .hsSymbolEffect(.bounce, value: stars)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(
                String(format: String(localized: "wotd.stars.a11y", defaultValue: "Оценка: %lld из 3"), stars)
            ))
        case .tryAgain:
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                    .font(.system(size: 24))
                Text(String(localized: "wotd.tryAgain", defaultValue: "Давай попробуем ещё раз!"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
            .accessibilityElement(children: .combine)
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
