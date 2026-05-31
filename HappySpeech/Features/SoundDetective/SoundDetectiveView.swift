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

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundDetective.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                // Детективная «прохлада» — kidCool mesh, ненавязчиво.
                // Reduced Motion: убираем анимированный/блендовый фон —
                // остаётся ровный Kid.bg (accessibility + детерминизм снимков).
                if !reduceMotion {
                    HSMeshGradientBackground(palette: .kidCool, animated: true)
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
            .navigationTitle(Text("soundDetective.title"))
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
                    .accessibilityLabel(Text("soundDetective.close.a11y"))
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
        round: SoundDetectiveModels.Start.RoundViewModel
    ) -> some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: SpacingTokens.sp4) {
                    progressHeader(round)

                    Spacer(minLength: 0)

                    // Ляля-детектив задаёт вопрос.
                    HSSpeechBubble(
                        holder.lastLyalyaLine ?? round.promptLyalya,
                        direction: .left,
                        style: holder.lastFeedback == nil ? .question : bubbleStyle(holder.lastFeedback)
                    )
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .id("bubble-\(round.id)-\(holder.lastFeedback?.rawValue ?? "q")")
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))

                    // Картинка-улика.
                    clueCard(round: round)
                        .id(round.id)
                        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))

                    // Кнопка «Ещё разок» — переслушать слово.
                    replayButton

                    Spacer(minLength: 0)

                    // Полоска слова: зоны-окошки + лупа.
                    wordStrip(round: round)
                        .padding(.horizontal, SpacingTokens.screenEdge)
                }
                .frame(minHeight: geo.size.height, alignment: .top)
                .padding(.top, SpacingTokens.sp2)
                .padding(.bottom, SpacingTokens.sp6)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaPadding(.bottom, SpacingTokens.small)
            .animation(reduceMotion ? nil : .spring(duration: 0.35), value: round.id)
        }
    }

    private func progressHeader(
        _ round: SoundDetectiveModels.Start.RoundViewModel
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

    private func clueCard(
        round: SoundDetectiveModels.Start.RoundViewModel
    ) -> some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp5) {
            VStack(spacing: SpacingTokens.sp3) {
                HSContentSymbol(round.imageAsset, size: 96, tint: ColorTokens.Brand.primary)
                Text(round.wordText)
                    .font(TypographyTokens.title(30))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(
            String(format: String(localized: "soundDetective.clue.a11y"), round.wordText)
        ))
    }

    private var replayButton: some View {
        Button {
            Task { await replayWord() }
        } label: {
            Label {
                Text("soundDetective.replay")
                    .font(TypographyTokens.body(15).weight(.medium))
            } icon: {
                Image(systemName: "speaker.wave.2.fill")
            }
            .foregroundStyle(ColorTokens.Brand.primary)
            .padding(.horizontal, SpacingTokens.sp4)
            .frame(minHeight: 44)
            .background(
                Capsule().fill(ColorTokens.Kid.surface)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("soundDetective.replay.a11y"))
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
                    dismiss()
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
            self.router = SoundDetectiveRouter(dismissAction: { dismiss() })
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
