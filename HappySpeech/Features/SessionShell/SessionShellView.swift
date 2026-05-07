import OSLog
import SwiftUI

// MARK: - SessionShellView
//
// Public entry point for an active therapy session.
//
// Архитектура:
//   SessionShellView
//     └─ SessionShellHost (owns VIP stack, bridges Interactor → State)
//          └─ SessionShellBinder (pure SwiftUI render)
//               ├─ SessionHUDView (HSLiquidGlassCard со счётчиком/прогрессом/сердечками/паузой)
//               ├─ Game content area (concrete game View)
//               ├─ FeedbackOverlayView (flash + shake + Ляля)
//               └─ PauseSheetView (motivational + 2 actions, exit-confirm alert)
//
// Полный VIP стек (Interactor / Presenter / Router + Adapter) живёт в
// `SessionShellHost`, который владеет lifecycle интерактора и зеркалит state в
// лёгкий `SessionShellState`, читаемый Binder'ом. Такой раздел держит
// SwiftUI-render чистым, а интерактор — reference-type `AnyObject`.

struct SessionShellView: View {

    let childId: String
    let targetSoundId: String
    let sessionType: SessionType

    let container: AppContainer
    let coordinator: AppCoordinator

    var body: some View {
        SessionShellHost(
            childId: childId,
            targetSoundId: targetSoundId,
            sessionType: sessionType,
            container: container,
            coordinator: coordinator
        )
    }
}

// MARK: - SessionShellFactory

@MainActor
enum SessionShellFactory {
    static func make(
        container: AppContainer,
        coordinator: AppCoordinator,
        childId: String,
        targetSoundId: String,
        sessionType: SessionType
    ) -> some View {
        SessionShellView(
            childId: childId,
            targetSoundId: targetSoundId,
            sessionType: sessionType,
            container: container,
            coordinator: coordinator
        )
    }
}

// MARK: - SessionShellHost

/// Owns the VIP stack and bridges Interactor state into SwiftUI via `SessionShellState`.
struct SessionShellHost: View {
    let childId: String
    let targetSoundId: String
    let sessionType: SessionType
    let container: AppContainer
    let coordinator: AppCoordinator

    @State private var interactor: SessionShellInteractor?
    @State private var presenter: SessionShellPresenter?
    @State private var router: SessionShellRouter?
    @State private var displayAdapter: SessionShellDisplayAdapter?
    @State private var shellState = SessionShellState()

    var body: some View {
        SessionShellBinder(
            state: $shellState,
            onComplete: { activityId, score in
                await interactor?.completeActivity(
                    SessionShellModels.CompleteActivity.Request(
                        activityId: activityId,
                        score: score,
                        durationSeconds: 0,
                        errorCount: score < 0.5 ? 1 : 0
                    )
                )
            },
            onPauseRequested: {
                shellState.isPaused = true
                interactor?.pauseSession(SessionShellModels.PauseSession.Request())
            },
            onResume: {
                shellState.isPaused = false
                interactor?.resumeSession()
            },
            onExitConfirmed: {
                await interactor?.endSessionEarly()
                router?.routeBack()
            },
            onSessionFinished: {
                router?.routeToResults(activities: shellState.activities)
            }
        )
        .task {
            guard interactor == nil else { return }
            let presenterInstance = SessionShellPresenter()
            let routerInstance = SessionShellRouter(coordinator: coordinator)
            let interactorInstance = SessionShellInteractor(
                contentService: container.contentService,
                adaptivePlannerService: container.adaptivePlannerService,
                sessionRepository: container.sessionRepository,
                hapticService: container.hapticService
            )
            let adapter = SessionShellDisplayAdapter(state: $shellState)
            interactorInstance.presenter = presenterInstance
            presenterInstance.display = adapter

            presenter = presenterInstance
            router = routerInstance
            displayAdapter = adapter
            interactor = interactorInstance

            await interactorInstance.startSession(
                SessionShellModels.StartSession.Request(
                    childId: childId,
                    targetSoundId: targetSoundId,
                    sessionType: sessionType
                )
            )
        }
        .onDisappear {
            guard let interactor else { return }
            Task { @MainActor in
                await interactor.endSessionEarly()
            }
        }
    }
}

// MARK: - SessionShellState

