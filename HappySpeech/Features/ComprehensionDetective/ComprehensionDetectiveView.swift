import OSLog
import SwiftUI

// MARK: - ComprehensionDetectiveViewModelHolder

@MainActor
@Observable
final class ComprehensionDetectiveViewModelHolder: ComprehensionDetectiveDisplayLogic {

    var startVM: ComprehensionDetectiveModels.Start.ViewModel?
    var currentRound: ComprehensionDetectiveModels.Start.RoundViewModel?
    var lastFeedback: FeedbackTier?
    var lastLyalyaLine: String?
    /// id картинки, выбранной в последней попытке (для подсветки промаха).
    var chosenPictureId: String?
    /// id правильной картинки для пульсации-подсказки (после 2 промахов).
    var hintPictureId: String?
    var summary: ComprehensionDetectiveModels.Pick.SummaryViewModel?
    var isFinished: Bool = false
    var showCelebration: Bool = false
    /// Счётчик попыток в текущем раунде (для номера попытки в Request).
    var attemptInRound: Int = 0

    func displayStart(viewModel: ComprehensionDetectiveModels.Start.ViewModel) async {
        self.startVM = viewModel
        self.currentRound = viewModel.firstRound
        resetRoundState()
        self.isFinished = false
        self.summary = nil
        self.showCelebration = false
        self.lastFeedback = nil
        self.lastLyalyaLine = nil
    }

    func displayPick(viewModel: ComprehensionDetectiveModels.Pick.ViewModel) async {
        self.lastFeedback = viewModel.feedback
        self.lastLyalyaLine = viewModel.lyalyaLine
        self.hintPictureId = viewModel.hintPictureId
        self.isFinished = viewModel.isFinished
        self.summary = viewModel.summary
        self.showCelebration = viewModel.summary?.showCelebration ?? false

        if let next = viewModel.nextRound {
            // Новый раунд — стираем состояние предыдущего.
            self.currentRound = next
            resetRoundState()
            self.lastFeedback = nil
            self.lastLyalyaLine = nil
        }
    }

    private func resetRoundState() {
        self.chosenPictureId = nil
        self.hintPictureId = nil
        self.attemptInRound = 0
    }
}

// MARK: - ComprehensionDetectiveView (Clean Swift: View)
//
// v31 Волна B, Функция Ф.2 «Понимание-детектив» (F2-014).
//
// Детская игра на понимание устной инструкции. Ляля-сыщик проговаривает
// инструкцию (TTS), ребёнок видит 4 картинки в сетке 2×2 и тапает ту, что
// соответствует инструкции. Сессия из фиксированного числа раундов разной
// грамматической сложности (одно/два/три поручения, предлоги, перевёртыши).
//
// Accessibility:
//   • Kid circuit: картинки ≥ 120pt, кнопки ≥ 56pt.
//   • VoiceOver: инструкция и каждая картинка озвучены подписями; объявление
//     обратной связи после ответа.
//   • Dynamic Type: инструкция multiline + minimumScaleFactor.
//   • Reduced Motion: фон без анимации; подсветка/пульсация без spring;
//     confetti → static.
//   • Light + Dark: ColorTokens.Kid + Brand адаптируются.

struct ComprehensionDetectiveView: View {

    let childId: String
    let preferredTier: GrammarTier?

    @State private var holder = ComprehensionDetectiveViewModelHolder()
    @State private var interactor: ComprehensionDetectiveInteractor?
    @State private var presenter: ComprehensionDetectivePresenter?
    @State private var router: ComprehensionDetectiveRouter?
    @State private var pickInFlight = false

