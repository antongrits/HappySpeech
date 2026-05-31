import OSLog
import SwiftUI

// MARK: - FourthExtraViewModelHolder

@MainActor
@Observable
final class FourthExtraViewModelHolder: FourthExtraDisplayLogic {

    var startVM: FourthExtraModels.Start.ViewModel?
    var currentRound: FourthExtraModels.Start.RoundViewModel?
    var lastFeedback: FeedbackTier?
    var lastLyalyaLine: String?
    /// id карточки, которую ребёнок выбрал в последней попытке.
    var chosenCardId: String?
    /// id «лишней» карточки текущего раунда (улёт/подсветка на hit).
    var revealedExtraId: String?
    /// id трёх «своих» карточек для подсказки (после 2 промахов).
    var hintCardIds: [String] = []
    /// Обобщение «своих» (обруч-категория + озвучка) на hit.
    var groupingLabel: String?
    /// Спросить «почему лишний» (7–8, semantic).
    var askWhy: Bool = false
    var summary: FourthExtraModels.Answer.SummaryViewModel?
    var isFinished: Bool = false
    var showCelebration: Bool = false
    /// Счётчик попыток в текущем раунде (для номера попытки в Request).
    var attemptInRound: Int = 0

    func displayStart(viewModel: FourthExtraModels.Start.ViewModel) async {
        self.startVM = viewModel
        self.currentRound = viewModel.firstRound
        resetRoundState()
        self.isFinished = false
        self.summary = nil
        self.showCelebration = false
    }

    func displayAnswer(viewModel: FourthExtraModels.Answer.ViewModel) async {
        self.lastFeedback = viewModel.feedback
        self.lastLyalyaLine = viewModel.lyalyaLine
        self.hintCardIds = viewModel.hintCardIds
        self.askWhy = viewModel.askWhy
        self.isFinished = viewModel.isFinished
        self.summary = viewModel.summary
        self.showCelebration = viewModel.summary?.showCelebration ?? false

        if viewModel.feedback == .hit {
            self.revealedExtraId = viewModel.extraCardId
            self.groupingLabel = viewModel.groupingLabel
        }

        if let next = viewModel.nextRound {
            // Новый раунд — стираем состояние предыдущего.
            self.currentRound = next
            resetRoundState()
            self.lastFeedback = nil
            self.lastLyalyaLine = nil
        }
    }

    private func resetRoundState() {
        self.chosenCardId = nil
        self.revealedExtraId = nil
        self.hintCardIds = []
        self.groupingLabel = nil
        self.askWhy = false
        self.attemptInRound = 0
    }
}

// MARK: - FourthExtraView (Clean Swift: View)
//
// F2-005 «Четвёртый лишний» (Wave 2).
//
// Детская игра классификации/обобщения: «Наведём порядок у Ляли». 4 карточки-
// картинки в сетке 2×2. Ляля задаёт вопрос (semantic: «Три дружат, а один —
// лишний» / phonetic: «Три слова со звуком, а одно — без»). Ребёнок тапает
// лишнюю карточку; при попадании 3 «своих» объединяются обручем-категорией,
// Ляля называет обобщение.
//
// Accessibility:
//   • Kid circuit: карточки крупные ≥ 96pt
//   • VoiceOver: карточки — описательные labels; промпт озвучен; объявление
//     обобщения после ответа
//   • Dynamic Type: подписи слов minimumScaleFactor(0.85) + lineLimit(nil)
//   • Reduced Motion: улёт лишней / обруч → opacity/обводка без spring;
//     confetti → static
//   • Light + Dark: ColorTokens.Kid + Brand адаптируются

struct FourthExtraView: View {

    let childId: String

