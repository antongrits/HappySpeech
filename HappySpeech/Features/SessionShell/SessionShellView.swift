import SwiftUI
import OSLog

// MARK: - SessionShellView

/// Public entry point for an active therapy session.
///
/// The full VIP stack (Interactor / Presenter / Router + Adapter) is wired inside
/// `SessionShellHost` which owns lifecycle of the interactor and mirrors state into
/// a lightweight `SessionShellState` used by `SessionShellBinder`. This split keeps
/// the SwiftUI render pure while the interactor remains a reference-type `AnyObject`.
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
            onPauseToggle: { wasPaused in
                if wasPaused {
                    interactor?.resumeSession()
                } else {
                    interactor?.pauseSession(SessionShellModels.PauseSession.Request())
                }
            },
            onEndEarly: {
                await interactor?.endSessionEarly()
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
    }
}

// MARK: - SessionShellState

struct SessionShellState {
    var activities: [SessionActivity] = []
    var currentIndex: Int = 0
    var totalSteps: Int = 0
    var rewardVM: RewardViewModel?
    var isShowingReward: Bool = false
    var isShowingFatigueAlert: Bool = false
    var isPaused: Bool = false
}

// MARK: - SessionShellBinder

/// Pure SwiftUI renderer. Receives state + callbacks, owns animations and a11y.
struct SessionShellBinder: View {
    @Binding var state: SessionShellState
    let onComplete: (String, Float) async -> Void
    let onPauseToggle: (Bool) -> Void
    let onEndEarly: () async -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            ColorTokens.Kid.bg.ignoresSafeArea()

            VStack(spacing: SpacingTokens.regular) {
                header
                    .padding(.horizontal, SpacingTokens.screenEdge)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityElement(children: .contain)
            }
            .padding(.vertical, SpacingTokens.large)

