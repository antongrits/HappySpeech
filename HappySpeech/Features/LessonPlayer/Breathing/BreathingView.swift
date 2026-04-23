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

    init(activity: SessionActivity, onComplete: @escaping (Float) -> Void) {
        self.activity = activity
        self.onComplete = onComplete
        let audioWorker = BreathingAudioWorker()
        let hapticWorker = BreathingHapticWorker(haptic: LiveHapticService())
        let interactor = BreathingInteractor(
            audioWorker: audioWorker,
            hapticWorker: hapticWorker
        )
        let presenter = BreathingPresenter()
        interactor.presenter = presenter
        let store = BreathingStore(interactor: interactor, presenter: presenter)
        _store = State(initialValue: store)
    }

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()
            content
            if store.showTutorial { tutorialOverlay }
            if store.showWarmUp   { warmUpOverlay }
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
        VStack(spacing: SpacingTokens.large) {
            header
            Spacer(minLength: 0)
            dandelion
            Spacer(minLength: 0)
            progressSection
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.vertical, SpacingTokens.medium)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: SpacingTokens.small) {
            VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                Text(store.title)
                    .font(TypographyTokens.title())
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                Text(store.subtitle)
                    .font(TypographyTokens.body())
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }
            Spacer()
            HSMascotView(mood: store.mascotMoodView, size: 80)
                .accessibilityHidden(true)
        }
    }

    private var dandelion: some View {
        ZStack {
            // Stem
            Rectangle()
                .fill(ColorTokens.Brand.mint)
                .frame(width: 6, height: 120)
                .offset(y: 80)
                .accessibilityHidden(true)

            // Petals
            ForEach(0..<max(store.petalsRemaining, 0), id: \.self) { index in
                petal(index: index)
            }

            // Core
            Circle()
                .fill(ColorTokens.Brand.primary.opacity(0.35))
                .frame(width: 70, height: 70)
                .overlay(
                    Circle()
                        .stroke(ColorTokens.Brand.primary, lineWidth: 2)
                )
        }
        .scaleEffect(reduceMotion ? 1.0 : store.objectScale)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7),
                   value: store.objectScale)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Одуванчик"))
        .accessibilityValue(String(localized: "\(Int(store.progress * 100)) процентов"))
    }

    private func petal(index: Int) -> some View {
        let total = max(store.petalsRemaining, 1)
        let angle = Double(index) / Double(total) * 360
        return Circle()
            .fill(ColorTokens.Brand.primary.opacity(0.7))
            .frame(width: 18, height: 18)
            .offset(y: -54)
            .rotationEffect(.degrees(angle))
            .accessibilityHidden(true)
    }

    private var progressSection: some View {
        VStack(spacing: SpacingTokens.small) {
            HSProgressBar(value: store.progress)
                .frame(height: 10)

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
        Color.black.opacity(0.35).ignoresSafeArea()
            .overlay(
                VStack(spacing: SpacingTokens.medium) {
                    HSMascotView(mood: .thinking, size: 120)
                        .accessibilityHidden(true)
                    Text(tutorialText(for: store.tutorialStep))
                        .font(TypographyTokens.title())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .padding(.horizontal, SpacingTokens.screenEdge)
                    HSButton(
                        String(localized: "Дальше"),
                        style: .primary
                    ) {
                        Task { await store.interactor.advanceTutorial() }
                    }
                    .frame(minHeight: 56)
                    .padding(.horizontal, SpacingTokens.screenEdge)
                }
            )
    }

    private var warmUpOverlay: some View {
        VStack(spacing: SpacingTokens.small) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.4)
            Text(String(localized: "Тише… готовимся"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.ink)
        }
        .padding(SpacingTokens.large)
        .background(ColorTokens.Kid.surface, in: RoundedRectangle(cornerRadius: RadiusTokens.md))
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
