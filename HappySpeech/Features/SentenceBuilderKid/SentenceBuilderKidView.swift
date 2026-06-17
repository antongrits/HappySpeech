import SwiftUI

// MARK: - SentenceBuilderKidView

struct SentenceBuilderKidView: View {

    let childId: String

    @State private var interactor: SentenceBuilderKidInteractor?
    @Environment(AppContainer.self) private var container
    @Environment(\.exitGame) private var exitGame
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()
            // Step 10 Batch G — Pattern 1: kidWarm mesh палитра (drag-класс).
            HSMeshGradientBackground(palette: .kidWarm, animated: true)
                .ignoresSafeArea()
                .opacity(colorScheme == .dark ? 0.20 : 0.30)
                .blendMode(.softLight)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            content
        }
        .task {
            if interactor == nil {
                let new = SentenceBuilderKidInteractor(
                    childId: childId,
                    childRepository: container.childRepository,
                    adaptivePlanner: container.adaptivePlannerService
                )
                interactor = new
                await new.load()
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor, interactor.state.isLoaded {
            ScrollView {
                VStack(spacing: SpacingTokens.sp4) {
                    // Drag-класс: заголовок с X-кнопкой (без системного nav bar).
                    HStack(alignment: .firstTextBaseline) {
                        Text(String(localized: "sentenceBuilder.nav.title"))
                            .font(TypographyTokens.title(22))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Spacer()
                        Button {
                            exitGame()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(ColorTokens.Kid.inkSoft)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(String(localized: "action.close")))
                    }
                    progressHeader(state: interactor.state)
                    hero
                    assembledZone(interactor: interactor)
                    availableZone(interactor: interactor)
                    if interactor.state.isFull {
                        resultCard(state: interactor.state)
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

    /// Прогресс-шапка эталонного класса kid-game-drag: тёплый бар + степ-чип
    /// «N / M». Реальные данные из состояния (`sentenceIndex`/`totalSentences`),
    /// никакой фабрикации.
    private func progressHeader(state: SentenceBuilderKidModels.ViewState) -> some View {
        let total = max(state.totalSentences, 1)
        let current = min(state.sentenceIndex + 1, total)
        return VStack(spacing: SpacingTokens.tiny) {
            HStack(spacing: SpacingTokens.small) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(ColorTokens.Kid.line)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, geo.size.width * Double(current) / Double(total)))
                    }
                }
                .frame(height: 12)
                .accessibilityHidden(true)
                KidStepChip(current: current, total: total)
            }
            Text(String(localized: "Прогресс"))
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var hero: some View {
        // Step 10 Batch G — Pattern 2: HSLiquidGlassCard(.elevated) для hero.
        HSLiquidGlassCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .explaining, size: 56)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "sentenceBuilder.hero.title"))
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "sentenceBuilder.hero.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func assembledZone(interactor: SentenceBuilderKidInteractor) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            KidSectionLabel(String(localized: "sentenceBuilder.yourSentence"))
            assembledCard(interactor: interactor)
        }
    }

    private func assembledCard(interactor: SentenceBuilderKidInteractor) -> some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                if interactor.state.assembled.isEmpty {
                    Text(String(localized: "sentenceBuilder.tapWords"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkSoft)
                        .padding(.vertical, SpacingTokens.sp2)
                } else {
                    flowLayout(chips: interactor.state.assembled, isAssembled: true) { id in
                        hapticService.impact(.light)
                        interactor.removeFromAssembled(id)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        }
    }

    private func availableZone(interactor: SentenceBuilderKidInteractor) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            KidSectionLabel(String(localized: "sentenceBuilder.availableWords"))
            KidTrayContainer {
                Group {
                    if interactor.state.available.isEmpty {
                        Text(String(localized: "sentenceBuilder.allUsed"))
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                            .frame(maxWidth: .infinity, minHeight: 56)
                    } else {
                        flowLayout(chips: interactor.state.available, isAssembled: false) { id in
                            hapticService.impact(.light)
                            interactor.pickFromAvailable(id)
                        }
                        .frame(minHeight: 56)
                    }
                }
            }
        }
    }

    /// Wrap-флоу для чипов (эталон `flex-wrap`): слова переносятся на новую
    /// строку, заполняя поднос сверху вниз. Раньше был горизонтальный ScrollView,
    /// из-за которого длинные предложения уезжали за край и слова прятались —
    /// теперь все чипы видны на SE без overflow.
    private func flowLayout(
        chips: [SentenceBuilderKidModels.WordChip],
        isAssembled: Bool,
        onTap: @escaping (UUID) -> Void
    ) -> some View {
        KidWrapLayout(spacing: SpacingTokens.sp2, lineSpacing: SpacingTokens.sp2) {
            ForEach(chips) { chip in
                chipView(chip, isAssembled: isAssembled) {
                    onTap(chip.id)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chipView(
        _ chip: SentenceBuilderKidModels.WordChip,
        isAssembled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(chip.text)
                .font(TypographyTokens.headline(16).weight(.semibold))
                .foregroundStyle(
                    isAssembled ? ColorTokens.Overlay.onAccent : ColorTokens.Kid.ink
                )
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, SpacingTokens.sp3)
                .padding(.vertical, SpacingTokens.sp2)
                .background(
                    Capsule().fill(
                        isAssembled ? ColorTokens.Brand.primary : ColorTokens.Kid.surface
                    )
                )
                .overlay(
                    Capsule().stroke(
                        isAssembled ? Color.clear : ColorTokens.Kid.line,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(chip.text))
        .accessibilityHint(Text(isAssembled
            ? String(localized: "sentenceBuilder.a11y.remove")
            : String(localized: "sentenceBuilder.a11y.add")))
        .accessibilityAddTraits(.isButton)
    }

    private func resultCard(state: SentenceBuilderKidModels.ViewState) -> some View {
        // Тёплые заливки в палитре приложения (как Bingo/Memory): «верно» —
        // мягкий мятный тинт-акцент, «попробуй ещё» — коралловый. Семантика
        // дублируется иконкой; без больших зелёных/красных заливок.
        HSCard(style: .tinted(state.isCorrect
                              ? ColorTokens.Brand.mint.opacity(0.16)
                              : ColorTokens.Brand.primaryLo.opacity(0.30))) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: state.isCorrect ? .celebrating : .thinking, size: 48)
                    .accessibilityHidden(true)
                Text(state.isCorrect
                     ? String(localized: "sentenceBuilder.result.correct")
                     : String(localized: "sentenceBuilder.result.retry"))
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: SpacingTokens.sp2)
                // Step 10 Batch G — Pattern 5: bounce on result state.
                Image(systemName: state.isCorrect ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill")
                    .font(.title3)
                    .foregroundStyle(state.isCorrect ? ColorTokens.Brand.mint : ColorTokens.Brand.butter)
                    .hsSymbolEffect(.bounce, value: state.isCorrect)
            }
        }
    }

    @ViewBuilder
    private func cta(interactor: SentenceBuilderKidInteractor) -> some View {
        if interactor.state.isGameComplete {
            HSCard(style: .tinted(ColorTokens.Brand.mint.opacity(0.16))) {
                HStack(spacing: SpacingTokens.sp3) {
                    LyalyaMascotView(state: .celebrating, size: 48)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "sentenceBuilder.gameDone"))
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.85)
                        Text(String(
                            format: String(localized: "kidGame.stars %lld"),
                            interactor.state.stars
                        ))
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(ColorTokens.Brand.gold)
                    }
                    Spacer(minLength: 0)
                }
            }
        } else if interactor.state.isCorrect {
            HSButton(
                String(localized: "sentenceBuilder.cta.next"),
                style: .primary,
                size: .large,
                icon: "arrow.right"
            ) {
                hapticService.notification(.success)
                interactor.next()
            }
        } else {
            HSButton(
                String(localized: "sentenceBuilder.cta.action"),
                style: .secondary,
                size: .large,
                icon: "arrow.counterclockwise"
            ) {
                hapticService.impact(.light)
                interactor.reset()
            }
        }
    }
}

// MARK: - Preview

#Preview("SentenceBuilderKid — Light") {
    SentenceBuilderKidView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("SentenceBuilderKid — Dark") {
    SentenceBuilderKidView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
