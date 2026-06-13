import OSLog
import SwiftUI

// MARK: - ScreeningView
//
// Full-screen 10-sound diagnostic flow. Shows one word per stage, lets the
// child record their pronunciation, and privately scores it on-device.
//
// UX choices:
//   • One stage visible at a time — reduces cognitive load.
//   • Progress dots (10 stages) + block title.
//   • Lyalya encouragement phrase shown above each stage.
//   • Scores are NEVER shown to the child (only parent summary at the end).
//   • Touch targets ≥56pt for motor accessibility.
//   • Reduced Motion fallback for all transitions.

struct ScreeningView: View {

    let childId: String
    let childAge: Int
    let onFinish: (ScreeningOutcome) -> Void
    let onCancel: () -> Void

    @State private var interactor: ScreeningInteractor?
    @State private var presenter: ScreeningPresenter?
    @State private var router: ScreeningRouter?
    // Strong reference: presenter.display — weak, без strong-владельца bridge освободится
    // моментально и updates никогда не сработают.
    @State private var displayBridge: ScreeningDisplayBridge?
    @State private var state = ScreeningViewState()
    @State private var isSaving: Bool = false

    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg
                .ignoresSafeArea()

            HSMeshGradientBackground(palette: .kidWarm, animated: false)
                .ignoresSafeArea()
                .blendMode(.softLight)
                .accessibilityHidden(true)

            VStack(spacing: SpacingTokens.large) {
                header
                // Fix v33 P1 — экран screening заполнял только верх
                // (карточка «собака / Звук С» вверху, 60% низа пусто). Добавляем
                // Spacer сверху И снизу контентной карточки, чтобы она ехала к
                // вертикальному центру safe area. SummaryView сам ScrollView,
                // поэтому центрируется не через Spacer, а через frame.
                if state.isFinished, let outcome = state.outcome {
                    SummaryView(vm: outcome, isSaving: isSaving) {
                        complete(outcome: outcome.outcome)
                    }
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                } else {
                    Spacer(minLength: 0)
                    Group {
                        if state.showBlockTransition, let blockTitle = state.blockTitle {
                            BlockTransitionView(title: blockTitle) {
                                state.showBlockTransition = false
                            }
                        } else if state.showMicDenied {
                            MicDeniedView()
                        } else if let stageVM = state.currentStageVM {
                            StageCard(
                                vm: stageVM,
                                isRecording: state.isRecording,
                                recordingLabel: state.recordingTimerLabel,
                                onRecord: { startOrStop() },
                                onPlay: { replay(vm: stageVM) }
                            )
                            // Fix v34-polish — низ экрана выглядел пустовато
                            // (карточка узкая, прижата к центру по высоте Spacer'ами,
                            // но на ширину ничем не ограничена). Кап maxWidth 520pt
                            // удерживает карточку компактной и читаемой на iPad/Plus,
                            // а на SE/обычных iPhone она занимает доступную ширину —
                            // без overflow. Вертикальное центрирование — через Spacer'ы выше.
                            .frame(maxWidth: 520)
                            .id(stageVM.stageIndex)
                            .transition(
                                reduceMotion
                                    ? .opacity
                                    : .opacity.combined(with: .move(edge: .trailing))
                            )
                        } else {
                            ProgressView().progressViewStyle(.circular)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(SpacingTokens.screenEdge)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task { await bootstrap() }
        .environment(\.circuitContext, .parent)
    }

    // MARK: - Subviews

    private var header: some View {
        // Эталон screening «слово и запись»: круглая close-кнопка слева +
        // коралловый прогресс «Слово N из M» с коралловым треком. Маскот Ляля
        // живёт в карточке слова (say-row), а не в шапке — шапка спокойная.
        HStack(alignment: .center, spacing: SpacingTokens.small) {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(ColorTokens.Kid.surfaceAlt)
                            .overlay(Circle().strokeBorder(ColorTokens.Kid.line, lineWidth: 1))
                    )
            }
            .accessibilityLabel(String(localized: "screening.header.cancel"))

            VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                if let progress = state.progressText {
                    Text(progress)
                        .font(TypographyTokens.headline(15))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .accessibilityLabel(String(localized: "screening.accessibility.progress.\(progress)"))
                }
                HSProgressBar(value: progressFraction, style: .kid)
                    .accessibilityHidden(true)
            }
        }
    }

    /// Доля пройденного скрининга (0…1) для кораллового трека прогресса.
    private var progressFraction: Double {
        let total = max(1, state.prompts.count)
        return min(1.0, Double(state.currentIndex + 1) / Double(total))
    }