            if state.isShowingReward, let vm = state.rewardVM {
                rewardOverlay(vm)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .alert(
            String(localized: "Пора отдохнуть"),
            isPresented: $state.isShowingFatigueAlert
        ) {
            Button(String(localized: "Закончить")) {
                Task { await onEndEarly() }
            }
        } message: {
            Text(String(localized: "Ты отлично поработал! Давай продолжим чуть позже."))
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: SpacingTokens.small) {
            HStack(spacing: SpacingTokens.tiny) {
                HSMascotView(mood: .encouraging, size: 48)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(String(localized: "Шаг \(state.currentIndex + 1) из \(max(state.totalSteps, 1))"))
                        .font(TypographyTokens.caption())
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                    HSProgressBar(
                        value: state.totalSteps > 0
                            ? Double(state.currentIndex) / Double(state.totalSteps)
                            : 0
                    )
                    .frame(width: 160, height: 8)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(
                localized: "Прогресс: шаг \(state.currentIndex + 1) из \(max(state.totalSteps, 1))"
            ))

            Spacer()

            Button {
                let wasPaused = state.isPaused
                state.isPaused.toggle()
                onPauseToggle(wasPaused)
            } label: {
                Image(systemName: state.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .padding(SpacingTokens.small)
                    .background(Circle().fill(ColorTokens.Kid.surface))
            }
            .accessibilityLabel(state.isPaused
                ? String(localized: "Продолжить занятие")
                : String(localized: "Пауза"))
            .accessibilityAddTraits(.isButton)
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if state.currentIndex >= state.totalSteps, state.totalSteps > 0 {
            VStack(spacing: SpacingTokens.large) {
                HSMascotView(mood: .celebrating, size: 140)
                Text(String(localized: "Занятие завершено!"))
                    .font(TypographyTokens.title(28))
                    .foregroundStyle(ColorTokens.Kid.ink)
                HSButton(String(localized: "Итоги"), style: .primary) {
                    Task { await onEndEarly() }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
            }
        } else if state.activities.indices.contains(state.currentIndex) {
            let activity = state.activities[state.currentIndex]
            gameView(for: activity)
                .id(activity.id)
        } else {
            ProgressView()
                .progressViewStyle(.circular)
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
            BreathingView(activity: activity) { score in
                Task { await onComplete(activity.id, score) }
            }
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
        default:
            placeholderGame(for: activity)
        }
    }

    private func placeholderGame(for activity: SessionActivity) -> some View {
        VStack(spacing: SpacingTokens.medium) {
            Text(activity.gameType.localizedTitle)
                .font(TypographyTokens.title())
                .foregroundStyle(ColorTokens.Kid.ink)
            Text(String(localized: "Целевой звук: \(activity.soundTarget)"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
            HSButton(String(localized: "Отметить выполненным"), style: .primary) {
                Task { await onComplete(activity.id, 0.9) }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
        .padding()
    }

    // MARK: Reward overlay

    private func rewardOverlay(_ vm: RewardViewModel) -> some View {
        VStack(spacing: SpacingTokens.small) {
            Text(vm.emoji).font(.system(size: 64))
            Text(vm.title)
                .font(TypographyTokens.title())
                .foregroundStyle(ColorTokens.Kid.ink)
            Text(vm.subtitle)
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .padding(SpacingTokens.large)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(ColorTokens.Kid.surface)
                .shadow(color: .black.opacity(0.08), radius: 20, y: 8)
        )
        .padding(.top, SpacingTokens.xxLarge)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(vm.title). \(vm.subtitle)")
    }
}

// MARK: - SessionShellDisplayAdapter

/// Bridges the presenter (class, `AnyObject`) into SwiftUI `@State`.
@MainActor
final class SessionShellDisplayAdapter: SessionShellDisplayLogic {
    @Binding var state: SessionShellState

    init(state: Binding<SessionShellState>) {
        _state = state
    }

    func displayStartSession(_ viewModel: SessionShellModels.StartSession.ViewModel) {
        state.activities = viewModel.activities
        state.totalSteps = viewModel.totalSteps
        state.currentIndex = 0
    }

    func displayCompleteActivity(_ viewModel: SessionShellModels.CompleteActivity.ViewModel) {
        if viewModel.shouldShowReward, let reward = viewModel.reward {
            state.rewardVM = reward
            state.isShowingReward = true
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1.6))
                self?.state.isShowingReward = false
            }
        }
        if viewModel.shouldShowFatigueAlert {
            state.isShowingFatigueAlert = true
            return
        }
        if viewModel.shouldAdvance {
            state.currentIndex += 1
        } else {
            state.currentIndex = state.totalSteps
        }
    }

    func displayPauseSession(_ viewModel: SessionShellModels.PauseSession.ViewModel) {
        // pause state is mirrored by the Binder's button directly
    }
}

// MARK: - GameType helpers

extension GameType {
    var localizedTitle: String {
        switch self {
        case .listenAndChoose:       return String(localized: "Слушай и выбирай")
        case .repeatAfterModel:      return String(localized: "Повторяй за мной")
        case .minimalPairs:          return String(localized: "Похожие звуки")
        case .dragAndMatch:          return String(localized: "Перетащи и совмести")
        case .memory:                return String(localized: "Запомни пары")
        case .bingo:                 return String(localized: "Лото")
        case .breathing:             return String(localized: "Дышим правильно")
        case .rhythm:                return String(localized: "Ритм речи")
        case .sorting:               return String(localized: "Разложи по группам")
        case .puzzleReveal:          return String(localized: "Собери пазл")
        case .soundHunter:           return String(localized: "Охотник за звуком")
        case .narrativeQuest:        return String(localized: "Сказка")
        case .visualAcoustic:        return String(localized: "Вижу звук")
        case .storyCompletion:       return String(localized: "Закончи историю")
        case .articulationImitation: return String(localized: "Повтори движение")
        case .arActivity:            return String(localized: "AR-зеркало")
        }
    }
}
