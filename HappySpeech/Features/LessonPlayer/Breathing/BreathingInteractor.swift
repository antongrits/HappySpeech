import Foundation
import OSLog

// MARK: - BreathingBusinessLogic

@MainActor
protocol BreathingBusinessLogic: AnyObject {

    // Scaffold hooks kept for parity with the rest of the LessonPlayer
    // features — they are called from the view when SessionShell first
    // drops into the Breathing screen and when a final "submit" is made.
    func loadSession(_ request: BreathingModels.LoadSession.Request)
    func submitAttempt(_ request: BreathingModels.SubmitAttempt.Request)

    // Real lifecycle used by the dandelion view.
    func beginGame(activityId: String, difficulty: BreathingDifficulty) async
    func advanceTutorial() async
    func cancel() async
    func markInterrupted()
}

// MARK: - BreathingInteractor
//
// The Breathing game turns the microphone RMS level into on-screen motion
// (dandelion petals fly off / balloon inflates). The Interactor drives a
// simple state machine:
//
//   idle → tutorial(0,1,2) → warmUp → playing → (success | failure) → summary
//
// Signal path:
//   AVAudioEngine tap  ─►  vDSP_rmsqv  ─►  worker callback
//        ─►  handleAmplitude(_:)  ─►  classify by threshold
//        ─►  presenter.presentUpdateSignal(...)  ─►  view update
//
// Scoring:
//   score = stableRatio × min(duration/required, 1)
// where `stableRatio` is the fraction of ticks whose amplitude is above the
// adaptive threshold = `baseline × config.thresholdMultiplier`.

@MainActor
final class BreathingInteractor: BreathingBusinessLogic {

    // MARK: - Dependencies

    var presenter: (any BreathingPresentationLogic)?

    private let audioWorker: any BreathingAudioWorkerProtocol
    private let hapticWorker: any BreathingHapticWorkerProtocol
    private let logger = HSLogger.audio

    // MARK: - Tuning

    /// 20 Hz update rate — matches the 50 ms RMS window requested in the ТЗ.
    private let tickIntervalSec: TimeInterval = 0.05
    /// Size of the rolling baseline buffer used during warm-up.
    private let baselineSampleCount: Int = 60

    // MARK: - Session state

    private(set) var state: BreathingGameState = .idle
    private var config: BreathingGameConfig = .medium
    private var scene: BreathingScene = .dandelion
    private var activityId: String = ""

    // Warm-up calibration buffer (last ~3 s of amplitude).
    private var warmUpBuffer: [Float] = []
    private var warmUpStartedAt: Date?

    // Runtime counters driven by the amplitude callback.
    private var baseline: Float = 0
    private var adaptiveThreshold: Float = 0
    private var playStartedAt: Date?
    private var lastTickTime: Date?
    private var accumulatedMs: Int = 0
    private var sampleCount: Int = 0
    private var samplesAboveThreshold: Int = 0
    private var petalsBlown: Int = 0
    private var hasBegunBlowing: Bool = false
    private var consecutiveAboveTicks: Int = 0

    // Timer for the "already-blowing" progression sanity-check. RMS from the
    // worker is bursty; a ~100 ms cadence tick lets us drive progress even
    // if the worker pauses briefly (buffer exhaustion at start-up).
    private var progressTimer: Timer?

    // MARK: - Init

    init(
        audioWorker: any BreathingAudioWorkerProtocol,
        hapticWorker: any BreathingHapticWorkerProtocol
    ) {
        self.audioWorker = audioWorker
        self.hapticWorker = hapticWorker
    }

    // MARK: - Scaffold contract

    func loadSession(_ request: BreathingModels.LoadSession.Request) {
        activityId = request.sessionId
        config = .forDifficulty(request.difficulty)
        scene = .dandelion
        let items = [
            String(localized: "Подуй на одуванчик!"),
            String(localized: "Сделай глубокий вдох…"),
            String(localized: "…и долгий ровный выдох")
        ]
        let response = BreathingModels.LoadSession.Response(
            items: items,
            config: config,
            scene: scene
        )
        presenter?.presentLoadSession(response)
    }

    func submitAttempt(_ request: BreathingModels.SubmitAttempt.Request) {
        // Breathing doesn't have a word-submit step; the audio path already
        // produced a score. We still emit a neutral response so the scaffold
        // pipeline keeps its contract.
        let response = BreathingModels.SubmitAttempt.Response(
            isCorrect: false,
            score: 0
        )
        presenter?.presentSubmitAttempt(response)
    }

