import SwiftUI

// MARK: - ArticulationImitationView
//
// "Повтори артикуляцию": 5 артикуляционных упражнений подряд. Ребёнок
// смотрит на картинку + инструкцию, нажимает «Начать», удерживает позу
// 3 секунды (таймер в интеракторе). При успехе — звезда, при отпускании
// раньше таймера — нежный feedback "Почти!" без звезды.
//
// Source of truth для UI — `ArticulationImitationDisplay` (@Observable).
// Presenter пишет в store через bridge, View реагирует через SwiftUI.
//
// Жизненный цикл:
//   .task → interactor.loadSession → bridge выставляет phase=loading →
//   View видит loading, затем просит interactor.startExercise(0) →
//   bridge → phase=exercisePreview → ... → completed → pendingFinalScore
//   → onComplete(score)

struct ArticulationImitationView: View {

    // MARK: - API

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Store + VIP stack

    @State private var display: ArticulationImitationDisplay
    private let interactor: ArticulationImitationInteractor
    private let presenter: ArticulationImitationPresenter
    private let bridge: ArticulationImitationStoreBridge

    // Mascot bounce state (только визуал, не часть VIP)
    @State private var isPulsing: Bool = false
    @State private var sessionStarted: Bool = false

    // MARK: - Init

    init(activity: SessionActivity, onComplete: @escaping (Float) -> Void) {
        self.activity = activity
        self.onComplete = onComplete

        let display = ArticulationImitationDisplay()
        let interactor = ArticulationImitationInteractor()
        let presenter = ArticulationImitationPresenter()
        let bridge = ArticulationImitationStoreBridge(display: display)

        interactor.presenter = presenter
        presenter.viewModel = bridge

        self._display = State(initialValue: display)
        self.interactor = interactor
        self.presenter = presenter
        self.bridge = bridge
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()
            content
        }
        .task { startSessionOnce() }
        .onChange(of: display.pendingFinalScore) { _, newScore in
            if let newScore { onComplete(newScore) }
        }
        .onDisappear {
            interactor.cancel()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "articulation.screen.a11y"))
    }

    // MARK: - Content router

    @ViewBuilder
    private var content: some View {
        switch display.phase {
        case .loading:
            loadingView
        case .exercisePreview:
            exercisePreviewView
        case .holding:
            holdingView
        case .feedback:
            feedbackView
        case .completed:
            completedView
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: SpacingTokens.medium) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.4)
            Text(String(localized: "articulation.loading"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
    }

    // MARK: - Preview (instruction)

    private var exercisePreviewView: some View {
        VStack(spacing: SpacingTokens.large) {
            header
            Spacer(minLength: 0)
            if let pose = display.currentPose {
                poseCard(pose)
            }
            Spacer(minLength: 0)
            HSButton(
                String(localized: "articulation.button.start"),
                style: .primary,
                icon: "play.fill"
            ) {
                container.soundService.playUISound(.tap)
                interactor.beginMirroring()
            }
            .accessibilityHint(String(localized: "articulation.button.start.hint"))
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
        .padding(.vertical, SpacingTokens.medium)
    }

    private func poseCard(_ pose: ArticulationPose) -> some View {
        VStack(spacing: SpacingTokens.medium) {
            Text(pose.emoji)
                .font(.system(size: 96))
                .accessibilityHidden(true)
            Text(pose.name)
                .font(TypographyTokens.title(26))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
            Text(pose.instruction)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, SpacingTokens.small)
            if !display.attemptLabel.isEmpty {
                Text(display.attemptLabel)
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .padding(.top, SpacingTokens.tiny)
            }
        }
        .padding(SpacingTokens.large)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Kid.surface)
        )
        .padding(.horizontal, SpacingTokens.screenEdge)
    }

    // MARK: - Holding

    private var holdingView: some View {
        VStack(spacing: SpacingTokens.large) {
            header
            Spacer(minLength: 0)
            holdingBody
            Spacer(minLength: 0)
            holdingBottom
        }
        .padding(.vertical, SpacingTokens.medium)
    }

    private var holdingBody: some View {
        VStack(spacing: SpacingTokens.medium) {
            ZStack {
                Circle()
                    .stroke(ColorTokens.Kid.line, lineWidth: 10)
                    .frame(width: 220, height: 220)
                Circle()
                    .trim(from: 0, to: CGFloat(display.holdFraction))
                    .stroke(
                        ColorTokens.Brand.primary,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 220, height: 220)
                    .animation(
                        reduceMotion ? nil : .linear(duration: 0.1),
                        value: display.holdFraction
                    )
                Text(display.currentPose?.emoji ?? "")
                    .font(.system(size: 96))
                    .scaleEffect(reduceMotion ? 1.0 : (isPulsing ? 1.05 : 1.0))
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: isPulsing
                    )
                    .accessibilityHidden(true)
            }
            .onAppear {
                guard !reduceMotion else { return }
                isPulsing = true
            }
            .onDisappear { isPulsing = false }

            Text(display.timerLabel)
                .font(TypographyTokens.display(44))
                .foregroundStyle(ColorTokens.Kid.ink)
                .monospacedDigit()
                .accessibilityLabel(String(localized: "articulation.timer.a11y"))
                .accessibilityValue(display.timerLabel)

            Text(String(localized: "articulation.hold.title"))
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Brand.primary)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
    }

    private var holdingBottom: some View {
        VStack(spacing: SpacingTokens.small) {
            // Живой score-бар (AR режим)
            if display.mirroringMode == .arFaceTracking {
                VStack(spacing: SpacingTokens.tiny) {
                    HSProgressBar(value: display.liveScoreFraction)
                        .frame(height: 12)
                        .padding(.horizontal, SpacingTokens.screenEdge)
                    Text(display.liveScoreLabel)
                        .font(TypographyTokens.caption(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .monospacedDigit()
                        .accessibilityLabel(String(localized: "articulation.score.a11y"))
                        .accessibilityValue(display.liveScoreLabel)
                }
            }
            HStack(spacing: SpacingTokens.small) {
                // Кнопка подсказки
                Button {
                    container.soundService.playUISound(.tap)
                    let poseId = display.currentPose?.id ?? ""
                    interactor.requestHint(.init(poseId: poseId))
                } label: {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(ColorTokens.Brand.mint)
                        .frame(width: 56, height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.button)
                                .fill(ColorTokens.Kid.surface)
                        )
                }
                .accessibilityLabel(String(localized: "articulation.button.hint.a11y"))
                .accessibilityHint(String(localized: "articulation.button.hint.hint"))

                HSButton(
                    String(localized: "articulation.button.release"),
                    style: .secondary,
                    icon: "stop.fill"
                ) {
                    container.soundService.playUISound(.tap)
                    let poseId = display.currentPose?.id ?? ""
                    interactor.confirmPose(.init(poseId: poseId, confirmedByParent: false))
                }
                .accessibilityHint(String(localized: "articulation.button.release.hint"))
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
    }

    // MARK: - Feedback

    private var feedbackView: some View {
        VStack(spacing: SpacingTokens.large) {
            header
            Spacer(minLength: 0)
            feedbackBody
            Spacer(minLength: 0)
        }
        .padding(.vertical, SpacingTokens.medium)
        .task { await advanceAfterFeedback() }
    }

    private var feedbackBody: some View {
        VStack(spacing: SpacingTokens.medium) {
            if display.earnedStar {
                Image(systemName: "star.fill")
                    .font(.system(size: 120, weight: .bold))
                    .foregroundStyle(ColorTokens.Brand.gold)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "heart.fill")
                    .font(.system(size: 96, weight: .bold))
                    .foregroundStyle(ColorTokens.Brand.rose)
                    .accessibilityHidden(true)
            }
            Text(display.feedbackText)
                .font(TypographyTokens.title(26))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(display.feedbackText)
    }

    // MARK: - Completed

    private var completedView: some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer(minLength: 0)
            HSMascotView(mood: .celebrating, size: 140)
                .accessibilityHidden(true)

            HStack(spacing: SpacingTokens.tiny) {
                ForEach(0..<display.outOf, id: \.self) { index in
                    Image(systemName: index < display.starsTotal ? "star.fill" : "star")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(
                            index < display.starsTotal
                                ? ColorTokens.Brand.gold
                                : ColorTokens.Kid.line
                        )
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(display.scoreLabel)

            Text(display.scoreLabel)
                .font(TypographyTokens.headline(20))
                .foregroundStyle(ColorTokens.Kid.ink)

            Text(display.completionMessage)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, SpacingTokens.screenEdge)

            Spacer(minLength: 0)

            HSButton(
                String(localized: "articulation.button.finish"),
                style: .primary,
                icon: "checkmark.circle.fill"
            ) {
                container.soundService.playUISound(.correct)
                // Финальный скор уже уехал через pendingFinalScore.
                // Кнопка — косметический ACK (закрытие будет через
                // SessionShell, он сам навигирует).
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
        .padding(.vertical, SpacingTokens.medium)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: SpacingTokens.small) {
            VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                Text(display.greeting)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                Text(display.progressLabel)
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
            Spacer()
            HSMascotView(mood: mascotMood, size: 80)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
    }

    private var mascotMood: MascotMood {
        switch display.phase {
        case .loading:          return .thinking
        case .exercisePreview:  return .explaining
        case .holding:          return .encouraging
        case .feedback:         return display.earnedStar ? .celebrating : .encouraging
        case .completed:        return .happy
        }
    }

    // MARK: - Flow helpers

    private func startSessionOnce() {
        guard !sessionStarted else { return }
        sessionStarted = true
        let soundGroup = Self.soundGroup(for: activity.soundTarget)
        interactor.loadSession(.init(
            soundGroup: soundGroup,
            childName: ""
        ))
        // После loadSession bridge выставил phase=loading. Сразу стартуем первую позу.
        interactor.startPose(.init(poseIndex: 0))
    }

    private func advanceAfterFeedback() async {
        let wasAllDone = display.allDone
        let currentPoseId = display.currentPose?.id
        let earned = display.earnedStar

        container.soundService.playUISound(earned ? .correct : .tap)
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        // Если фаза уже изменилась (например, view ушёл) — не мешаем.
        guard display.phase == .feedback else { return }
        guard display.currentPose?.id == currentPoseId else { return }

        if wasAllDone {
            interactor.completeSession()
        } else {
            let nextIndex = nextPoseIndex()
            interactor.startPose(.init(poseIndex: nextIndex))
        }
    }

    private func nextPoseIndex() -> Int {
        guard let current = display.currentPose,
              let index = interactor.poses.firstIndex(where: { $0.id == current.id })
        else { return 0 }
        return min(index + 1, max(interactor.poses.count - 1, 0))
    }

    // MARK: - Sound group resolution

    /// Преобразует `activity.soundTarget` ("С", "Ш", "Р", …) в
    /// rawValue `SoundFamily`, который принимает интерактор.
    static func soundGroup(for soundTarget: String) -> String {
        let trimmed = soundTarget.trimmingCharacters(in: .whitespaces)
        for family in SoundFamily.allCases where family.sounds.contains(trimmed) {
            return family.rawValue
        }
        return SoundFamily.whistling.rawValue
    }
}

// MARK: - StoreBridge
//
// Presenter держит `weak` ссылку на `DisplayLogic`. SwiftUI-store —
// value-like @Observable, его нельзя безопасно weak-ссылать. Поэтому
// вводим отдельный долгоживущий объект-bridge, который View держит
// через `let bridge`. Bridge ретранслирует обновления в store.

@MainActor
final class ArticulationImitationStoreBridge: ArticulationImitationDisplayLogic {

    private let display: ArticulationImitationDisplay

    init(display: ArticulationImitationDisplay) {
        self.display = display
    }

    // MARK: Deep VIP

    func displayLoadSession(_ viewModel: ArticulationImitationModels.LoadSession.ViewModel) {
        display.greeting = viewModel.greeting
        display.totalPoses = viewModel.poses.count
        display.outOf = max(viewModel.poses.count, 1)
        display.starsTotal = 0
        display.mirroringMode = viewModel.mirroringMode
        display.gamePhase = .loading
    }

    func displayStartPose(_ viewModel: ArticulationImitationModels.StartPose.ViewModel) {
        display.currentPose = viewModel.pose
        display.progressLabel = viewModel.progressLabel
        display.attemptLabel = viewModel.attemptLabel
        display.voicePrompt = viewModel.voicePrompt
        display.liveScoreFraction = 0
        display.liveScoreLabel = "0%"
        display.liveFeedbackColor = "neutral"
        display.matchedChannels = []
        display.gamePhase = .posePreview
        // Legacy bridge
        display.phase = .exercisePreview
    }

    func displayBeginMirroring(_ mode: MirroringMode) {
        display.mirroringMode = mode
        display.gamePhase = .mirroring
        display.arSessionActive = (mode == .arFaceTracking)
        display.phase = .holding
    }

    func displayBlendshapeUpdate(_ viewModel: ArticulationImitationModels.BlendshapeUpdate.ViewModel) {
        display.liveScoreFraction = viewModel.scoreFraction
        display.liveScoreLabel = viewModel.scoreLabel
        display.liveFeedbackColor = viewModel.feedbackColor
        display.matchedChannels = viewModel.matchedChannels
        display.holdFraction = viewModel.scoreFraction
    }

    func displayConfirmPose(_ viewModel: ArticulationImitationModels.ConfirmPose.ViewModel) {
        display.poseFeedbackText = viewModel.feedbackText
        display.posePassed = viewModel.passed
        display.allDone = viewModel.allDone
        display.feedbackText = viewModel.feedbackText
        display.earnedStar = viewModel.passed
        if viewModel.passed {
            display.starsTotal += 1
        }
        display.gamePhase = .poseFeedback
        display.phase = .feedback
    }

    func displayHint(_ viewModel: ArticulationImitationModels.RequestHint.ViewModel) {
        display.hintText = viewModel.hintText
        display.hintLevel = viewModel.hintLevel
        display.attemptsLeftLabel = viewModel.attemptsLeftLabel
        display.gamePhase = .hintShowing(level: viewModel.hintLevel)
    }

    func displayParentConfirmRequest(_ pose: ArticulationPose) {
        display.currentPose = pose
        display.gamePhase = .parentConfirm
    }

    // MARK: Legacy

    func displayStartExercise(_ viewModel: ArticulationImitationModels.StartExercise.ViewModel) {
        display.currentExercise = viewModel.exercise
        display.progressLabel = viewModel.progressLabel
        display.holdFraction = 0
        display.timerLabel = "\(viewModel.exercise.holdSeconds)"
        display.phase = .exercisePreview
    }

    func displayHoldProgress(_ viewModel: ArticulationImitationModels.HoldProgress.ViewModel) {
        display.holdFraction = viewModel.fraction
        display.timerLabel = viewModel.timerLabel
    }

    func displayCompleteExercise(_ viewModel: ArticulationImitationModels.CompleteExercise.ViewModel) {
        display.earnedStar = viewModel.earnedStar
        display.feedbackText = viewModel.feedbackText
        display.allDone = viewModel.allDone
        if viewModel.earnedStar {
            display.starsTotal += 1
        }
        display.phase = .feedback
    }

    func displaySessionComplete(_ viewModel: ArticulationImitationModels.SessionComplete.ViewModel) {
        display.starsTotal = viewModel.starsTotal
        display.outOf = viewModel.outOf
        display.scoreLabel = viewModel.scoreLabel
        display.completionMessage = viewModel.message
        display.phase = .completed
        display.pendingFinalScore = viewModel.normalizedScore
    }
}

// MARK: - Preview

#Preview {
    ArticulationImitationView(
        activity: SessionActivity(
            id: "preview",
            gameType: .articulationImitation,
            lessonId: "l1",
            soundTarget: "Р",
            difficulty: 1,
            isCompleted: false,
            score: nil
        ),
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
