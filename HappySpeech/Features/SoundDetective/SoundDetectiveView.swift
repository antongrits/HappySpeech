import OSLog
import SwiftUI

// MARK: - SoundDetectiveViewModelHolder

@MainActor
@Observable
final class SoundDetectiveViewModelHolder: SoundDetectiveDisplayLogic {

    var startVM: SoundDetectiveModels.Start.ViewModel?
    var currentRound: SoundDetectiveModels.Start.RoundViewModel?
    var lastFeedback: FeedbackTier?
    var lastLyalyaLine: String?
    /// Зона, которую ребёнок выбрал в последней попытке (для подсветки лупы).
    var chosenZone: SoundZone?
    /// Верная зона текущего раунда (подсветка на hit).
    var revealedZone: SoundZone?
    /// Зона-подсказка (пульсация после 2 промахов).
    var hintZone: SoundZone?
    var summary: SoundDetectiveModels.Answer.SummaryViewModel?
    var isFinished: Bool = false
    var showCelebration: Bool = false
    /// Счётчик попыток в текущем раунде (для номера попытки в Request).
    var attemptInRound: Int = 0

    func displayStart(viewModel: SoundDetectiveModels.Start.ViewModel) async {
        self.startVM = viewModel
        self.currentRound = viewModel.firstRound
        resetRoundState()
        self.isFinished = false
        self.summary = nil
        self.showCelebration = false
    }

    func displayAnswer(viewModel: SoundDetectiveModels.Answer.ViewModel) async {
        self.lastFeedback = viewModel.feedback
        self.lastLyalyaLine = viewModel.lyalyaLine
        self.hintZone = viewModel.hintZone
        self.isFinished = viewModel.isFinished
        self.summary = viewModel.summary
        self.showCelebration = viewModel.summary?.showCelebration ?? false

        if viewModel.feedback == .hit {
            self.revealedZone = viewModel.correctZone
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
        self.chosenZone = nil
        self.revealedZone = nil
        self.hintZone = nil
        self.attemptInRound = 0
    }
}

// MARK: - SoundDetectiveView (Clean Swift: View)
//
// F2-009 «Звуковой детектив» (Wave 2).
//
// Детская игра позиционного фонематического анализа: «Бюро находок звуков».
// Ляля-детектив задаёт вопрос, показывается картинка-улика и «полоска слова»
// из зон-окошек (начало · середина · конец · «звука нет»). Ребёнок тапает
// зону, куда «прячется» целевой звук; лупа перемещается в выбранное окошко.
//
// Accessibility:
//   • Kid circuit: окошки-зоны и лупа ≥ 56pt
//   • VoiceOver: улика, зоны и лупа — описательные labels; объявление
//     результата после ответа
//   • Dynamic Type: VStack + minimumScaleFactor(0.85) + lineLimit(nil)
//   • Reduced Motion: подпрыгивание звука / перенос лупы → opacity/scale без
//     spring; пульсация-подсказка → статичная обводка; confetti → static
//   • Light + Dark: ColorTokens.Kid + Brand адаптируются

struct SoundDetectiveView: View {

    let childId: String

    @State private var holder = SoundDetectiveViewModelHolder()
    @State private var interactor: SoundDetectiveInteractor?
    @State private var presenter: SoundDetectivePresenter?
    @State private var router: SoundDetectiveRouter?

    @Environment(\.exitGame) private var exitGame
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundDetective.View"
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
        round: SoundDetectiveModels.Start.RoundViewModel
    ) -> some View {
        KidGameTapScaffold(
            stepLabel: round.progressLabel,
            progress: round.progressFraction,
            promptText: holder.lastLyalyaLine ?? round.promptLyalya,
            mascotState: mascotState,
            feedback: currentFeedback,
            listen: KidGameListenAction(
                title: String(localized: "soundDetective.replay"),
                action: { Task { await replayWord() } }
            ),
            onClose: { exitGame() }
        ) {
            clueCard(round: round)
                .id(round.id)
                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            wordStrip(round: round)
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: round.id)
    }