    // MARK: - Wiring

    private func bootstrap() async {
        guard interactor == nil else { return }
        let presenterInstance = ScreeningPresenter()
        let interactorInstance = ScreeningInteractor(
            realmActor: container.realmActor,
            audioService: container.audioService,
            pronunciationScorer: container.pronunciationService,
            asrService: container.asrService
        )
        let routerInstance = ScreeningRouter()

        interactorInstance.presenter = presenterInstance
        interactorInstance.router = routerInstance
        routerInstance.onComplete = { outcome in onFinish(outcome) }
        routerInstance.onRouteToParentHome = { [coordinator] in
            coordinator.navigate(to: .parentHome)
        }
        routerInstance.onCancel = onCancel

        self.interactor = interactorInstance
        self.presenter = presenterInstance
        self.router = routerInstance

        let capturedRouter = routerInstance
        let capturedInteractor = interactorInstance
        // Индекс последнего этапа, для которого уже запрошен prepareStage —
        // защита от повторных вызовов при каждом commit.
        var preparedStageIndex: Int = -1
        let bridge = ScreeningDisplayBridge(state: state) { newState in
            // Прокидываем обновлённое состояние в @State экрана — без этой
            // записи body не перерисовывается и экран вечно висит на
            // ProgressView (currentStageVM остаётся nil).
            state = newState
            if newState.isFinished, let outcome = newState.outcome {
                capturedRouter.complete(outcome: outcome.outcome)
                return
            }
            // Презентер сообщает только об индексе текущего этапа; сам этап
            // (target word, фраза Ляли) грузится отдельным запросом prepareStage.
            // Без этого currentStageVM остаётся nil и экран висит на спиннере.
            guard !newState.prompts.isEmpty,
                  newState.currentStageVM?.stageIndex != newState.currentIndex,
                  newState.currentIndex != preparedStageIndex else { return }
            preparedStageIndex = newState.currentIndex
            let nextIndex = newState.currentIndex
            Task { @MainActor in
                await capturedInteractor.prepareStage(.init(stageIndex: nextIndex))
            }
        }
        presenterInstance.display = bridge
        self.displayBridge = bridge

        // startScreening наполняет только список промптов и вызывает commit
        // через displayStartScreening — закрытие выше подхватит currentIndex=0
        // и запросит prepareStage для первого этапа. Без этого StageCard
        // никогда не появится и экран зависнет на ProgressView.
        await interactorInstance.startScreening(.init(childId: childId, childAge: childAge))
    }

    // MARK: - Actions

    private func startOrStop() {
        guard let stageVM = state.currentStageVM else { return }
        container.hapticService.selection()
        if state.isRecording {
            Task {
                await interactor?.stopRecordingAndScore(
                    .init(stageIndex: stageVM.stageIndex)
                )
                state.isRecording = false
            }
        } else {
            Task {
                await interactor?.startRecording(.init(stageIndex: stageVM.stageIndex))
            }
        }
    }

    private func replay(vm: ScreeningModels.PrepareStage.ViewModel) {
        container.hapticService.selection()
        let index = vm.stageIndex
        guard let prompt = state.prompts.indices.contains(index) ? state.prompts[index] : nil else { return }
        Task {
            await interactor?.replayReferenceAudio(.init(
                stageIndex: index,
                referenceAudioAsset: prompt.referenceAudio
            ))
        }
    }

    private func complete(outcome: ScreeningOutcome) {
        guard !isSaving else { return }
        isSaving = true
        let request = Self.makeCompleteRequest(from: outcome, childId: childId)
        // E.2 — Performance trace: screening complete (parent circuit, COPPA-safe).
        let screeningTrace = container.performanceMonitorService.trace(name: "screening_complete_trace")
        screeningTrace.start()
        Task {
            await interactor?.completeScreening(request)
            screeningTrace.stop()
            isSaving = false
            onFinish(outcome)
        }
    }

    // MARK: - Helpers

    /// Маппинг `ScreeningOutcome` → `CompleteRequest`. Severity выводится из
    /// количества звуков с verdict == .intervention:
    ///   0 — "mild", 1–2 — "moderate", 3+ — "severe".
    static func makeCompleteRequest(
        from outcome: ScreeningOutcome,
        childId: String,
        isRescreening: Bool = false
    ) -> ScreeningModels.CompleteRequest {
        let severity: String
        switch outcome.priorityTargetSounds.count {
        case 0:    severity = "mild"
        case 1, 2: severity = "moderate"
        default:   severity = "severe"
        }
        let packs = outcome.priorityTargetSounds.map { sound in
            "sound_\(sound.lowercased())_pack"
        }
        return ScreeningModels.CompleteRequest(
            childId: childId,
            severity: severity,
            problematicSounds: outcome.priorityTargetSounds,
            recommendedPacks: packs,
            notes: "",
            isRescreening: isRescreening
        )
    }
}

