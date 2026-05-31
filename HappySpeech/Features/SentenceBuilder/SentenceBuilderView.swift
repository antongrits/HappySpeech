import OSLog
import SwiftUI

// MARK: - SentenceBuilderViewModelHolder

@MainActor
@Observable
final class SentenceBuilderViewModelHolder: SentenceBuilderDisplayLogic {

    var startVM: SentenceBuilderModels.Start.ViewModel?
    var currentRound: SentenceBuilderModels.Start.RoundViewModel?
    var lastFeedback: FeedbackTier?
    var lastLyalyaLine: String?

    /// id карточек, выложенных в слоты (по порядку слева направо).
    var placedIds: [String] = []
    /// Озвучка собранной фразы (+ субтитр) на hit.
    var spokenSentence: String?
    /// Порядок подсветки слотов на retry (канонический).
    var highlightOrder: [String] = []
    /// id карточки-подсказки («прилипает» в слот при retry).
    var hintTokenId: String?

    var summary: SentenceBuilderModels.Answer.SummaryViewModel?
    var isFinished: Bool = false
    var showCelebration: Bool = false
    /// Счётчик попыток в текущем раунде (для номера попытки в Request).
    var attemptInRound: Int = 0

    /// Карточки, ещё не выложенные в слоты (банк). Отображаются в стабильном
    /// порядке (по id): антипозиционное правило здесь относится к ПОРЯДКУ
    /// СБОРКИ в слотах (графируемый ответ), а не к позиции карточки в банке —
    /// поэтому стабильный показ банка не «прибивает» ответ к позиции и заодно
    /// делает снапшоты детерминированными.
    var bankRemaining: [SentenceBuilderModels.Start.CardViewModel] {
        guard let round = currentRound else { return [] }
        let placed = Set(placedIds)
        return round.bankCards
            .filter { !placed.contains($0.id) }
            .sorted { $0.id < $1.id }
    }

    /// Заполнена ли лента полностью (можно проверять «Готово»).
    var isLentaFull: Bool {
        guard let round = currentRound else { return false }
        return placedIds.count >= round.slotCount
    }

    func cardVM(for id: String) -> SentenceBuilderModels.Start.CardViewModel? {
        currentRound?.bankCards.first { $0.id == id }
    }

    func displayStart(viewModel: SentenceBuilderModels.Start.ViewModel) async {
        self.startVM = viewModel
        self.currentRound = viewModel.firstRound
        resetRoundState()
        self.isFinished = false
        self.summary = nil
        self.showCelebration = false
    }

    func displayAnswer(viewModel: SentenceBuilderModels.Answer.ViewModel) async {
        self.lastFeedback = viewModel.feedback
        self.lastLyalyaLine = viewModel.lyalyaLine
        self.highlightOrder = viewModel.highlightOrder
        self.hintTokenId = viewModel.hintTokenId
        self.isFinished = viewModel.isFinished
        self.summary = viewModel.summary
        self.showCelebration = viewModel.summary?.showCelebration ?? false

        if viewModel.feedback == .hit {
            self.spokenSentence = viewModel.spokenSentence
        } else if viewModel.feedback == .retry, let hint = viewModel.hintTokenId {
            // Errorless: возвращаем карточки в банк, но подсказку-карточку
            // оставляем «прилипшей» первой в ленте.
            self.placedIds = [hint]
        } else {
            // almost — мягко возвращаем карточки для пересборки.
            self.placedIds = []
        }

        if let next = viewModel.nextRound {
            self.currentRound = next
            resetRoundState()
            self.lastFeedback = nil
            self.lastLyalyaLine = nil
        }
    }

    func place(_ id: String) {
        guard let round = currentRound, placedIds.count < round.slotCount,
              !placedIds.contains(id) else { return }
        placedIds.append(id)
    }

    func removeLast() {
        guard !placedIds.isEmpty else { return }
        placedIds.removeLast()
    }

    func removeFromSlot(_ id: String) {
        placedIds.removeAll { $0 == id }
    }

    private func resetRoundState() {
        self.placedIds = []
        self.spokenSentence = nil
        self.highlightOrder = []
        self.hintTokenId = nil
        self.attemptInRound = 0
    }
}