/// Snapshot of all UI-relevant data the Binder needs to render. Mirrored from
/// the Interactor through `SessionShellDisplayAdapter`.
struct SessionShellState {
    var activities: [SessionActivity] = []
    var currentIndex: Int = 0
    var totalSteps: Int = 0
    var rewardVM: RewardViewModel?
    var isShowingReward: Bool = false
    var isShowingFatigueAlert: Bool = false
    var isShowingPauseSheet: Bool = false
    var isShowingExitAlert: Bool = false
    var isPaused: Bool = false
    var feedbackState: SessionShellModels.FeedbackState = .none
    var fatigueHearts: Int = 3
    var mascotState: SessionShellModels.MascotState = .idle
    var motivationalPhrase: String = ""
    var sessionStartReference: Date = Date()
}

// MARK: - SessionShellBinder

/// Pure SwiftUI renderer. Receives state + callbacks, owns animations and a11y.
struct SessionShellBinder: View {
    @Binding var state: SessionShellState
    let onComplete: (String, Float) async -> Void
    let onPauseRequested: () -> Void
    let onResume: () -> Void
    let onExitConfirmed: () async -> Void
    let onSessionFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    var body: some View {
        ZStack(alignment: .top) {
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: SpacingTokens.regular) {
                SessionHUDView(
                    state: state,
                    onPauseTap: handlePauseTap
                )
                .padding(.horizontal, SpacingTokens.screenEdge)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityElement(children: .contain)
            }
            .padding(.vertical, SpacingTokens.large)

            if state.feedbackState != .none {
                FeedbackOverlayView(
                    state: state.feedbackState,
                    mascotState: state.mascotState
                )
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale))
                .zIndex(5)
                .allowsHitTesting(false)
            }

            if state.isShowingReward, let vm = state.rewardVM {
                rewardOverlay(vm)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .sheet(isPresented: $state.isShowingPauseSheet) {
            PauseSheetView(
                motivationalPhrase: state.motivationalPhrase,
                onResume: {
                    state.isShowingPauseSheet = false
                    onResume()
                },
                onExitTap: {
                    state.isShowingExitAlert = true
                }
            )
        }
        .alert(
            String(localized: "session.hud.exit_confirm"),
            isPresented: $state.isShowingExitAlert
        ) {
            Button(String(localized: "session.hud.exit"), role: .destructive) {
                state.isShowingExitAlert = false
                state.isShowingPauseSheet = false
                Task { await onExitConfirmed() }
            }
            Button(String(localized: "common.cancel"), role: .cancel) {
                state.isShowingExitAlert = false
            }
        } message: {
            Text(String(localized: "session.hud.exit_message"))
        }
        .alert(
            String(localized: "session.fatigue.alert.title"),
            isPresented: $state.isShowingFatigueAlert
        ) {
            Button(String(localized: "session.fatigue.stop")) {
                Task { await onExitConfirmed() }
            }
        } message: {
            Text(String(localized: "session.fatigue.alert.message"))
        }
        .onChange(of: state.feedbackState) { _, newValue in
            if newValue != .none {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(800))
                    state.feedbackState = .none
                }
            }
        }
    }

    // MARK: - Background

    /// Динамический градиент по типу текущей игры. Меняется плавно при смене
    /// activity (через `id` ниже).
    private var backgroundGradient: LinearGradient {
        let palette = state.activities.indices.contains(state.currentIndex)
            ? gradientPalette(for: state.activities[state.currentIndex].gameType)
            : (top: ColorTokens.Kid.bg, bottom: ColorTokens.Kid.bgSoft)
        return LinearGradient(
            colors: [palette.top, palette.bottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func gradientPalette(for type: GameType) -> (top: Color, bottom: Color) {
        switch type {
        case .listenAndChoose, .repeatAfterModel, .minimalPairs:
            return (ColorTokens.Brand.sky.opacity(0.18), ColorTokens.Kid.bgSoft)
        case .breathing, .rhythm:
            return (ColorTokens.Brand.mint.opacity(0.18), ColorTokens.Kid.bgSoft)
        case .narrativeQuest, .storyCompletion:
            return (ColorTokens.Brand.lilac.opacity(0.18), ColorTokens.Kid.bgSoft)
        case .arActivity, .articulationImitation, .visualAcoustic:
            return (ColorTokens.Brand.butter.opacity(0.18), ColorTokens.Kid.bgSoft)
        case .letterTracing:
            return (ColorTokens.Brand.sky.opacity(0.12), ColorTokens.Kid.bgSoft)
        default:
            return (ColorTokens.Kid.bgSoft, ColorTokens.Kid.bg)
        }
    }

    // MARK: - Pause handler

    private func handlePauseTap() {
        guard !state.isPaused else { return }
        container.hapticService.selection()
        state.isShowingPauseSheet = true
        onPauseRequested()
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if state.currentIndex >= state.totalSteps, state.totalSteps > 0 {
            sessionCompletedView
        } else if state.activities.indices.contains(state.currentIndex) {
            let activity = state.activities[state.currentIndex]
            gameView(for: activity)
                .id(activity.id)
        } else {
            ProgressView()
                .progressViewStyle(.circular)
        }
    }

    private var sessionCompletedView: some View {
        VStack(spacing: SpacingTokens.large) {
            HSMascotView(mood: .celebrating, size: 140)
            Text(String(localized: "session.completed.title"))
                .font(TypographyTokens.title(28))
                .foregroundStyle(ColorTokens.Kid.ink)
            HSButton(
                String(localized: "session.completed.cta"),
                style: .primary,
                icon: "chart.bar.fill"
            ) {
                onSessionFinished()
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
    }

    @ViewBuilder
    private func gameView(for activity: SessionActivity) -> some View {
        switch activity.gameType {
        case .listenAndChoose:
            ListenAndChooseView(activity: activity) { score in
                Task { await onComplete(activity.id, score) }
            }
        case .repeatAfterModel:
            RepeatAfterModelView(activity: activity) { score in
                Task { await onComplete(activity.id, score) }
            }
        case .breathing:
            BreathingView(
                activity: activity,
                onComplete: { score in Task { await onComplete(activity.id, score) } }
            )
        case .minimalPairs:
            MinimalPairsView(activity: activity) { score in
                Task { await onComplete(activity.id, score) }
            }
        case .soundHunter:
            SoundHunterView(activity: activity) { score in
                Task { await onComplete(activity.id, score) }
            }
        case .memory:
            MemoryView(activity: activity) { score in
                Task { await onComplete(activity.id, score) }
            }
        case .dragAndMatch:
            DragAndMatchView(activity: activity) { score in
                Task { await onComplete(activity.id, score) }
            }
        case .sorting:
            SortingView(activity: activity) { score in
                Task { await onComplete(activity.id, score) }
            }
        case .bingo:
            BingoView(activity: activity) { score in
                Task { await onComplete(activity.id, score) }
            }
        case .rhythm:
            RhythmView(activity: activity) { score in
                Task { await onComplete(activity.id, score) }
            }
        case .puzzleReveal:
            PuzzleRevealView(activity: activity) { score in
                Task { await onComplete(activity.id, score) }
            }
        case .storyCompletion:
            StoryCompletionView(activity: activity) { score in
                Task { await onComplete(activity.id, score) }
            }
        case .narrativeQuest:
            NarrativeQuestView(activity: activity) { score in
                Task { await onComplete(activity.id, score) }
            }
        case .articulationImitation:
            ArticulationImitationView(activity: activity) { score in
                Task { await onComplete(activity.id, score) }
            }
        case .visualAcoustic:
            VisualAcousticView(activity: activity) { score in
                Task { await onComplete(activity.id, score) }
            }
        case .objectHunt:
            ObjectHuntView(activity: activity) { score in
                Task { await onComplete(activity.id, score) }
            }
        case .letterTracing:
            LetterTracingView(activity: activity) { score in
                Task { await onComplete(activity.id, score) }
            }
        default:
            placeholderGame(for: activity)
        }
    }

    private func placeholderGame(for activity: SessionActivity) -> some View {
        VStack(spacing: SpacingTokens.medium) {
            Text(activity.gameType.localizedTitle)
                .font(TypographyTokens.title())
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, SpacingTokens.medium)
            Text(String(
                format: String(localized: "session.placeholder.target_sound %@"),
                activity.soundTarget
            ))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, SpacingTokens.medium)
            HSButton(
                String(localized: "general.done"),
                style: .primary,
                icon: "checkmark.circle.fill"
            ) {
                Task { await onComplete(activity.id, 0.9) }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
        .padding()
    }

    // MARK: - Reward overlay

    private func rewardOverlay(_ vm: RewardViewModel) -> some View {
        VStack(spacing: SpacingTokens.small) {
            Text(vm.emoji).font(TypographyTokens.kidDisplay(64)).accessibilityHidden(true)
            Text(vm.title)
                .font(TypographyTokens.title())
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(vm.subtitle)
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
        }
        .padding(SpacingTokens.large)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(ColorTokens.Kid.surface)
                .shadow(color: ColorTokens.Overlay.shadow, radius: 20, y: 8)
        )
        .padding(.top, SpacingTokens.xxLarge)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(vm.title). \(vm.subtitle)")
    }
}
