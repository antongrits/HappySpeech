import OSLog
import SwiftUI

// MARK: - VoicingSoftnessViewModelHolder

@MainActor
@Observable
final class VoicingSoftnessViewModelHolder: VoicingSoftnessDisplayLogic {

    var startVM: VoicingSoftnessModels.Start.ViewModel?
    var mode: VoicingSoftnessMode = .voicing

    // Sort-режимы
    var currentSort: VoicingSoftnessModels.Start.SortRoundViewModel?
    /// Зона, в которую ребёнок «уронил» токен в последней попытке.
    var droppedZone: VoicingZone?
    /// Верная зона (раскрытие на hit).
    var revealedZone: VoicingZone?

    // Trap-режим
    var currentTrap: VoicingSoftnessModels.Start.TrapRoundViewModel?
    var chosenOptionId: String?
    var correctOptionId: String?

    // Общее
    var lastFeedback: FeedbackTier?
    var lastLyalyaLine: String?
    var throatHint: String?
    var summary: VoicingSoftnessModels.Answer.SummaryViewModel?
    var isFinished: Bool = false
    var showCelebration: Bool = false
    var attemptInRound: Int = 0

    func displayStart(viewModel: VoicingSoftnessModels.Start.ViewModel) async {
        startVM = viewModel
        mode = viewModel.mode
        currentSort = viewModel.firstSort
        currentTrap = viewModel.firstTrap
        resetRoundState()
        isFinished = false
        summary = nil
        showCelebration = false
    }

    func displayAnswer(viewModel: VoicingSoftnessModels.Answer.ViewModel) async {
        lastFeedback = viewModel.feedback
        lastLyalyaLine = viewModel.lyalyaLine
        throatHint = viewModel.throatHint
        isFinished = viewModel.isFinished
        summary = viewModel.summary
        showCelebration = viewModel.summary?.showCelebration ?? false

        if viewModel.feedback == .hit {
            revealedZone = viewModel.correctZone
            correctOptionId = viewModel.correctOptionId
        } else {
            // На промахе в словах-ловушках раскрываем верную картинку (мягко).
            correctOptionId = viewModel.correctOptionId
        }

        if let next = viewModel.nextSort {
            currentSort = next
            resetRoundState()
            lastFeedback = nil
            lastLyalyaLine = nil
            throatHint = nil
        }
        if let next = viewModel.nextTrap {
            currentTrap = next
            resetRoundState()
            lastFeedback = nil
            lastLyalyaLine = nil
            throatHint = nil
        }
    }

    private func resetRoundState() {
        droppedZone = nil
        revealedZone = nil
        chosenOptionId = nil
        correctOptionId = nil
        attemptInRound = 0
    }
}

// MARK: - VoicingSoftnessView (Clean Swift: View)
//
// «Карта звонкости и мягкости» — детская игра дифференциации оппозиционных
// фонем по акустическим признакам. Три режима:
//   • voicing — звонкость/глухость: токен-звук в домик «Звонкий — гудит» /
//     «Глухой — молчит». Звонкий звук → дрожащее горлышко + реальная вибро-
//     отдача (HapticService) — метафора голоса.
//   • softness — твёрдость/мягкость: «Сердитый брат» (твёрдый) / «Ласковый
//     братик» (мягкий, мягко покачивается, off при Reduced Motion).
//   • trapWords — слова-ловушки: 2 картинки минимальной пары, выбрать по
//     услышанному; при ошибке — подсветка различающейся буквы + «потрогай
//     горлышко», без штрафа.
//
// Палитра: звонкий = Primary/коралл, глухой = нейтрально-серый (НЕ синий);
// твёрдый = коралл-силач, мягкий = Rose. Success-рамка = Mint (мелкий акцент),
// ошибка = Error мягкая обводка.
//
// Accessibility:
//   • Kid circuit: зоны/токен/картинки ≥ 56pt
//   • VoiceOver: токен, зоны, картинки — описательные labels
//   • Dynamic Type: lineLimit(nil) + minimumScaleFactor
//   • Reduced Motion: buzz/wiggle/drag → opacity/static; confetti → static
//   • Light + Dark: ColorTokens адаптируются

struct VoicingSoftnessView: View {

    let childId: String

    @State private var holder = VoicingSoftnessViewModelHolder()
    @State private var interactor: VoicingSoftnessInteractor?
    @State private var presenter: VoicingSoftnessPresenter?
    @State private var router: VoicingSoftnessRouter?

    @Environment(\.exitGame) private var exitGame
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "VoicingSoftness.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()

