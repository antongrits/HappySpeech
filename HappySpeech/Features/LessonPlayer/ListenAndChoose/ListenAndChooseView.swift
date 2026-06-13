import OSLog
import SwiftUI

// MARK: - ListenAndChoosePhase

/// 4-фазный state machine для одного раунда «Слушай и выбирай»:
///
///   listening   — Ляля проигрывает целевое слово; кнопки выбора отключены
///   choosing    — карточки активны, ребёнок может ткнуть; stagger-anim
///   revealing   — показываем правильный ответ + флаш; кнопки disabled
///   nextItem    — короткая пауза перед загрузкой следующего раунда
enum ListenAndChoosePhase: Sendable, Equatable {
    case listening
    case choosing
    case revealing
    case nextItem
}

// MARK: - ListenAndChooseView

/// Production "Listen and Choose" game.
///
/// Contract with `SessionShell`: the parent provides a `SessionActivity` and an
/// `onComplete` closure that receives the final score [0.0 – 1.0]. The game
/// auto-loads a round on appear, handles up to 3 attempts per round, and then
/// calls `onComplete` once the round is finished.
///
/// UI: единый каркас `KidGameTapScaffold` (эталон kid-game-tap) — sound-chip +
/// шаг + прогресс-бар + крестик в шапке, маскот Ляля + коралловый пузырь-вопрос,
/// сетка `KidGameTapCard` 2×N (stagger-появление), строка обратной связи и
/// нижняя капсула «Послушать». Состояния карточки: neutral / selected /
/// correct (мятная галочка) / wrong (коралл-обводка + shake-намёк).
struct ListenAndChooseView: View {

    // MARK: Input

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    // MARK: VIP

    @State private var interactor: (any ListenAndChooseBusinessLogic)?
    @State private var presenter: ListenAndChoosePresenter?
    @State private var router: ListenAndChooseRouter?
    @Environment(AppContainer.self) private var container

    // MARK: State

    @State private var vm: ListenAndChooseModels.LoadRound.ViewModel?
    @State private var phase: ListenAndChoosePhase = .listening
    @State private var attemptsUsed: Int = 0
    @State private var selectedIndex: Int?
    @State private var feedbackText: String?
    @State private var feedbackIsCorrect: Bool?
    @State private var revealAnswer: Bool = false
    @State private var isPlayingSample: Bool = false
    @State private var visibleCardCount: Int = 0
    @State private var staggerTask: Task<Void, Never>?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // A-08 «Спокойный режим» — гасит shake/scale-фидбэк наравне с reduceMotion.
    @Environment(\.calmMode) private var calmMode

    /// A-08: объединённый флаг «без резкого движения» — reduceMotion ИЛИ calmMode.
    private var calmReduce: Bool { reduceMotion || calmMode }

    // MARK: Body

