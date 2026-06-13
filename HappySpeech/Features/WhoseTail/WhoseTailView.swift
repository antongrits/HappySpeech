import OSLog
import SwiftUI

// MARK: - WhoseTailViewModelHolder

@MainActor
@Observable
final class WhoseTailViewModelHolder: WhoseTailDisplayLogic {

    var startVM: WhoseTailModels.Start.ViewModel?
    var currentRound: WhoseTailModels.Start.RoundViewModel?
    var lastFeedback: FeedbackTier?
    var lastLyalyaLine: String?
    /// id варианта, который ребёнок выбрал в последней попытке.
    var chosenOptionId: String?
    /// id правильного варианта текущего раунда (подсветка на hit).
    var revealedOptionId: String?
    /// id варианта-подсказки (после 2 промахов).
    var hintOptionId: String?
    /// Целевая форма прилагательного (озвучка + субтитр) на hit.
    var spokenForm: String?
    /// Попросить «скажи, чей хвост?» (7–8 лет).
    var askToRepeat: Bool = false
    var summary: WhoseTailModels.Answer.SummaryViewModel?
    var isFinished: Bool = false
    var showCelebration: Bool = false
    /// Счётчик попыток в текущем раунде (для номера попытки в Request).
    var attemptInRound: Int = 0

    func displayStart(viewModel: WhoseTailModels.Start.ViewModel) async {
        self.startVM = viewModel
        self.currentRound = viewModel.firstRound
        resetRoundState()
        self.isFinished = false
        self.summary = nil
        self.showCelebration = false
    }

    func displayAnswer(viewModel: WhoseTailModels.Answer.ViewModel) async {
        self.lastFeedback = viewModel.feedback
        self.lastLyalyaLine = viewModel.lyalyaLine
        self.hintOptionId = viewModel.hintOptionId
        self.askToRepeat = viewModel.askToRepeat
        self.isFinished = viewModel.isFinished
        self.summary = viewModel.summary
        self.showCelebration = viewModel.summary?.showCelebration ?? false

        if viewModel.feedback == .hit {
            self.revealedOptionId = viewModel.correctOptionId
            self.spokenForm = viewModel.spokenForm
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
        self.chosenOptionId = nil
        self.revealedOptionId = nil
        self.hintOptionId = nil
        self.spokenForm = nil
        self.askToRepeat = false
        self.attemptInRound = 0
    }
}

// MARK: - WhoseTailView (Clean Swift: View)
//
// F2-006 «Чей хвост / чей домик» (Wave 2).
//
// Детская игра словообразования прилагательных: «Чей это хвост?». Улика-картинка
// крупно сверху (хвост / домик / предмет). Ляля задаёт вопрос-загадку. Ребёнок
// сопоставляет улику с правильным зверем/материалом (тап по карточке); при
// попадании система проговаривает целевую форму прилагательного («Это лисий
// хвост!») — закрепление формы по слуху (методическое ядро словообразования).
//
// Accessibility:
//   • Kid circuit: карточки-варианты крупные (touch ≥ 96pt)
//   • VoiceOver: улика — вопрос «чей?»; вариант — слово зверя/материала; на hit
//     озвучивается spokenForm + субтитр (целевая форма)
//   • Dynamic Type: подписи вариантов minimumScaleFactor(0.85) + lineLimit(nil)
//   • Reduced Motion: «прирастание хвоста»/подсветка → opacity/обводка без
//     spring; confetti → static
//   • Light + Dark: ColorTokens.Kid + Brand адаптируются

struct WhoseTailView: View {

    let childId: String

    @State private var holder = WhoseTailViewModelHolder()
    @State private var interactor: WhoseTailInteractor?
    @State private var presenter: WhoseTailPresenter?
    @State private var router: WhoseTailRouter?

    @Environment(\.exitGame) private var exitGame
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WhoseTail.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()

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
            .navigationBarHidden(true)
            .task {
                await setupAndStart()
            }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Game