    // MARK: - Public lifecycle

    func beginGame(activityId: String, difficulty: BreathingDifficulty) async {
        self.activityId = activityId
        self.config = .forDifficulty(difficulty)
        self.resetRuntimeState()

        // First ask for mic permission before doing anything else.
        let granted = await audioWorker.requestPermission()
        guard granted else {
            await fail(with: .noMicrophone)
            return
        }

        // Kick off the tutorial. The view drives `advanceTutorial()` as the
        // user taps "Дальше". After the last step we enter warm-up.
        state = .tutorial(step: 0)
        await emitCurrentSnapshot()
        logger.info("Breathing: tutorial started for activity=\(self.activityId, privacy: .public)")
    }

    func advanceTutorial() async {
        guard case .tutorial(let step) = state else { return }
        let nextStep = step + 1
        if nextStep >= 3 {
            await startWarmUp()
        } else {
            state = .tutorial(step: nextStep)
            await emitCurrentSnapshot()
        }
    }

    func cancel() async {
        stopProgressTimer()
        audioWorker.stop()
        state = .idle
        await emitCurrentSnapshot()
    }

    func markInterrupted() {
        stopProgressTimer()
        audioWorker.stop()
        Task { @MainActor in
            await self.fail(with: .interrupted)
        }
    }

    // MARK: - Phase transitions