    private var mascotState: LyalyaState {
        switch holder.lastFeedback {
        case .hit:   return .celebrating
        case .retry: return .encouraging
        case .almost, .none: return .pointing
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

    private func clueCard(
        round: SoundDetectiveModels.Start.RoundViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.small) {
            HSContentSymbol(round.imageAsset, size: 84, tint: ColorTokens.Brand.primary)
                .frame(width: 110, height: 110)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .fill(ColorTokens.Kid.surfaceAlt)
                )
            Text(round.wordText)
                .font(TypographyTokens.title(30))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(nil)
                .minimumScaleFactor(0.6)
                .multilineTextAlignment(.center)
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
            String(format: String(localized: "soundDetective.clue.a11y"), round.wordText)
        ))
    }

    // MARK: - Word strip (zones + magnifier)

    private func wordStrip(
        round: SoundDetectiveModels.Start.RoundViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp3) {
            // Лупа-подсказка над полоской.
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "magnifyingglass")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(ColorTokens.Brand.gold)
                    .accessibilityHidden(true)
                Text("soundDetective.magnifier.hint")
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("soundDetective.magnifier.a11y"))

            HStack(spacing: SpacingTokens.sp2) {
                ForEach(round.zones) { zone in
                    zoneWindow(zone, round: round)
                }
            }
        }
    }

    private func zoneWindow(
        _ zone: SoundDetectiveModels.Start.ZoneViewModel,
        round: SoundDetectiveModels.Start.RoundViewModel
    ) -> some View {
        let isRevealed = holder.revealedZone == zone.id
        let isHinted = holder.hintZone == zone.id
        let isChosenMiss = holder.chosenZone == zone.id
            && holder.lastFeedback != nil
            && holder.lastFeedback != .hit

        return Button {
            Task { await chooseZone(zone.id) }
        } label: {
            VStack(spacing: SpacingTokens.sp1) {
                // Лупа «садится» в выбранное окно.
                Image(systemName: holder.chosenZone == zone.id ? "magnifyingglass" : zoneIcon(zone.colorHint))
                    .font(.title2)
                    .foregroundStyle(zoneTint(zone.colorHint, isRevealed: isRevealed))
                    .scaleEffect(reduceMotion ? 1 : (isRevealed ? 1.18 : 1))
                    .accessibilityHidden(true)

                Text(zone.label)
                    .font(TypographyTokens.caption(13).weight(.medium))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.vertical, SpacingTokens.sp2)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(zoneBackground(zone.colorHint, isRevealed: isRevealed, isMiss: isChosenMiss))
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .stroke(
                        isHinted ? ColorTokens.Brand.lilac : Color.clear,
                        lineWidth: isHinted ? 3 : 0
                    )
            )
            .depthShadow(ShadowTokens.kidDepth)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(zone.accessibilityLabel))
        .accessibilityHint(Text("soundDetective.zone.hint"))
        .accessibilityAddTraits(isRevealed ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Summary

    private func summarySection(
        _ summary: SoundDetectiveModels.Answer.SummaryViewModel
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
                    Text("soundDetective.summary.again")
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .fill(ColorTokens.Brand.primary)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("soundDetective.summary.again.hint"))

                Button {
                    exitGame()
                } label: {
                    Text("soundDetective.summary.done")
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
            Text("soundDetective.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Zone styling

    private func zoneIcon(_ hint: SoundDetectiveModels.Start.ZoneColorHint) -> String {
        switch hint {
        case .start:  return "arrow.left.circle.fill"
        case .middle: return "circle.circle.fill"
        case .end:    return "arrow.right.circle.fill"
        case .absent: return "nosign"
        }
    }

    private func zoneTint(
        _ hint: SoundDetectiveModels.Start.ZoneColorHint,
        isRevealed: Bool
    ) -> Color {
        if isRevealed { return ColorTokens.Brand.mint }
        switch hint {
        case .start:  return ColorTokens.Brand.mint
        case .middle: return ColorTokens.Brand.butter
        case .end:    return ColorTokens.Brand.rose
        case .absent: return ColorTokens.Kid.inkMuted
        }
    }

    private func zoneBackground(
        _ hint: SoundDetectiveModels.Start.ZoneColorHint,
        isRevealed: Bool,
        isMiss: Bool
    ) -> Color {
        if isRevealed { return ColorTokens.Brand.mint.opacity(0.28) }
        if isMiss { return ColorTokens.Kid.surfaceAlt }
        return ColorTokens.Kid.surface
    }

    // MARK: - Wiring

    private func setupAndStart(forceRestart: Bool = false) async {
        if interactor == nil {
            let presenter = SoundDetectivePresenter(displayLogic: holder)
            let worker = SoundDetectiveWorker(childRepository: container.childRepository)
            let interactor = SoundDetectiveInteractor(
                childId: childId,
                worker: worker,
                hapticService: container.hapticService,
                adaptivePlanner: container.adaptivePlannerService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = SoundDetectiveRouter(dismissAction: { exitGame() })
        }
        _ = forceRestart
        await interactor?.start(request: .init(childId: childId, preferredLevel: nil))
    }

    private func chooseZone(_ zone: SoundZone) async {
        holder.chosenZone = zone
        holder.attemptInRound += 1
        await interactor?.answer(
            request: .init(chosenZone: zone, attemptInRound: holder.attemptInRound)
        )
    }

    private func replayWord() async {
        // Переслушать слово (озвучка слова с интонационным выделением). Аудио-
        // пайплайн — Lyalya TTS-паки; здесь хаптика подтверждает нажатие.
        container.hapticService.selection()
        Self.logger.debug("Replay word requested")
    }
}

// MARK: - Preview

#if DEBUG
#Preview("SoundDetective / game") {
    SoundDetectiveView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