                if holder.isFinished, let summary = holder.summary {
                    VoicingSoftnessSummaryView(
                        summary: summary,
                        onAgain: { Task { await setupAndStart() } },
                        onDone: { exitGame() }
                    )
                } else if holder.mode == .trapWords, let trap = holder.currentTrap {
                    trapSection(round: trap)
                } else if let sort = holder.currentSort {
                    sortSection(round: sort)
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
            .task { await setupAndStart() }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Sort section (voicing / softness)

    private func sortSection(
        round: VoicingSoftnessModels.Start.SortRoundViewModel
    ) -> some View {
        KidGameTapScaffold(
            stepLabel: round.progressLabel,
            progress: round.progressFraction,
            promptText: holder.lastLyalyaLine ?? round.promptLyalya,
            mascotState: mascotState,
            feedback: currentFeedback,
            listen: KidGameListenAction(
                title: String(localized: "voicingSoftness.replay"),
                action: { Task { await replay(isVoiced: round.isVoiced) } }
            ),
            onClose: { exitGame() }
        ) {
            listenCard(token: round.token, isVoiced: round.isVoiced)
                .id(round.id)
                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))

            VoicingZoneRow(
                zones: presenterZones,
                droppedZone: holder.droppedZone,
                revealedZone: holder.revealedZone,
                reduceMotion: reduceMotion,
                onSelect: { zone in Task { await chooseZone(zone) } }
            )

            VoicingTokenRow(
                token: round.token,
                isVoiced: round.isVoiced,
                placed: holder.droppedZone != nil,
                accessibilityLabel: round.tokenAccessibilityLabel
            )

            if let hint = holder.throatHint {
                VoicingThroatHintCard(text: hint)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: round.id)
    }

    /// Зоны текущего раунда (от ViewModel; fallback на пересборку presenter'ом).
    private var presenterZones: [VoicingSoftnessModels.Start.ZoneViewModel] {
        VoicingSoftnessPresenter.zones(for: holder.mode)
    }

    // MARK: - Trap section (слова-ловушки)

    private func trapSection(
        round: VoicingSoftnessModels.Start.TrapRoundViewModel
    ) -> some View {
        KidGameTapScaffold(
            stepLabel: round.progressLabel,
            progress: round.progressFraction,
            promptText: holder.lastLyalyaLine ?? round.promptLyalya,
            mascotState: mascotState,
            feedback: currentFeedback,
            listen: KidGameListenAction(
                title: String(localized: "voicingSoftness.replay"),
                action: { Task { await replay(isVoiced: false) } }
            ),
            onClose: { exitGame() }
        ) {
            VoicingTrapAskCard(targetWord: round.targetWord)
                .id(round.id)

            VoicingPicksRow(
                options: round.options,
                chosenOptionId: holder.chosenOptionId,
                correctOptionId: holder.correctOptionId,
                feedback: holder.lastFeedback,
                reduceMotion: reduceMotion,
                onSelect: { id in Task { await chooseOption(id) } }
            )

            if let hint = holder.throatHint {
                VoicingThroatHintCard(text: hint)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: round.id)
    }

    // MARK: - Listen card (token to drag)

    private func listenCard(token: String, isVoiced: Bool) -> some View {
        VStack(spacing: SpacingTokens.small) {
            Text("voicingSoftness.listen.label")
                .font(TypographyTokens.caption(12).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text(verbatim: "[ \(token) ]")
                .font(TypographyTokens.title(40))
                .foregroundStyle(isVoiced ? ColorTokens.Brand.primary : ColorTokens.VoicingSoftness.voiceless)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityHidden(true)
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
            String(format: String(localized: "voicingSoftness.listen.a11y"), token)
        ))
    }

    // MARK: - Mascot / feedback mapping

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
        case .hit:    return KidGameFeedback(.correct, line)
        case .retry:  return KidGameFeedback(.hint, line)
        case .almost: return KidGameFeedback(.incorrect, line)
        }
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ProgressView().controlSize(.large)
            Text("voicingSoftness.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Wiring

    private func setupAndStart() async {
        if interactor == nil {
            let presenter = VoicingSoftnessPresenter(displayLogic: holder)
            let worker = VoicingSoftnessWorker(childRepository: container.childRepository)
            let interactor = VoicingSoftnessInteractor(
                childId: childId,
                worker: worker,
                hapticService: container.hapticService,
                adaptivePlanner: container.adaptivePlannerService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = VoicingSoftnessRouter(dismissAction: { exitGame() })
        }
        await interactor?.start(request: .init(childId: childId, preferredMode: nil))
    }

    private func chooseZone(_ zone: VoicingZone) async {
        // Блокируем повторный ввод только после раскрытия верной зоны (hit).
        guard holder.revealedZone == nil else { return }
        holder.droppedZone = zone
        holder.attemptInRound += 1
        await interactor?.answer(
            request: .init(chosenZone: zone, chosenOptionId: nil, attemptInRound: holder.attemptInRound)
        )
    }

    private func chooseOption(_ id: String) async {
        // После hit раунд продвигается (holder сбросит state); до тех пор —
        // повторные попытки разрешены (мягкая коррекция без штрафа).
        guard holder.lastFeedback != .hit else { return }
        holder.chosenOptionId = id
        holder.attemptInRound += 1
        await interactor?.answer(
            request: .init(chosenZone: nil, chosenOptionId: id, attemptInRound: holder.attemptInRound)
        )
    }

    /// Переслушать токен/слово. Звонкий → дополнительная виброотдача-метафора.
    private func replay(isVoiced: Bool) async {
        if isVoiced {
            await container.hapticService.play(pattern: .heartbeat)
        } else {
            container.hapticService.selection()
        }
        Self.logger.debug("Replay requested (voiced: \(isVoiced, privacy: .public))")
    }
}

// MARK: - Preview

#if DEBUG
#Preview("VoicingSoftness / game") {
    VoicingSoftnessView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
