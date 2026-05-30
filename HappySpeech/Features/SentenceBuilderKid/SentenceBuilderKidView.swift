import SwiftUI

// MARK: - SentenceBuilderKidView

struct SentenceBuilderKidView: View {

    let childId: String

    @State private var interactor: SentenceBuilderKidInteractor?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                // Step 10 Batch G — Pattern 1: kidCool mesh палитра (sentence-building).
                HSMeshGradientBackground(palette: .kidCool, animated: true)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.20 : 0.30)
                    .blendMode(.softLight)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                content
            }
            .navigationTitle(Text(String(localized: "sentenceBuilder.nav.title")))
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
                    interactor = SentenceBuilderKidInteractor(childId: childId)
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
                        .lineLimit(2)
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
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                Text("Твоё предложение:")
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                if interactor.state.assembled.isEmpty {
                    Text("Нажимай на слова ниже")
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
        HSCard(style: .tinted(ColorTokens.Kid.bgSoft)) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                Text("Доступные слова:")
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                if interactor.state.available.isEmpty {
                    Text("Все слова использованы")
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkSoft)
                        .padding(.vertical, SpacingTokens.sp2)
                } else {
                    flowLayout(chips: interactor.state.available, isAssembled: false) { id in
                        hapticService.impact(.light)
                        interactor.pickFromAvailable(id)
                    }
                }
            }
        }
    }

    /// Простой wrap-flow для чипов — используем `FlowLayout`-like через HStack
    /// внутри `LazyVStack` нельзя; пока маленькое количество чипов — обёртываем
    /// руками через 2 HStack-строки.
    private func flowLayout(
        chips: [SentenceBuilderKidModels.WordChip],
        isAssembled: Bool,
        onTap: @escaping (UUID) -> Void
    ) -> some View {
        // Простая wrap-имитация: ScrollView horizontal с HStack.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.sp2) {
                ForEach(chips) { chip in
                    chipView(chip, isAssembled: isAssembled) {
                        onTap(chip.id)
                    }
                    // Step 10 Batch G — Pattern 3: scrollTransition stagger.
                    .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] content, phase in
                        content
                            .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                            .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.9))
                    }
                    // Step 10 Batch G — Pattern 4: parallax drift на word chips.
                    .hsParallaxTile(factor: 0.15)
                }
            }
            .padding(.horizontal, 2)
        }
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
                    isAssembled ? Color.white : ColorTokens.Kid.ink
                )
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
        .accessibilityHint(Text(isAssembled ? "Убрать из предложения" : "Добавить в предложение"))
        .accessibilityAddTraits(.isButton)
    }

    private func resultCard(state: SentenceBuilderKidModels.ViewState) -> some View {
        HSCard(style: .tinted(state.isCorrect ? ColorTokens.Semantic.successBg : ColorTokens.Semantic.errorBg)) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: state.isCorrect ? .celebrating : .thinking, size: 48)
                    .accessibilityHidden(true)
                Text(state.isCorrect
                     ? "Отлично! Правильно собрал!"
                     : "Попробуй другой порядок")
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Kid.ink)
                Spacer()
                // Step 10 Batch G — Pattern 5: bounce on result state.
                Image(systemName: state.isCorrect ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill")
                    .font(.title3)
                    .foregroundStyle(state.isCorrect ? ColorTokens.Brand.mint : ColorTokens.Brand.butter)
                    .hsSymbolEffect(.bounce, value: state.isCorrect)
            }
        }
    }

    private func cta(interactor: SentenceBuilderKidInteractor) -> some View {
        HSButton(
            interactor.state.isCorrect
                ? "Новое предложение"
                : String(localized: "sentenceBuilder.cta.action"),
            style: .primary,
            size: .large,
            icon: interactor.state.isCorrect ? "arrow.right" : "arrow.counterclockwise"
        ) {
            hapticService.notification(.success)
            interactor.reset()
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