    private func gameSection(
        round: WhoseTailModels.Start.RoundViewModel
    ) -> some View {
        KidGameTapScaffold(
            stepLabel: round.progressLabel,
            progress: round.progressFraction,
            promptText: holder.lastLyalyaLine ?? round.promptLyalya,
            mascotState: mascotState,
            feedback: currentFeedback,
            onClose: { exitGame() }
        ) {
            cueCard(round: round)
                .id(round.id)
                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            optionsGrid(round: round)
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: round.id)
    }

    private var mascotState: LyalyaState {
        switch holder.lastFeedback {
        case .hit:   return .celebrating
        case .retry: return .encouraging
        case .almost, .none: return .thinking
        }
    }

    private var currentFeedback: KidGameFeedback? {
        if holder.lastFeedback == .hit {
            if let form = holder.spokenForm, !form.isEmpty {
                return KidGameFeedback(.correct, form)
            }
            return holder.lastLyalyaLine.map { KidGameFeedback(.correct, $0) }
        }
        guard let line = holder.lastLyalyaLine, let fb = holder.lastFeedback else { return nil }
        return KidGameFeedback(fb == .retry ? .hint : .incorrect, line)
    }

    // MARK: - Cue card (улика)

    private func cueCard(
        round: WhoseTailModels.Start.RoundViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.small) {
            HSContentSymbol(round.cueImage, size: 120, tint: ColorTokens.Brand.primary)
                .scaleEffect(reduceMotion ? 1 : (holder.lastFeedback == .hit ? 1.08 : 1))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.regular)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .fill(ColorTokens.Kid.surface)
        )
        .kidTileShadow()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(
            String(format: String(localized: "whoseTail.cue.a11y"), round.promptLyalya)
        ))
    }

    // MARK: - Options grid (карточки-варианты)

    private func optionsGrid(
        round: WhoseTailModels.Start.RoundViewModel
    ) -> some View {
        LazyVGrid(columns: KidGameTapScaffold<EmptyView>.twoColumnGrid, spacing: SpacingTokens.small) {
            ForEach(round.options) { option in
                optionCard(option)
            }
        }
    }

    private func optionCard(
        _ option: WhoseTailModels.Start.OptionViewModel
    ) -> some View {
        let isRevealed = holder.revealedOptionId == option.id
        let isHinted = holder.hintOptionId == option.id
        let isChosenMiss = holder.chosenOptionId == option.id
            && holder.lastFeedback != nil
            && holder.lastFeedback != .hit
        let state: KidGameCardState = {
            if isRevealed { return .correct }
            if isChosenMiss { return .wrong }
            if isHinted { return .selected }
            return .neutral
        }()
        return KidGameTapCard(
            symbol: option.imageAsset,
            word: option.word,
            state: state,
            isLocked: holder.lastFeedback == .hit,
            onTap: { Task { await chooseOption(option.id) } }
        )
        .accessibilityLabel(Text(option.accessibilityLabel))
        .accessibilityHint(Text("whoseTail.option.hint"))
    }

    // MARK: - Summary

    private func summarySection(
        _ summary: WhoseTailModels.Answer.SummaryViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp5) {
            Spacer()

            Image(systemName: summary.accuracyFraction >= 0.8
                ? "pawprint.circle.fill"
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
                    Text("whoseTail.summary.again")
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .fill(ColorTokens.Brand.primary)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("whoseTail.summary.again.hint"))

                Button {
                    exitGame()
                } label: {
                    Text("whoseTail.summary.done")
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
            Text("whoseTail.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Wiring

    private func setupAndStart(forceRestart: Bool = false) async {
        if interactor == nil {
            let presenter = WhoseTailPresenter(displayLogic: holder)
            let worker = WhoseTailWorker(childRepository: container.childRepository)
            let interactor = WhoseTailInteractor(
                childId: childId,
                worker: worker,
                hapticService: container.hapticService,
                adaptivePlanner: container.adaptivePlannerService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = WhoseTailRouter(dismissAction: { exitGame() })
        }
        _ = forceRestart
        await interactor?.start(request: .init(childId: childId, preferredSubtask: nil))
    }

    private func chooseOption(_ optionId: String) async {
        holder.chosenOptionId = optionId
        holder.attemptInRound += 1
        await interactor?.answer(
            request: .init(chosenOptionId: optionId, attemptInRound: holder.attemptInRound)
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview("WhoseTail / game") {
    WhoseTailView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
