import Foundation
import OSLog

// MARK: - BreathingExtendedInteractor
//
// Composition (not subclass) of BreathingInteractor logic, adapted for the
// Stuttering module's "Длинный выдох" (BreathingTreeView) exercise.
// Scene is `.tree`, goals match StutteringDifficulty thresholds.
//
// Delegates all audio/RMS work to BreathingInteractor by constructing it
// internally with a `.tree` scene configuration. The extended interactor
// only overrides the required duration and round counting.

@MainActor
final class BreathingExtendedInteractor {

    // MARK: - Display state

    @Observable
    final class Display {
        var treeProgress: Float = 0       // 0.0–1.0 leaf fill
        var isPlaying: Bool = false
        var roundsComplete: Int = 0
        var roundsRequired: Int = 5
        var showSuccess: Bool = false
        var mascotMood: MascotMood = .idle
        var instruction: String = ""
        var waveformLevels: [Float] = []
    }

    let display = Display()

    // MARK: - Core breathing interactor (composition)

    private let coreInteractor: BreathingInteractor
    private let audioWorker: BreathingAudioWorker
    private let hapticWorker: any BreathingHapticWorkerProtocol
    private let logger = HSLogger.audio

    // MARK: - Session state

    private var difficulty: StutteringDifficulty = .easy
    private var totalProgress: Float = 0
    private var roundStartProgress: Float = 0

    // MARK: - Init

    init() {
        let audio = BreathingAudioWorker()
        let haptic = MockBreathingHapticWorker()
        self.audioWorker = audio
        self.hapticWorker = haptic
        self.coreInteractor = BreathingInteractor(
            audioWorker: audio,
            hapticWorker: haptic
        )
    }

    // MARK: - Public API

    func startSession(difficulty: StutteringDifficulty) async {
        self.difficulty = difficulty
        display.roundsRequired = difficulty.roundCount
        display.roundsComplete = 0
        display.treeProgress = 0
        display.showSuccess = false
        display.instruction = String(localized: "stuttering.exercise.breathing.subtitle")
        display.mascotMood = .happy

        await beginRound()
    }

    func cancel() async {
        await coreInteractor.cancel()
        display.isPlaying = false
        display.mascotMood = .idle
    }

    // MARK: - Round management

    private func beginRound() async {
        display.isPlaying = true
        roundStartProgress = display.treeProgress

        await coreInteractor.beginGame(
            activityId: "stuttering_breathing_\(difficulty.rawValue)",
            difficulty: breathingDifficulty
        )

        // Observe core state via presenter delegate pattern —
        // we subscribe by injecting a custom presenter.
        let presenter = BreathingExtendedPresenterAdapter { [weak self] state, progress, amplitude in
            Task { @MainActor [weak self] in
                self?.handleCoreUpdate(state: state, progress: progress, amplitude: amplitude)
            }
        }
        coreInteractor.presenter = presenter
        await coreInteractor.advanceTutorial()
        await coreInteractor.advanceTutorial()
        await coreInteractor.advanceTutorial()
    }

    // MARK: - State handling

    private func handleCoreUpdate(state: BreathingGameState, progress: Float, amplitude: Float) {
        // Update waveform
        var levels = display.waveformLevels
        levels.append(amplitude)
        if levels.count > 40 { levels.removeFirst(levels.count - 40) }
        display.waveformLevels = levels

        // Map progress (0..1 per round) to tree fill (0..1 across all rounds)
        let roundFraction = Float(display.roundsComplete) / Float(max(1, display.roundsRequired))
        let roundProgress = progress * (1.0 / Float(max(1, display.roundsRequired)))
        display.treeProgress = min(1.0, roundFraction + roundProgress)

        switch state {
        case .summary(let result):
            if result.didSucceed {
                completeRound()
            } else {
                // Failed round: partial progress, restart round
                display.treeProgress = roundStartProgress
                display.mascotMood = .happy
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    try? await Task.sleep(for: .seconds(1.0))
                    await self.beginRound()
                }
            }
        case .playing:
            display.mascotMood = .happy
        case .warmUp:
            display.mascotMood = .thinking
        default:
            break
        }
    }

    private func completeRound() {
        display.roundsComplete += 1
        display.mascotMood = .celebrating
        logger.info("BreathingExtended: round \(self.display.roundsComplete)/\(self.display.roundsRequired) complete")

        if display.roundsComplete >= display.roundsRequired {
            display.treeProgress = 1.0
            display.showSuccess = true
            display.isPlaying = false
        } else {
            Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: .seconds(1.5))
                self.display.mascotMood = .happy
                await self.beginRound()
            }
        }
    }

    // MARK: - Breathing difficulty mapping

    private var breathingDifficulty: BreathingDifficulty {
        switch difficulty {
        case .easy:   return .easy
        case .medium: return .medium
        case .hard:   return .hard
        }
    }
}

// MARK: - BreathingExtendedPresenterAdapter

/// Bridges BreathingInteractor output into the extended interactor callback.
@MainActor
private final class BreathingExtendedPresenterAdapter: BreathingPresentationLogic {

    typealias UpdateCallback = @MainActor (BreathingGameState, Float, Float) -> Void

    private let onUpdate: UpdateCallback

    init(onUpdate: @escaping UpdateCallback) {
        self.onUpdate = onUpdate
    }

    func presentLoadSession(_ response: BreathingModels.LoadSession.Response) {}

    func presentSubmitAttempt(_ response: BreathingModels.SubmitAttempt.Response) {}

    func presentUpdateSignal(_ response: BreathingModels.UpdateSignal.Response) {
        onUpdate(response.state, response.progress, response.amplitude)
    }

    func presentFinish(_ response: BreathingModels.Finish.Response) {
        onUpdate(.summary(result: response.result), 1.0, 0)
    }
}