// MARK: - ScreeningViewState

struct ScreeningViewState: Equatable {
    var prompts: [ScreeningPrompt] = []
    var currentIndex: Int = 0
    var progressText: String?
    var blockTitle: String?
    var showBlockTransition: Bool = false
    var isFinished: Bool = false
    var outcome: ScreeningSummaryViewModel?
    var currentStageVM: ScreeningModels.PrepareStage.ViewModel?
    var isRecording: Bool = false
    var recordingTimerLabel: String = ""
    var showMicDenied: Bool = false
    var adaptiveStopMessage: String?
}

struct ScreeningSummaryViewModel: Equatable {
    let outcome: ScreeningOutcome
    let rows: [SoundVerdictViewModel]
    let recommendedSessionMinutes: Int
    let summaryText: String
    let wasAdaptiveStopped: Bool
    let lyalyaFinishPhrase: String
}

// MARK: - Display bridge

@MainActor
private final class ScreeningDisplayBridge: ScreeningDisplayLogic {
    private var state: ScreeningViewState
    private let commit: (ScreeningViewState) -> Void

    init(state: ScreeningViewState, commit: @escaping (ScreeningViewState) -> Void) {
        self.state = state
        self.commit = commit
    }

    func displayStartScreening(_ vm: ScreeningModels.StartScreening.ViewModel) {
        state.prompts = vm.prompts
        state.currentIndex = 0
        state.progressText = "1 / \(vm.prompts.count)"
        state.blockTitle = vm.prompts.first?.block.title
        commit(state)
    }

    func displayPrepareStage(_ vm: ScreeningModels.PrepareStage.ViewModel) {
        state.currentStageVM = vm
        state.currentIndex = vm.stageIndex
        state.progressText = "\(vm.stageIndex + 1) / \(vm.totalStages)"
        state.isRecording = false
        state.adaptiveStopMessage = nil
        commit(state)
    }

    func displayStartRecording(_ vm: ScreeningModels.StartRecording.ViewModel) {
        state.isRecording = true
        state.recordingTimerLabel = vm.timerLabelText
        commit(state)
    }

    func displaySubmitAnswer(_ vm: ScreeningModels.SubmitAnswer.ViewModel) {
        state.isRecording = false
        state.adaptiveStopMessage = vm.adaptiveStopMessage
        if let next = vm.nextPromptIndex {
            state.currentIndex = next
            state.progressText = "\(next + 1) / \(state.prompts.count)"
            if vm.shouldShowBlockTransition, state.prompts.indices.contains(next) {
                state.blockTitle = state.prompts[next].block.title
                state.showBlockTransition = true
            }
        }
        commit(state)
    }

    func displayFinishScreening(_ vm: ScreeningModels.FinishScreening.ViewModel) {
        // Build ScreeningOutcome stub for SummaryView from ViewModel data
        let perSound: [String: SoundVerdict] = Dictionary(
            uniqueKeysWithValues: vm.perSoundVerdicts.map { ($0.sound, $0.verdict) }
        )
        let outcome = ScreeningOutcome(
            childId: "",
            completedAt: Date(),
            perSound: perSound,
            priorityTargetSounds: vm.priorityTargetSounds,
            recommendedSessionDurationSec: vm.recommendedSessionMinutes * 60,
            initialStagePerSound: [:]
        )
        state.isFinished = true
        state.outcome = ScreeningSummaryViewModel(
            outcome: outcome,
            rows: vm.perSoundVerdicts,
            recommendedSessionMinutes: vm.recommendedSessionMinutes,
            summaryText: vm.outcomeSummary,
            wasAdaptiveStopped: vm.wasAdaptiveStopped,
            lyalyaFinishPhrase: vm.lyalyaFinishPhrase
        )
        commit(state)
    }

    func displayRecordingError(_ error: ScreeningModels.RecordingError) {
        state.isRecording = false
        // Ошибка показывается как toast — не блокируем пользователя
        commit(state)
    }