    private func startWarmUp() async {
        state = .warmUp(elapsedMs: 0)
        warmUpStartedAt = Date()
        warmUpBuffer.removeAll(keepingCapacity: true)
        do {
            try await audioWorker.start(
                onAmplitude: { [weak self] amp in
                    Task { @MainActor [weak self] in
                        self?.handleAmplitude(amp)
                    }
                },
                onInterrupt: { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.markInterrupted()
                    }
                }
            )
            hapticWorker.blowStart()
            logger.info("Breathing: warm-up started")
            await emitCurrentSnapshot()
            scheduleProgressTimer()
        } catch {
            logger.error("Breathing: audio start failed — \(error.localizedDescription, privacy: .public)")
            await fail(with: .noMicrophone)
        }
    }

    private func startPlaying() async {
        // Snapshot the baseline so later amplitude samples have a stable
        // threshold to compare against.
        baseline = computeBaseline(from: warmUpBuffer)
        adaptiveThreshold = max(0.03, baseline * config.thresholdMultiplier)
        playStartedAt = Date()
        lastTickTime = Date()
        accumulatedMs = 0
        sampleCount = 0
        samplesAboveThreshold = 0
        petalsBlown = 0
        hasBegunBlowing = false
        consecutiveAboveTicks = 0
        state = .playing(elapsedMs: 0, amplitude: 0, objectScale: 1.0)
        logger.info("Breathing: playing — baseline=\(self.baseline) threshold=\(self.adaptiveThreshold)")
        await emitCurrentSnapshot()
    }

    private func completeSuccess() async {
        stopProgressTimer()
        audioWorker.stop()
        let duration = accumulatedMs.ms
        let ratio = computeStableRatio()
        let score = BreathingScoring.score(
            stableRatio: ratio,
            durationSec: duration,
            required: config.requiredDurationSec
        )
        state = .success(score: score, duration: duration)
        hapticWorker.success()
        let result = BreathingResult(
            difficulty: config.difficulty,
            durationSec: duration,
            stableRatio: ratio,
            score: score,
            stars: BreathingScoring.stars(for: score),
            petalsBlown: petalsBlown,
            totalPetals: scene.totalPetals,
            didSucceed: true
        )
        state = .summary(result: result)
        presenter?.presentFinish(.init(result: result))
        await emitCurrentSnapshot()
        logger.info("Breathing: success score=\(score) duration=\(duration)")
    }

    private func fail(with reason: BreathingFailureReason) async {
        stopProgressTimer()
        audioWorker.stop()
        state = .failure(reason: reason)
        hapticWorker.failure()

        let duration = accumulatedMs.ms
        let ratio = computeStableRatio()
        let score: Float = 0
        let result = BreathingResult(
            difficulty: config.difficulty,
            durationSec: duration,
            stableRatio: ratio,
            score: score,
            stars: 0,
            petalsBlown: petalsBlown,
            totalPetals: scene.totalPetals,
            didSucceed: false
        )
        state = .summary(result: result)
        presenter?.presentFinish(.init(result: result))
        await emitCurrentSnapshot()
        logger.info("Breathing: failed — reason=\(String(describing: reason), privacy: .public)")
    }

    // MARK: - Amplitude handling

    private func handleAmplitude(_ amplitude: Float) {
        switch state {
        case .warmUp:
            handleWarmUpSample(amplitude)
        case .playing:
            handlePlayingSample(amplitude)
        default:
            break
        }
    }

    private func handleWarmUpSample(_ amplitude: Float) {
        warmUpBuffer.append(amplitude)
        if warmUpBuffer.count > baselineSampleCount {
            warmUpBuffer.removeFirst(warmUpBuffer.count - baselineSampleCount)
        }

        let elapsedMs = Int(Date().timeIntervalSince(warmUpStartedAt ?? Date()) * 1000)
        state = .warmUp(elapsedMs: elapsedMs)

        if Double(elapsedMs) / 1000.0 >= config.warmUpSec {
            Task { @MainActor [weak self] in await self?.startPlaying() }
        }
    }

    private func handlePlayingSample(_ amplitude: Float) {
        guard let startedAt = playStartedAt else { return }

        let now = Date()
        let elapsedSec = now.timeIntervalSince(startedAt)
        let elapsedMs = Int(elapsedSec * 1000)
        accumulatedMs = elapsedMs
        lastTickTime = now

        sampleCount += 1
        let isAbove = amplitude >= adaptiveThreshold
        if isAbove {
            samplesAboveThreshold += 1
            consecutiveAboveTicks += 1
            if !hasBegunBlowing {
                hasBegunBlowing = true
                hapticWorker.blowStart()
            }
        } else {
            consecutiveAboveTicks = 0
        }

        // Petal flight: every ~requiredDuration / totalPetals of sustained
        // blowing peels one petal off.
        let total = scene.totalPetals
        let target = min(
            total,
            Int(elapsedSec / config.requiredDurationSec * Double(total) + 0.01)
        )
        while petalsBlown < target {
            petalsBlown += 1
            hapticWorker.petalBlown()
        }

        let normalised = Self.normalise(amplitude, threshold: adaptiveThreshold)
        let objectScale = Self.objectScale(
            for: normalised,
            cap: config.amplitudeScaleCap
        )
        state = .playing(elapsedMs: elapsedMs, amplitude: amplitude, objectScale: objectScale)

        // Check termination: duration reached OR signal dropped for too long.
        if elapsedSec >= config.requiredDurationSec {
            let ratio = computeStableRatio()
            if ratio >= config.minStableRatio {
                Task { @MainActor [weak self] in await self?.completeSuccess() }
            } else {
                Task { @MainActor [weak self] in await self?.fail(with: .tooQuiet) }
            }
            return
        }

        // If the child produced a burst then gave up quickly, fail with
        // `tooShort` so the presenter can tell them to try again.
        if hasBegunBlowing, consecutiveAboveTicks == 0, elapsedMs > 1500,
           samplesAboveThreshold < Int(Double(sampleCount) * 0.15) {
            Task { @MainActor [weak self] in await self?.fail(with: .tooShort) }
            return
        }

        emitPlayingSnapshot(amplitude: amplitude,
                            normalised: normalised,
                            objectScale: objectScale,
                            elapsedMs: elapsedMs)
    }

    // MARK: - Snapshot emission

    private func emitCurrentSnapshot() async {
        switch state {
        case .idle, .tutorial, .summary:
            let response = BreathingModels.UpdateSignal.Response(
                state: state,
                amplitude: 0,
                normalizedAmplitude: 0,
                objectScale: 1,
                petalsRemaining: scene.totalPetals - petalsBlown,
                elapsedMs: 0,
                progress: 0
            )
            presenter?.presentUpdateSignal(response)
        case .warmUp(let elapsedMs):
            let response = BreathingModels.UpdateSignal.Response(
                state: state,
                amplitude: 0,
                normalizedAmplitude: 0,
                objectScale: 1,
                petalsRemaining: scene.totalPetals,
                elapsedMs: elapsedMs,
                progress: 0
            )
            presenter?.presentUpdateSignal(response)
        case .playing(let elapsedMs, let amplitude, let objectScale):
            let normalised = Self.normalise(amplitude, threshold: adaptiveThreshold)
            emitPlayingSnapshot(amplitude: amplitude,
                                normalised: normalised,
                                objectScale: objectScale,
                                elapsedMs: elapsedMs)
        case .success, .failure:
            // Intentionally empty — the Finish VM is pushed via presentFinish.
            break
        }
    }

    private func emitPlayingSnapshot(
        amplitude: Float,
        normalised: Float,
        objectScale: Float,
        elapsedMs: Int
    ) {
        let progress = min(Float(elapsedMs) / Float(config.requiredDurationSec * 1000), 1)
        let response = BreathingModels.UpdateSignal.Response(
            state: state,
            amplitude: amplitude,
            normalizedAmplitude: normalised,
            objectScale: objectScale,
            petalsRemaining: max(0, scene.totalPetals - petalsBlown),
            elapsedMs: elapsedMs,
            progress: progress
        )
        presenter?.presentUpdateSignal(response)
    }

    // MARK: - Maths helpers

    static func normalise(_ amplitude: Float, threshold: Float) -> Float {
        guard threshold > 0 else { return 0 }
        let normalised = amplitude / (threshold * 2)
        return max(0, min(normalised, 1))
    }

    static func objectScale(for normalised: Float, cap: Float) -> Float {
        // 1.0 baseline → up to `cap` (e.g. 3.0) at full normalised amplitude.
        return 1 + normalised * (cap - 1)
    }

    private func computeBaseline(from buffer: [Float]) -> Float {
        guard !buffer.isEmpty else { return 0 }
        let mean = buffer.reduce(0, +) / Float(buffer.count)
        return mean
    }

    private func computeStableRatio() -> Float {
        guard sampleCount > 0 else { return 0 }
        return Float(samplesAboveThreshold) / Float(sampleCount)
    }

    // MARK: - Progress timer

    private func scheduleProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(
            withTimeInterval: tickIntervalSec,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pulseTimer()
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    /// Advances the UI even when the mic callback is briefly idle. Does
    /// not mutate amplitude statistics — only re-emits the latest snapshot.
    private func pulseTimer() {
        switch state {
        case .warmUp(let elapsedMs):
            let newMs = elapsedMs + Int(tickIntervalSec * 1000)
            state = .warmUp(elapsedMs: newMs)
            Task { @MainActor [weak self] in await self?.emitCurrentSnapshot() }
            if Double(newMs) / 1000.0 >= config.warmUpSec {
                Task { @MainActor [weak self] in await self?.startPlaying() }
            }
        case .playing(_, let amplitude, let objectScale):
            guard let startedAt = playStartedAt else { return }
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            accumulatedMs = elapsedMs
            state = .playing(elapsedMs: elapsedMs,
                             amplitude: amplitude,
                             objectScale: objectScale)
            emitPlayingSnapshot(
                amplitude: amplitude,
                normalised: Self.normalise(amplitude, threshold: adaptiveThreshold),
                objectScale: objectScale,
                elapsedMs: elapsedMs
            )
            // Force-fail if no blow within 10 s of play start.
            if !hasBegunBlowing, elapsedMs > 10_000 {
                Task { @MainActor [weak self] in await self?.fail(with: .tooQuiet) }
            }
        default:
            break
        }
    }

    // MARK: - Reset

    private func resetRuntimeState() {
        warmUpBuffer.removeAll(keepingCapacity: true)
        warmUpStartedAt = nil
        baseline = 0
        adaptiveThreshold = 0
        playStartedAt = nil
        lastTickTime = nil
        accumulatedMs = 0
        sampleCount = 0
        samplesAboveThreshold = 0
        petalsBlown = 0
        hasBegunBlowing = false
        consecutiveAboveTicks = 0
    }

    // MARK: - Test hooks
    // Let unit tests feed deterministic amplitudes without the timer race.

    #if DEBUG
    func _test_pushAmplitude(_ amplitude: Float) {
        handleAmplitude(amplitude)
    }

    func _test_forceEnterPlaying(baseline: Float) {
        self.baseline = baseline
        self.adaptiveThreshold = max(0.03, baseline * config.thresholdMultiplier)
        self.playStartedAt = Date().addingTimeInterval(-0.01)
        self.lastTickTime = Date()
        self.state = .playing(elapsedMs: 0, amplitude: 0, objectScale: 1)
    }

    func _test_forceState(_ newState: BreathingGameState) {
        self.state = newState
    }

    func _test_currentStableRatio() -> Float {
        computeStableRatio()
    }
    #endif
}

// MARK: - Int → TimeInterval helper

private extension Int {
    var ms: TimeInterval { TimeInterval(self) / 1000.0 }
}
