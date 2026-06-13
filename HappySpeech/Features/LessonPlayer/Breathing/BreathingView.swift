import SwiftUI

// MARK: - BreathingView
//
// "Подуй на одуванчик" / "Задуй свечу" / "Надуй шарик" — dandelion minigame
// that reads the mic RMS in real time and flies petals off the screen as
// the child holds their exhale. The view owns an @Observable `Store` that
// plays the BreathingDisplayLogic role; the Interactor pushes updates into
// it from its state machine.

struct BreathingView: View {

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    @State private var store: BreathingStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        activity: SessionActivity,
        onComplete: @escaping (Float) -> Void
    ) {
        self.activity = activity
        self.onComplete = onComplete
        let audioWorker = BreathingAudioWorker()
        let hapticWorker = BreathingHapticWorker(haptic: LiveHapticService())
        let metricsWorker: any BreathingMetricsWorkerProtocol = LiveBreathingMetricsWorker()
        let interactor = BreathingInteractor(
            audioWorker: audioWorker,
            hapticWorker: hapticWorker,
            metricsWorker: metricsWorker
        )
        let presenter = BreathingPresenter()
        interactor.presenter = presenter
        let store = BreathingStore(interactor: interactor, presenter: presenter)
        _store = State(initialValue: store)
    }

    var body: some View {
        ZStack {
            HSMeshGradientBackground(palette: .calm, animated: false)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            content
            if store.showTutorial { tutorialOverlay }
            if store.showWarmUp { warmUpOverlay }
        }
        .task {
            store.presenter.viewModel = store
            store.interactor.loadSession(.init(
                sessionId: activity.id,
                difficulty: Self.difficulty(for: activity.difficulty)
            ))
            await store.interactor.beginGame(
                activityId: activity.id,
                difficulty: Self.difficulty(for: activity.difficulty)
            )
        }
        .onChange(of: store.pendingFinalScore) { _, newValue in
            if let score = newValue { onComplete(score) }
        }
        .onDisappear {
            Task { await store.interactor.cancel() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Дыхательное упражнение. Подуй в микрофон, чтобы сдуть лепестки."))
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        VStack(spacing: SpacingTokens.medium) {
            header
            Spacer(minLength: 0)
            HSBreathingOrb(
                expansion: orbExpansion,
                ringProgress: store.progress,
                phaseTitle: store.subtitle,
                phaseCount: nil,
                size: 240
            )
            Spacer(minLength: 0)
            mascotBubble
            progressSection
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.vertical, SpacingTokens.medium)
    }

    /// Орб раскрывается тем сильнее, чем активнее выдох ребёнка (live RMS
    /// масштаб ≈ 0.7…1.2 нормализуется в 0…1).
    private var orbExpansion: CGFloat {
        guard !reduceMotion else { return store.progress }
        let normalized = (store.objectScale - 0.7) / 0.5
        return max(0, min(1, normalized))
    }

    private var header: some View {
        VStack(spacing: SpacingTokens.tiny) {
            Text(store.title)
                .font(TypographyTokens.kidTitle(22))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SpacingTokens.sp3)
    }

    private var breathingLyalyaState: LyalyaState {
        switch store.mascotMoodView {
        case .celebrating: return .celebrating
        case .encouraging:  return .encouraging
        case .thinking:    return .thinking
        default:           return .idle
        }
    }

    private var mascotBubble: some View {
        HStack(alignment: .center, spacing: SpacingTokens.sp3) {
            LyalyaMascotView(state: breathingLyalyaState, size: 60)
                .accessibilityHidden(true)
            Text(String(localized: "Дыши вместе со мной"))
                .font(TypographyTokens.body(15).weight(.medium))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .padding(SpacingTokens.sp3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .fill(ColorTokens.Kid.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                                .stroke(ColorTokens.Kid.line, lineWidth: 1)
                        )
                )
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Дыши вместе со мной"))
    }

    private var progressSection: some View {
        VStack(spacing: SpacingTokens.small) {
            HSProgressBar(value: store.progress)
                .frame(height: 10)
                .accessibilityLabel(String(localized: "Прогресс"))
                .accessibilityValue(String(localized: "\(Int(store.progress * 100)) процентов"))

            if let failure = store.failureMessage {
                Text(failure)
                    .font(TypographyTokens.caption())
                    .foregroundStyle(ColorTokens.Semantic.error)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    // MARK: - Overlays

    private var tutorialOverlay: some View {
        ColorTokens.Overlay.dimmer.ignoresSafeArea()
            .overlay(
                HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.large) {
                    VStack(spacing: SpacingTokens.medium) {
                        LyalyaMascotView(state: .thinking, size: 100)
                            .accessibilityHidden(true)
                        Text(tutorialText(for: store.tutorialStep))
                            .font(TypographyTokens.title())
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)
                        HSButton(
                            String(localized: "Дальше"),
                            style: .primary,
                            icon: "arrow.right.circle.fill"
                        ) {
                            Task { await store.interactor.advanceTutorial() }
                        }
                        .frame(minHeight: 56)
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
            )
    }

    private var warmUpOverlay: some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.large) {
            VStack(spacing: SpacingTokens.small) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.4)
                    .tint(ColorTokens.Brand.primary)
                Text(String(localized: "Тише… готовимся"))
                    .font(TypographyTokens.body())
                    .foregroundStyle(ColorTokens.Kid.ink)
            }
        }
    }

    private func tutorialText(for step: Int) -> String {
        switch step {
        case 0: return String(localized: "Сделай глубокий вдох носиком.")
        case 1: return String(localized: "Губы трубочкой, как на горячий чай.")
        default: return String(localized: "Дуй ровно и долго на одуванчик.")
        }
    }

    // MARK: - Difficulty mapping

    private static func difficulty(for level: Int) -> BreathingDifficulty {
        switch level {
        case ..<2: return .easy
        case 2:    return .medium
        default:   return .hard
        }
    }
}

// MARK: - Store

@MainActor
@Observable
final class BreathingStore: BreathingDisplayLogic {

    let interactor: BreathingInteractor
    let presenter: BreathingPresenter

    // Published state
    var title: String = String(localized: "Подуй на одуванчик!")
    var subtitle: String = String(localized: "Глубокий вдох")
    var progress: Double = 0
    var objectScale: CGFloat = 1
    var petalsRemaining: Int = BreathingScene.dandelion.totalPetals
    var showTutorial: Bool = false
    var showWarmUp: Bool = false
    var tutorialStep: Int = 0
    var failureMessage: String?
    var pendingFinalScore: Float?
    var mascotMoodView: MascotMood = .idle

    init(interactor: BreathingInteractor, presenter: BreathingPresenter) {
        self.interactor = interactor
        self.presenter = presenter
    }

    // MARK: BreathingDisplayLogic

    func displayLoadSession(_ viewModel: BreathingModels.LoadSession.ViewModel) {
        self.title = viewModel.titleText
        self.subtitle = viewModel.instructionText
    }

    func displaySubmitAttempt(_ viewModel: BreathingModels.SubmitAttempt.ViewModel) {
        // No-op — breathing submits via the UpdateSignal / Finish pipeline.
    }

    func displayUpdateSignal(_ viewModel: BreathingModels.UpdateSignal.ViewModel) {
        self.title = viewModel.title
        self.subtitle = viewModel.subtitle
        self.progress = viewModel.progress
        self.objectScale = viewModel.objectScale
        self.petalsRemaining = viewModel.petalsRemaining
        self.showTutorial = viewModel.showTutorialOverlay
        self.showWarmUp = viewModel.showWarmUpOverlay
        self.tutorialStep = viewModel.tutorialStep
        self.failureMessage = viewModel.failureMessage
        self.mascotMoodView = Self.mascotMood(from: viewModel.mascotMood)
    }

    func displayFinish(_ viewModel: BreathingModels.Finish.ViewModel) {
        self.title = viewModel.title
        self.subtitle = viewModel.subtitle
        self.pendingFinalScore = viewModel.finalScore
    }

    // MARK: Helpers

    private static func mascotMood(from vm: MascotMoodVM) -> MascotMood {
        switch vm {
        case .idle:         return .idle
        case .encouraging:  return .encouraging
        case .celebrating:  return .celebrating
        case .sad:          return .sad
        case .thinking:     return .thinking
        }
    }
}

// MARK: - Preview

#Preview {
    BreathingView(
        activity: SessionActivity(
            id: "preview", gameType: .breathing, lessonId: "l1",
            soundTarget: "С", difficulty: 1, isCompleted: false, score: nil
        ),
        onComplete: { _ in }
    )
}