// MARK: - SentenceBuilderView (Clean Swift: View)
//
// F2-004 «Конструктор предложения» (Wave 2).
//
// ЕДИНСТВЕННАЯ механика Волны 2 с последовательной сборкой: ребёнок выкладывает
// слова-карточки из банка в ленту-слоты, собирая фразу слева направо
// (tap-to-place; тап по слоту снимает карточку обратно). Сцена-подсказка крупно
// сверху, Ляля ведёт раунд. На «Готово» — частичная оценка по «светофору»; на
// hit собранная фраза проговаривается целиком (закрепление по слуху).
//
// Отличие от MVP SentenceBuilderKid: тот — одна жёстко зашитая фраза, точная
// проверка порядка, тонкий View-only. Здесь — полноценный VIP (под-типы,
// частичная оценка matchesPartially, корпус, fading, SM-2, прогрессия).
//
// Accessibility:
//   • Kid circuit: карточки крупные (touch ≥ 56pt), tap-to-place.
//   • VoiceOver: карточка — слово + роль («предлог на»); слот — «слот N из M,
//     пусто / занято словом X»; кнопка «Готово».
//   • Dynamic Type: подписи .lineLimit(nil) + .minimumScaleFactor(0.85).
//   • Reduced Motion: «оживание сцены» / улёт дистрактора → static + хаптик.
//   • Light + Dark: ColorTokens.Kid + Brand адаптируются.

struct SentenceBuilderView: View {

    let childId: String

