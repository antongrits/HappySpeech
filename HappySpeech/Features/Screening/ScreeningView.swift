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
    @State private var state = ScreeningViewState()
    @State private var isSaving: Bool = false

    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()

            VStack(spacing: SpacingTokens.large) {
                header
                if state.isFinished, let outcome = state.outcome {
                    SummaryView(vm: outcome, isSaving: isSaving) {
                        complete(outcome: outcome.outcome)
                    }
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                } else if state.showBlockTransition, let blockTitle = state.blockTitle {
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
                    .id(stageVM.stageIndex)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .trailing)))
                } else {
                    ProgressView().progressViewStyle(.circular)
                }
                Spacer(minLength: 0)
            }
            .padding(SpacingTokens.screenEdge)
        }
        .task { await bootstrap() }
        .environment(\.circuitContext, .parent)
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(TypographyTokens.title(28))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .frame(width: 56, height: 56)
            }
            .accessibilityLabel(String(localized: "screening.header.cancel"))
            Spacer()
            if let progress = state.progressText {
                Text(progress)
                    .font(TypographyTokens.caption(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .accessibilityLabel(String(localized: "screening.accessibility.progress.\(progress)"))
            }
        }
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
        presenterInstance.display = ScreeningDisplayBridge(state: state) { newState in
            if newState.isFinished, let outcome = newState.outcome {
                capturedRouter.complete(outcome: outcome.outcome)
            }
        }

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
        HSLiquidGlassCard(style: .primary, padding: SpacingTokens.large) {
            VStack(spacing: SpacingTokens.medium) {
                if !vm.lyalyaPhrase.isEmpty {
                    Text(vm.lyalyaPhrase)
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .accessibilityLabel(vm.lyalyaPhrase)
                }

                Text(vm.targetWord)
                    .font(TypographyTokens.title(32))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.85)
                    .lineLimit(nil)
                    .accessibilityLabel(
                        String(localized: "screening.accessibility.word.\(vm.targetWord)")
                    )

                if !vm.targetSoundHint.isEmpty {
                    Text(vm.targetSoundHint)
                        .font(TypographyTokens.caption(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: SpacingTokens.medium) {
                    HSButton(
                        String(localized: "screening.prompt.listen"),
                        style: .secondary,
                        action: onPlay
                    )
                    .frame(minWidth: 56, minHeight: 56)
                    .accessibilityLabel(String(localized: "screening.accessibility.listen"))

                    if vm.showRecordButton {
                        recordButton
                    }
                }
                .frame(maxWidth: .infinity)

                if isRecording {
                    Text(recordingLabel)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .accessibilityLabel(String(localized: "screening.accessibility.recording"))
                }
            }
        }
    }

    private var recordButton: some View {
        Button(action: onRecord) {
            ZStack {
                Circle()
                    .fill(isRecording
                          ? ColorTokens.Brand.primary.opacity(0.25)
                          : ColorTokens.Kid.bg)
                    .frame(width: 56, height: 56)
                Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(TypographyTokens.display(34))
                    .foregroundStyle(isRecording ? ColorTokens.Brand.primary : ColorTokens.Kid.ink)
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.medium) {
                if !vm.lyalyaFinishPhrase.isEmpty {
                    Text(vm.lyalyaFinishPhrase)
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                Text(String(localized: "screening.complete"))
                    .font(TypographyTokens.title())
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)

                Text(vm.summaryText)
                    .font(TypographyTokens.body(16))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(nil)

                HSProgressBar(value: 1.0)
                    .accessibilityLabel(String(localized: "screening.accessibility.complete"))

                if vm.wasAdaptiveStopped {
                    Text(String(localized: "screening.adaptive_stop.info"))
                        .font(TypographyTokens.caption(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
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
                } else {
                    HSButton(
                        String(localized: "screening.summary.done"),
                        style: .primary,
                        action: onDone
                    )
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(String(localized: "screening.summary.done"))
                }
            }
            .padding(SpacingTokens.large)
        }
    }
}