    @Environment(\.exitGame) private var exitGame
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    init(childId: String, preferredTier: GrammarTier? = nil) {
        self.childId = childId
        self.preferredTier = preferredTier
    }

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ComprehensionDetective.View"
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
        round: ComprehensionDetectiveModels.Start.RoundViewModel
    ) -> some View {
        KidGameTapScaffold(
            stepLabel: round.progressLabel,
            progress: round.progressFraction,
            promptText: holder.lastLyalyaLine ?? round.instruction,
            mascotState: mascotState,
            feedback: currentFeedback,
            listen: KidGameListenAction(action: { Task { await replayInstruction() } }),
            onClose: { exitGame() }
        ) {
            tierBadge(round)
            picturesGrid(round)
                .id(round.id)
                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: round.id)
    }

    private var mascotState: LyalyaState {
        switch holder.lastFeedback {
        case .hit:   return .celebrating
        case .retry: return .encouraging
        case .almost, .none: return .explaining
        }
    }

    private var currentFeedback: KidGameFeedback? {
        guard let line = holder.lastLyalyaLine, let fb = holder.lastFeedback else { return nil }
        switch fb {
        case .hit:   return KidGameFeedback(.correct, line)
        case .retry: return KidGameFeedback(.hint, line)
        case .almost: return KidGameFeedback(.incorrect, line)
        }
    }

    private func tierBadge(
        _ round: ComprehensionDetectiveModels.Start.RoundViewModel
    ) -> some View {
        Text(round.tierLabel)
            .font(TypographyTokens.caption(12).weight(.medium))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, SpacingTokens.small)
            .padding(.vertical, SpacingTokens.micro)
            .background(Capsule().fill(ColorTokens.Kid.surfaceAlt))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(Text(round.tierHint))
    }

    // MARK: - Pictures grid (2×2)

    private func picturesGrid(
        _ round: ComprehensionDetectiveModels.Start.RoundViewModel
    ) -> some View {
        LazyVGrid(columns: KidGameTapScaffold<EmptyView>.twoColumnGrid, spacing: SpacingTokens.small) {
            ForEach(round.pictures) { picture in
                pictureTile(picture)
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: holder.hintPictureId)
    }

    private func pictureTile(
        _ picture: ComprehensionDetectiveModels.Start.PictureViewModel
    ) -> some View {
        let isHinted = holder.hintPictureId == picture.id
        let isChosenMiss = holder.chosenPictureId == picture.id
            && holder.lastFeedback != nil
            && holder.lastFeedback != .hit
        let isRevealedHit = holder.lastFeedback == .hit
            && holder.chosenPictureId == picture.id
        let state: KidGameCardState = {
            if isRevealedHit { return .correct }
            if isChosenMiss { return .wrong }
            if isHinted { return .selected }
            return .neutral
        }()
        return KidGameTapCard(
            symbol: picture.symbolName,
            state: state,
            isLocked: holder.lastFeedback == .hit,
            onTap: { Task { await pick(picture) } }
        )
        .accessibilityLabel(Text(picture.accessibilityLabel))
        .accessibilityHint(Text("detective.tile.hint"))
    }

    // MARK: - Summary

    private func summarySection(
        _ summary: ComprehensionDetectiveModels.Pick.SummaryViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp5) {
            Spacer()

            Image(systemName: summary.accuracyFraction >= 0.8
                ? "magnifyingglass.circle.fill"
                : "hand.thumbsup.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(ColorTokens.Brand.gold)
                .hsSymbolEffect(.bounce, value: summary.scoreText)
                .accessibilityHidden(true)

            Text(summary.title)
                .font(TypographyTokens.title(26))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
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
                    Task { await restart() }
                } label: {
                    Text("detective.summary.again")
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .fill(ColorTokens.Brand.primary)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("detective.summary.again.hint"))

                Button {
                    exitGame()
                } label: {
                    Text("detective.summary.done")
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
            Text("detective.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Wiring

    private func setupAndStart() async {
        if interactor == nil {
            let presenter = ComprehensionDetectivePresenter(displayLogic: holder)
            let worker = ComprehensionDetectiveWorker(childRepository: container.childRepository)
            let interactor = ComprehensionDetectiveInteractor(
                childId: childId,
                worker: worker,
                hapticService: container.hapticService,
                adaptivePlanner: container.adaptivePlannerService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = ComprehensionDetectiveRouter(dismissAction: { exitGame() })
        }
        await interactor?.start(request: .init(childId: childId, preferredTier: preferredTier))
    }

    private func restart() async {
        // Уровень следующей сессии — рекомендованный (≥80% → ступень выше).
        let nextTier = interactor?.recommendedNextTier ?? preferredTier
        await interactor?.start(request: .init(childId: childId, preferredTier: nextTier))
    }

    private func pick(
        _ picture: ComprehensionDetectiveModels.Start.PictureViewModel
    ) async {
        guard !pickInFlight else { return }
        pickInFlight = true
        defer { pickInFlight = false }
        holder.chosenPictureId = picture.id
        holder.attemptInRound += 1
        await interactor?.pick(
            request: .init(pictureId: picture.id, attemptInRound: holder.attemptInRound)
        )
    }

    private func replayInstruction() async {
        guard let round = holder.currentRound else { return }
        await ComprehensionDetectiveWorker(childRepository: container.childRepository)
            .voiceInstruction(round.instruction, slowly: false)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("ComprehensionDetective / game") {
    ComprehensionDetectiveView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