    @State private var holder = SentenceBuilderViewModelHolder()
    @State private var interactor: SentenceBuilderInteractor?
    @State private var presenter: SentenceBuilderPresenter?
    @State private var router: SentenceBuilderRouter?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SentenceBuilder.View"
    )

    private let bankColumns = [
        GridItem(.adaptive(minimum: 96), spacing: SpacingTokens.sp3)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                if !reduceMotion {
                    HSMeshGradientBackground(palette: .kidWarm, animated: true)
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
            .navigationTitle(Text("sentenceBuilder.title"))
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
                    .accessibilityLabel(Text("sentenceBuilder.close.a11y"))
                }
            }
            .task {
                await setupAndStart()
            }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Game

    private func gameSection(
        round: SentenceBuilderModels.Start.RoundViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp4) {
            progressHeader(round)

            HSSpeechBubble(
                holder.lastLyalyaLine ?? round.promptLyalya,
                direction: .left,
                style: holder.lastFeedback == nil ? .question : bubbleStyle(holder.lastFeedback)
            )
            .padding(.horizontal, SpacingTokens.screenEdge)
            .id("bubble-\(round.id)-\(holder.lastFeedback?.rawValue ?? "q")")
            .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))

            sceneCard(round: round)
                .padding(.horizontal, SpacingTokens.screenEdge)

            // Лента-слоты (зона сборки).
            slotLane(round: round)
                .padding(.horizontal, SpacingTokens.screenEdge)

            Spacer(minLength: 0)

            // Банк слов-карточек.
            bankGrid(round: round)
                .padding(.horizontal, SpacingTokens.screenEdge)

            doneButton(round: round)
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.sp5)
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: round.id)
    }

    private func progressHeader(
        _ round: SentenceBuilderModels.Start.RoundViewModel
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

    // MARK: - Scene card (сцена-ситуация)

    private func sceneCard(
        round: SentenceBuilderModels.Start.RoundViewModel
    ) -> some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp4) {
            VStack(spacing: SpacingTokens.sp2) {
                HSContentSymbol(round.sceneImage, size: 64, tint: ColorTokens.Brand.primary)
                    .scaleEffect(reduceMotion ? 1 : (holder.lastFeedback == .hit ? 1.08 : 1))

                if let sentence = holder.spokenSentence, holder.lastFeedback == .hit, !sentence.isEmpty {
                    Text(sentence)
                        .font(TypographyTokens.headline(18))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(
            String(format: String(localized: "sentenceBuilder.scene.a11y"), round.promptLyalya)
        ))
    }

    // MARK: - Slot lane (лента-слоты, зона сборки)

    private func slotLane(
        round: SentenceBuilderModels.Start.RoundViewModel
    ) -> some View {
        let columns = [GridItem(.adaptive(minimum: 80), spacing: SpacingTokens.sp2)]
        return LazyVGrid(columns: columns, spacing: SpacingTokens.sp2) {
            ForEach(0..<round.slotCount, id: \.self) { index in
                slotView(index: index, round: round)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func slotView(
        index: Int,
        round: SentenceBuilderModels.Start.RoundViewModel
    ) -> some View {
        let placedId = index < holder.placedIds.count ? holder.placedIds[index] : nil
        let card = placedId.flatMap { holder.cardVM(for: $0) }
        let isHintSlot = holder.lastFeedback == .retry
            && index < holder.highlightOrder.count
            && holder.hintTokenId == holder.highlightOrder[index]

        return Button {
            if let placedId { holder.removeFromSlot(placedId) }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .fill(card == nil ? ColorTokens.Kid.surfaceAlt : ColorTokens.Brand.primary.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                            .stroke(
                                isHintSlot ? ColorTokens.Brand.lilac : ColorTokens.Kid.inkMuted.opacity(0.3),
                                style: StrokeStyle(lineWidth: isHintSlot ? 3 : 1.5, dash: card == nil ? [5] : [])
                            )
                    )

                if let card {
                    Text(card.text)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .padding(.horizontal, SpacingTokens.sp1)
                } else {
                    Text("\(index + 1)")
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted.opacity(0.5))
                }
            }
            .frame(minHeight: 56)
        }
        .buttonStyle(.plain)
        .disabled(card == nil)
        .accessibilityLabel(Text(slotAccessibilityLabel(index: index, total: round.slotCount, card: card)))
        .accessibilityHint(card == nil ? Text("") : Text("sentenceBuilder.slot.hint"))
    }

    private func slotAccessibilityLabel(
        index: Int,
        total: Int,
        card: SentenceBuilderModels.Start.CardViewModel?
    ) -> String {
        if let card {
            return String(
                format: String(localized: "sentenceBuilder.slot.a11y.filled"),
                index + 1, total, card.text
            )
        }
        return String(
            format: String(localized: "sentenceBuilder.slot.a11y.empty"),
            index + 1, total
        )
    }

    // MARK: - Bank grid (банк слов-карточек)

    private func bankGrid(
        round: SentenceBuilderModels.Start.RoundViewModel
    ) -> some View {
        LazyVGrid(columns: bankColumns, spacing: SpacingTokens.sp3) {
            ForEach(holder.bankRemaining) { card in
                bankCard(card)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func bankCard(
        _ card: SentenceBuilderModels.Start.CardViewModel
    ) -> some View {
        Button {
            holder.place(card.id)
        } label: {
            HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp2) {
                HStack(spacing: SpacingTokens.sp1) {
                    if let asset = card.imageAsset {
                        HSContentSymbol(asset, size: 28, tint: ColorTokens.Brand.primary)
                    }
                    Text(card.text)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                }
                .frame(minHeight: 40)
                .padding(.horizontal, SpacingTokens.sp1)
            }
        }
        .buttonStyle(.plain)
        .frame(minHeight: 56)
        .accessibilityLabel(Text(card.accessibilityLabel))
        .accessibilityHint(Text("sentenceBuilder.card.hint"))
    }

    // MARK: - Done button

    private func doneButton(
        round: SentenceBuilderModels.Start.RoundViewModel
    ) -> some View {
        Button {
            Task { await checkAnswer() }
        } label: {
            Text("sentenceBuilder.done")
                .font(TypographyTokens.headline(17))
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .fill(holder.isLentaFull ? ColorTokens.Brand.primary : ColorTokens.Brand.primary.opacity(0.4))
                )
        }
        .buttonStyle(.plain)
        .disabled(!holder.isLentaFull)
        .accessibilityLabel(Text("sentenceBuilder.done"))
        .accessibilityHint(Text("sentenceBuilder.done.hint"))
    }

    // MARK: - Summary

    private func summarySection(
        _ summary: SentenceBuilderModels.Answer.SummaryViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp5) {
            Spacer()

            Image(systemName: summary.accuracyFraction >= 0.8
                ? "text.bubble.fill"
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
                    Text("sentenceBuilder.summary.again")
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .fill(ColorTokens.Brand.primary)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("sentenceBuilder.summary.again.hint"))

                Button {
                    dismiss()
                } label: {
                    Text("sentenceBuilder.summary.done")
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
            Text("sentenceBuilder.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Styling

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
            let presenter = SentenceBuilderPresenter(displayLogic: holder)
            let worker = SentenceBuilderWorker(childRepository: container.childRepository)
            let interactor = SentenceBuilderInteractor(
                childId: childId,
                worker: worker,
                hapticService: container.hapticService,
                adaptivePlanner: container.adaptivePlannerService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = SentenceBuilderRouter(dismissAction: { dismiss() })
        }
        _ = forceRestart
        await interactor?.start(request: .init(childId: childId, preferredSubtask: nil))
    }

    private func checkAnswer() async {
        guard holder.isLentaFull else { return }
        holder.attemptInRound += 1
        await interactor?.answer(
            request: .init(placedOrder: holder.placedIds, attemptInRound: holder.attemptInRound)
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview("SentenceBuilder / game") {
    SentenceBuilderView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