    var body: some View {
        Group {
            if let vm {
                KidGameTapScaffold(
                    soundLetter: soundLetter,
                    soundTitle: soundTitle,
                    stepLabel: vm.progressText,
                    progress: progressFraction(vm),
                    promptText: vm.instructionText,
                    mascotState: phase == .listening ? .singing : .pointing,
                    feedback: currentFeedback,
                    listen: KidGameListenAction(
                        isPlaying: isPlayingSample,
                        action: { replayWord(vm) }
                    )
                ) {
                    optionsGrid(vm)
                    if let hint = vm.hintText {
                        Text(hint)
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                ProgressView().progressViewStyle(.circular)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { await bootstrap() }
        .onDisappear {
            staggerTask?.cancel()
            staggerTask = nil
        }
    }

    // MARK: Scaffold mapping

    /// Буква звука для sound-chip — первый символ цели урока в верхнем регистре.
    private var soundLetter: String? {
        let raw = activity.soundTarget.trimmingCharacters(in: .whitespaces)
        guard let first = raw.first else { return nil }
        return String(first).uppercased()
    }

    private var soundTitle: String? {
        guard let letter = soundLetter else { return nil }
        return String(localized: "Звук \(letter)")
    }

    private func progressFraction(_ vm: ListenAndChooseModels.LoadRound.ViewModel) -> Double? {
        // progressText вида «N из M» → доля; если распарсить нельзя — без бара.
        guard let text = vm.progressText else { return nil }
        let nums = text.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        guard nums.count == 2, nums[1] > 0 else { return nil }
        return Double(nums[0]) / Double(nums[1])
    }

    private var currentFeedback: KidGameFeedback? {
        guard let text = feedbackText, let isCorrect = feedbackIsCorrect else { return nil }
        return KidGameFeedback(isCorrect ? .correct : .incorrect, text)
    }

    private func replayWord(_ vm: ListenAndChooseModels.LoadRound.ViewModel) {
        interactor?.replayCurrentWord(ListenAndChooseModels.ReplayWord.Request())
        playSample(targetWord: vm.targetWord)
    }

    // MARK: Options grid

    private func optionsGrid(_ vm: ListenAndChooseModels.LoadRound.ViewModel) -> some View {
        LazyVGrid(columns: KidGameTapScaffold<EmptyView>.twoColumnGrid, spacing: SpacingTokens.small) {
            ForEach(Array(vm.options.enumerated()), id: \.element.id) { idx, option in
                optionCard(option, index: idx, vm: vm)
                    .opacity(calmReduce || idx < visibleCardCount ? 1 : 0)
                    .offset(y: calmReduce || idx < visibleCardCount ? 0 : 12)
                    .animation(calmReduce ? nil : .spring(duration: 0.45), value: visibleCardCount)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func optionCard(
        _ option: ListenAndChooseModels.LoadRound.OptionViewModel,
        index: Int,
        vm: ListenAndChooseModels.LoadRound.ViewModel
    ) -> some View {
        let isSelected = selectedIndex == index
        let isCorrect = index == vm.correctIndex
        let shouldHighlightCorrect = revealAnswer && isCorrect
        let isWrongSelection = isSelected && feedbackIsCorrect == false && !revealAnswer
        let state: KidGameCardState = {
            if shouldHighlightCorrect { return .correct }
            if isWrongSelection { return .wrong }
            if isSelected { return .selected }
            return .neutral
        }()
        return KidGameTapCard(
            symbol: option.imageSystemName,
            word: option.word,
            state: state,
            isLocked: phase != .choosing || feedbackIsCorrect == true || revealAnswer,
            onTap: { selectOption(index: index, vm: vm) }
        )
        .accessibilityIdentifier("answerOption_\(index)")
    }

    // MARK: Actions

    private func bootstrap() async {
        guard interactor == nil else { return }
        let presenterInstance = ListenAndChoosePresenter()
        let routerInstance = ListenAndChooseRouter()
        routerInstance.onFinish = { score in onComplete(score) }
        let interactorInstance = ListenAndChooseInteractor(
            contentService: container.contentService
        )
        interactorInstance.presenter = presenterInstance
        // Use a class-bound bridge because SwiftUI struct can't conform to
        // AnyObject protocols. The bridge forwards display callbacks into
        // `@State` via closures.
        let bridge = ListenAndChooseDisplayBridge(
            onLoad: { new in
                vm = new
                onNewRoundLoaded(optionsCount: new.options.count)
            },
            onAttempt: { result in
                feedbackText = result.feedbackText
                feedbackIsCorrect = result.isCorrect
                revealAnswer = result.shouldRevealAnswer
                if result.shouldRevealAnswer || result.isCorrect {
                    phase = .revealing
                }
                if let finalScore = result.finalScore {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(800))
                        phase = .nextItem
                        onComplete(finalScore)
                    }
                }
            }
        )
        presenterInstance.display = bridge

        presenter = presenterInstance
        router = routerInstance
        interactor = interactorInstance

        await interactorInstance.loadRound(
            ListenAndChooseModels.LoadRound.Request(
                soundTarget: activity.soundTarget,
                difficulty: activity.difficulty
            )
        )
    }

    private func playSample(targetWord: String) {
        guard !isPlayingSample else { return }
        isPlayingSample = true
        phase = .listening
        container.hapticService.selection()
        // Production audio playback happens through AudioService.playAudio(url:);
        // a real asset URL is resolved from the ContentPack. Here we simulate timing.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            isPlayingSample = false
            phase = .choosing
        }
    }

    private func selectOption(index: Int, vm: ListenAndChooseModels.LoadRound.ViewModel) {
        guard phase == .choosing, feedbackIsCorrect != true, !revealAnswer else { return }
        selectedIndex = index
        attemptsUsed += 1
        container.hapticService.selection()

        interactor?.submitAttempt(
            ListenAndChooseModels.SubmitAttempt.Request(
                selectedIndex: index,
                correctIndex: vm.correctIndex,
                attemptsUsed: attemptsUsed
            )
        )
    }

    // MARK: - Stagger appearance

    /// Запускается каждый раз, когда Presenter присылает новый раунд.
    /// Карточки появляются по очереди с задержкой 0.1с × n.
    private func onNewRoundLoaded(optionsCount: Int) {
        // Reset round-local state
        selectedIndex = nil
        feedbackText = nil
        feedbackIsCorrect = nil
        revealAnswer = false
        attemptsUsed = 0
        phase = .listening
        visibleCardCount = 0

        guard !reduceMotion else {
            visibleCardCount = optionsCount
            phase = .choosing
            return
        }

        staggerTask?.cancel()
        staggerTask = Task { @MainActor in
            // Сначала проигрываем «слушаем» в течение 700мс, потом показываем карточки.
            try? await Task.sleep(for: .milliseconds(400))
            for idx in 0..<optionsCount {
                if Task.isCancelled { return }
                visibleCardCount = idx + 1
                try? await Task.sleep(for: .milliseconds(100))
            }
            if Task.isCancelled { return }
            phase = .choosing
        }
    }
}

// MARK: - Bridge

/// Class-bound bridge that mirrors display callbacks into SwiftUI `@State` via a closure.
@MainActor
final class ListenAndChooseDisplayBridge: ListenAndChooseDisplayLogic {
    let onLoad: (ListenAndChooseModels.LoadRound.ViewModel) -> Void
    let onAttempt: (ListenAndChooseModels.SubmitAttempt.ViewModel) -> Void

    init(
        onLoad: @escaping (ListenAndChooseModels.LoadRound.ViewModel) -> Void,
        onAttempt: @escaping (ListenAndChooseModels.SubmitAttempt.ViewModel) -> Void
    ) {
        self.onLoad = onLoad
        self.onAttempt = onAttempt
    }

    func displayLoadRound(_ viewModel: ListenAndChooseModels.LoadRound.ViewModel) {
        onLoad(viewModel)
    }

    func displaySubmitAttempt(_ viewModel: ListenAndChooseModels.SubmitAttempt.ViewModel) {
        onAttempt(viewModel)
    }
}