    func displayMicrophonePermission(_ viewModel: ScreeningModels.MicrophonePermission.ViewModel) {
        state.showMicDenied = !viewModel.isGranted
        commit(state)
    }

    func displayRescreeningCheck(_ viewModel: ScreeningModels.CheckRescreening.ViewModel) {
        // Re-screening warning — handled at a higher level (ParentHome sheet)
        commit(state)
    }
}

// MARK: - StageCard

private struct StageCard: View {
    let vm: ScreeningModels.PrepareStage.ViewModel
    let isRecording: Bool
    let recordingLabel: String
    let onRecord: () -> Void
    let onPlay: () -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.large) {
            // Карточка слова: картинка-диск + крупное слово + подсказка звука.
            HSLiquidGlassCard(style: .primary, padding: SpacingTokens.large) {
                VStack(spacing: SpacingTokens.medium) {
                    pictureDisc

                    Text(vm.targetWord)
                        .font(TypographyTokens.title(36))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.85)
                        .lineLimit(nil)
                        .tracking(2)
                        .accessibilityLabel(
                            String(localized: "screening.accessibility.word.\(vm.targetWord)")
                        )

                    if !vm.targetSoundHint.isEmpty {
                        Text(vm.targetSoundHint)
                            .font(TypographyTokens.caption(13))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                    }
                }
            }

            // Say-row: маленькая Ляля + инструкция «скажи слово вслух».
            HStack(spacing: SpacingTokens.small) {
                LyalyaMascotView(state: .encouraging, size: 40)
                    .accessibilityHidden(true)
                Text(sayRowText)
                    .font(TypographyTokens.body(16))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(sayRowText)

            // Mic-зона: крупная коралловая кнопка записи с мягким свечением.
            if vm.showRecordButton {
                VStack(spacing: SpacingTokens.small) {
                    recordButton
                    if isRecording {
                        Text(recordingLabel)
                            .font(TypographyTokens.headline(14))
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .accessibilityLabel(String(localized: "screening.accessibility.recording"))
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // Ghost-контролы: «Послушать» (коралл) + «Пропустить».
            listenButton
        }
    }

    private var sayRowText: String {
        isRecording
            ? String(localized: "screening.recording.inProgress")
            : String(localized: "screening.prompt.sayAloud")
    }

    // MARK: Picture disc

    @ViewBuilder
    private var pictureDisc: some View {
        ZStack {
            Circle()
                .fill(ColorTokens.Kid.surfaceAlt)
                .overlay(Circle().strokeBorder(ColorTokens.Kid.line, lineWidth: 1))
                .frame(width: 144, height: 144)

            if let asset = vm.imageAsset, !asset.isEmpty {
                HSContentSymbol(asset, size: 92, tint: ColorTokens.Brand.primary)
            } else {
                Image(systemName: "text.bubble.fill")
                    .font(TypographyTokens.kidDisplay(48))
                    .foregroundStyle(ColorTokens.Brand.primary.opacity(0.55))
            }
        }
        .accessibilityHidden(true)
    }

    // Fix v34-polish — раньше использовалась HSButton(.secondary), но под
    // parent-контуром (ScreeningView задаёт circuitContext = .parent) она
    // подхватывала Parent.accent — системно-синий iOS-link цвет, выбивавшийся
    // из тёплой бренд-палитры экрана. Заменено на кастомную кнопку с
    // ColorTokens.Brand.primary (коралл) и мягкой tinted-подложкой —
    // визуально согласовано с record-кнопкой и play-кнопками в других играх.
    private var listenButton: some View {
        Button(action: onPlay) {
            Label {
                Text(String(localized: "screening.prompt.listen"))
                    .font(TypographyTokens.cta())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } icon: {
                Image(systemName: "speaker.wave.2.fill")
            }
            .foregroundStyle(ColorTokens.Brand.primary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.button, style: .continuous)
                    .fill(ColorTokens.Brand.primary.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.button, style: .continuous)
                    .strokeBorder(ColorTokens.Brand.primary.opacity(0.4), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "screening.accessibility.listen"))
    }

    private var recordButton: some View {
        Button(action: onRecord) {
            ZStack {
                // Мягкое коралловое свечение под кнопкой записи.
                Circle()
                    .fill(ColorTokens.Brand.primary.opacity(isRecording ? 0.22 : 0.12))
                    .frame(width: 124, height: 124)
                    .blur(radius: 12)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 96, height: 96)
                    .overlay(
                        Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                    )

                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(TypographyTokens.display(38))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .hsSymbolEffect(.pulse, value: isRecording)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isRecording
                ? String(localized: "screening.accessibility.stop_recording")
                : String(localized: "screening.accessibility.start_recording")
        )
    }
}

// MARK: - MicDeniedView

private struct MicDeniedView: View {
    var body: some View {
        VStack(spacing: SpacingTokens.medium) {
            Image(systemName: "mic.slash.fill")
                .font(TypographyTokens.kidDisplay(52))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
            Text(String(localized: "screening.mic.denied.title"))
                .font(TypographyTokens.headline())
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
            Text(String(localized: "screening.mic.denied.message"))
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
            HSButton(String(localized: "screening.mic.denied.open_settings"), style: .primary) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .frame(maxWidth: 260)
        }
        .padding(SpacingTokens.large)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Block transition + Summary

private struct BlockTransitionView: View {
    let title: String
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.medium) {
            Image(systemName: "star.fill")
                .font(TypographyTokens.kidDisplay(52))
                .foregroundStyle(ColorTokens.Brand.primary)
                .hsSymbolEffect(.bounce, value: title)
            Text(String(localized: "screening.block.next"))
                .font(TypographyTokens.headline())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
            Text(title)
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
            HSButton(String(localized: "screening.continue"), style: .primary, action: onContinue)
                .frame(maxWidth: 240)
                .accessibilityLabel(String(localized: "screening.continue"))
        }
    }
}

private struct SummaryView: View {
    let vm: ScreeningSummaryViewModel
    let isSaving: Bool
    let onDone: () -> Void

    private var targetSounds: [String] { vm.outcome.priorityTargetSounds }

    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.medium) {
                LyalyaMascotView(state: .celebrating, size: 110)
                    .accessibilityHidden(true)

                Text(String(localized: "screening.complete"))
                    .font(TypographyTokens.title(28))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .accessibilityAddTraits(.isHeader)

                if !vm.lyalyaFinishPhrase.isEmpty {
                    Text(vm.lyalyaFinishPhrase)
                        .font(TypographyTokens.body(16))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .frame(maxWidth: .infinity)
                }

                resultCard

                disclaimerCard

                if vm.wasAdaptiveStopped {
                    Text(String(localized: "screening.adaptive_stop.info"))
                        .font(TypographyTokens.caption(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                }

                if isSaving {
                    HStack(spacing: SpacingTokens.small) {
                        ProgressView().progressViewStyle(.circular)
                        Text(String(localized: "screening.saving"))
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, SpacingTokens.small)
                } else {
                    HSButton(
                        String(localized: "screening.summary.done"),
                        style: .primary,
                        action: onDone
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, SpacingTokens.small)
                    .accessibilityLabel(String(localized: "screening.summary.done"))
                }
            }
            .padding(SpacingTokens.large)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: Result card

    private var resultCard: some View {
        HSLiquidGlassCard(style: .primary, padding: SpacingTokens.regular) {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                Text(String(localized: "screening.summary.targetSounds"))
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)

                if targetSounds.isEmpty {
                    // Все звуки в норме — тёплая ободряющая строка.
                    HStack(spacing: SpacingTokens.small) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(ColorTokens.Brand.gold)
                            .accessibilityHidden(true)
                        Text(String(localized: "screening.summary.allGood"))
                            .font(TypographyTokens.body(15))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .lineLimit(nil)
                    }
                } else {
                    FlowChips(items: targetSounds)
                }

                Text(vm.summaryText)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(nil)
                    .padding(.top, SpacingTokens.tiny)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Disclaimer (honest — not a diagnosis)

    private var disclaimerCard: some View {
        HStack(alignment: .top, spacing: SpacingTokens.small) {
            Image(systemName: "info.circle.fill")
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Brand.primary)
                .accessibilityHidden(true)
            Text(String(localized: "screening.summary.notDiagnosis"))
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.regular)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(ColorTokens.Kid.surfaceAlt)
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                        .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - FlowChips

/// Тёплые коралловые чипы целевых звуков для сводки скрининга.
private struct FlowChips: View {
    let items: [String]

    var body: some View {
        HStack(spacing: SpacingTokens.small) {
            ForEach(items, id: \.self) { sound in
                Text(String(format: String(localized: "screening.summary.soundChip"), sound))
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .padding(.horizontal, SpacingTokens.regular)
                    .padding(.vertical, SpacingTokens.tiny)
                    .background(
                        Capsule().fill(ColorTokens.Brand.primary.opacity(0.14))
                    )
            }
            Spacer(minLength: 0)
        }
    }
}