    @State private var holder = FourthExtraViewModelHolder()
    @State private var interactor: FourthExtraInteractor?
    @State private var presenter: FourthExtraPresenter?
    @State private var router: FourthExtraRouter?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "FourthExtra.View"
    )

    private let columns = [
        GridItem(.flexible(), spacing: SpacingTokens.sp3),
        GridItem(.flexible(), spacing: SpacingTokens.sp3)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                // Семантический вариант — тёплый mesh; ненавязчиво.
                // Reduced Motion: убираем анимированный фон (accessibility +
                // детерминизм снимков).
                if !reduceMotion {
                    HSMeshGradientBackground(palette: backgroundPalette, animated: true)
                        .ignoresSafeArea()
                        .opacity(colorScheme == .dark ? 0.18 : 0.28)
                        .blendMode(.softLight)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                if holder.isFinished, let summary = holder.summary {
                    summarySection(summary)
                } else if let round = holder.currentRound {
                    gameSection(round: round)
                } else {
                    loadingSection
                }

                if holder.showCelebration {
                    HSConfettiView(preset: .celebration, isActive: $holder.showCelebration)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .navigationTitle(Text("fourthExtra.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text("fourthExtra.close.a11y"))
                }
            }
            .task {
                await setupAndStart()
            }
        }
        .environment(\.circuitContext, .kid)
    }

    private var backgroundPalette: HSMeshGradientBackground.Palette {
        // Фонетика — «прохлада» (звуковая тема); семантика — тепло.
        holder.currentRound?.variant == .phonetic ? .kidCool : .kidWarm
    }

    // MARK: - Game

    private func gameSection(
        round: FourthExtraModels.Start.RoundViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp4) {
            progressHeader(round)

            // Ляля задаёт вопрос.
            HSSpeechBubble(
                holder.lastLyalyaLine ?? round.promptLyalya,
                direction: .left,
                style: holder.lastFeedback == nil ? .question : bubbleStyle(holder.lastFeedback)
            )
            .padding(.horizontal, SpacingTokens.screenEdge)
            .id("bubble-\(round.id)-\(holder.lastFeedback?.rawValue ?? "q")")
            .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))

            Spacer(minLength: 0)

            // Сетка 2×2 карточек.
            cardsGrid(round: round)
                .padding(.horizontal, SpacingTokens.screenEdge)
                .id(round.id)
                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))

            // Обобщение «своих» при попадании (обруч-категория + текст).
            if let grouping = holder.groupingLabel, holder.lastFeedback == .hit {
                groupingBanner(grouping)
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }

            Spacer(minLength: 0)
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: round.id)
    }

    private func progressHeader(
        _ round: FourthExtraModels.Start.RoundViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            Text(round.progressLabel)
                .font(TypographyTokens.caption(12).monospacedDigit())
                .foregroundStyle(ColorTokens.Kid.inkMuted)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(ColorTokens.Kid.surfaceAlt)
                    Capsule()
                        .fill(ColorTokens.Brand.primary)
                        .frame(width: max(0, geo.size.width * round.progressFraction))
                }
            }
            .frame(height: 10)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.sp4)
    }

    // MARK: - Cards grid (2×2)

    private func cardsGrid(
        round: FourthExtraModels.Start.RoundViewModel
    ) -> some View {
        LazyVGrid(columns: columns, spacing: SpacingTokens.sp3) {
            ForEach(round.cards) { card in
                cardButton(card)
            }
        }
    }

    private func cardButton(
        _ card: FourthExtraModels.Start.CardViewModel
    ) -> some View {
        let isRevealedExtra = holder.revealedExtraId == card.id
        let isHinted = holder.hintCardIds.contains(card.id)
        let isChosenMiss = holder.chosenCardId == card.id
            && holder.lastFeedback != nil
            && holder.lastFeedback != .hit
        // На попадание «свои» (не-лишние) объединяются обручем.
        let isGrouped = holder.lastFeedback == .hit
            && holder.revealedExtraId != nil
            && card.id != holder.revealedExtraId

        return Button {
            Task { await chooseCard(card.id) }
        } label: {
            HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp3) {
                VStack(spacing: SpacingTokens.sp2) {
                    HSContentSymbol(card.imageAsset, size: 64, tint: ColorTokens.Brand.primary)
                        .scaleEffect(reduceMotion ? 1 : (isRevealedExtra ? 0.7 : 1))
                        .opacity(isRevealedExtra ? (reduceMotion ? 0.4 : 0.5) : 1)
                    Text(card.word)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 96)
            }
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .stroke(cardStroke(isGrouped: isGrouped, isHinted: isHinted, isMiss: isChosenMiss),
                            lineWidth: cardStrokeWidth(isGrouped: isGrouped, isHinted: isHinted, isMiss: isChosenMiss))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(card.accessibilityLabel))
        .accessibilityHint(Text("fourthExtra.card.hint"))
        .accessibilityAddTraits(isRevealedExtra ? [.isButton, .isSelected] : .isButton)
    }

    private func groupingBanner(_ grouping: String) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            Image(systemName: "circle.dashed")
                .font(.title3.weight(.bold))
                .foregroundStyle(ColorTokens.Brand.mint)
                .accessibilityHidden(true)
            Text(grouping)
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.sp3)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(ColorTokens.Brand.mint.opacity(0.18))
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }

    // MARK: - Summary

    private func summarySection(
        _ summary: FourthExtraModels.Answer.SummaryViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp5) {
            Spacer()

            Image(systemName: summary.accuracyFraction >= 0.8
                ? "square.grid.2x2.fill"
                : "hand.thumbsup.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(ColorTokens.Brand.gold)
                .hsSymbolEffect(.bounce, value: summary.scoreText)
                .accessibilityHidden(true)

            Text(summary.title)
                .font(TypographyTokens.title(26))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(summary.scoreText)
                .font(TypographyTokens.headline(20).monospacedDigit())
                .foregroundStyle(ColorTokens.Brand.primary)

            Text(summary.encouragement)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .padding(.horizontal, SpacingTokens.sp6)

            Spacer()

            VStack(spacing: SpacingTokens.sp3) {
                Button {
                    Task { await setupAndStart(forceRestart: true) }
                } label: {
                    Text("fourthExtra.summary.again")
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .fill(ColorTokens.Brand.primary)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("fourthExtra.summary.again.hint"))

                Button {
                    dismiss()
                } label: {
                    Text("fourthExtra.summary.done")
                        .font(TypographyTokens.body(16).weight(.medium))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp6)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ProgressView()
                .controlSize(.large)
            Text("fourthExtra.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Card styling

    private func cardStroke(isGrouped: Bool, isHinted: Bool, isMiss: Bool) -> Color {
        if isGrouped { return ColorTokens.Brand.mint }
        if isHinted { return ColorTokens.Brand.lilac }
        if isMiss { return ColorTokens.Brand.butter }
        return .clear
    }

    private func cardStrokeWidth(isGrouped: Bool, isHinted: Bool, isMiss: Bool) -> CGFloat {
        if isGrouped || isHinted || isMiss { return 3 }
        return 0
    }

    private func bubbleStyle(_ feedback: FeedbackTier?) -> HSSpeechBubble.BubbleStyle {
        switch feedback {
        case .hit:    return .lyalya
        case .retry:  return .hint
        case .almost, .none: return .question
        }
    }

    // MARK: - Wiring

    private func setupAndStart(forceRestart: Bool = false) async {
        if interactor == nil {
            let presenter = FourthExtraPresenter(displayLogic: holder)
            let worker = FourthExtraWorker(childRepository: container.childRepository)
            let interactor = FourthExtraInteractor(
                childId: childId,
                worker: worker,
                hapticService: container.hapticService,
                adaptivePlanner: container.adaptivePlannerService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = FourthExtraRouter(dismissAction: { dismiss() })
        }
        _ = forceRestart
        await interactor?.start(request: .init(childId: childId, preferredVariant: nil))
    }

    private func chooseCard(_ cardId: String) async {
        holder.chosenCardId = cardId
        holder.attemptInRound += 1
        await interactor?.answer(
            request: .init(chosenCardId: cardId, attemptInRound: holder.attemptInRound)
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview("FourthExtra / game") {
    FourthExtraView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
