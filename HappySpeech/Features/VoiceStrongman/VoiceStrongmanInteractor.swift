import Foundation
import OSLog

// MARK: - VoiceStrongmanBusinessLogic

@MainActor
protocol VoiceStrongmanBusinessLogic: AnyObject {
    func start(_ request: VoiceStrongmanModels.Start.Request) async
    func playPrompt()
    func selectLevel(_ request: VoiceStrongmanModels.SelectLevel.Request)
    func selectDirection(_ request: VoiceStrongmanModels.SelectDirection.Request)
    func startRecording() async
    func stopRecording() async
    func advance() async
    func cancel()
}

// MARK: - VoiceStrongmanInteractor
//
// Бизнес-логика «Силача-голоса». Два режима, проходимые последовательно
// (громкость → высота), внутри каждого — несколько заданий из корпуса.
//
//   • start          — собирает сессию через `VoiceStrongmanCorpus` по возрасту,
//                      выставляет первый режим и первое задание.
//   • playPrompt     — озвучивает образец/подсказку Ляли.
//   • selectLevel    — выбор зверька-уровня (тихо/средне/громко): меняет зону
//                      комфортной громкости.
//   • selectDirection— выбор направления глиссандо (вверх/вниз).
//   • startRecording — захват голоса (`VoiceStrongmanCapturing`): RMS-громкость
//                      и питч-контур. Live-стрим в presenter.
//   • stopRecording  — анализ по режиму через `VoiceStrongmanAnalyzer`:
//        громкость → доля кадров в комфортной зоне (антикрик),
//        высота    → пройденная доля лесенки + совпадение направления.
//   • advance        — следующее задание / следующий режим / завершение.
//
// Безоценочность: ни один режим не «проваливает» ребёнка. matchRate влияет
// только на число звёзд (минимум 1) и SM-2 quality для адаптивного планировщика.

@MainActor
final class VoiceStrongmanInteractor: VoiceStrongmanBusinessLogic {

    // MARK: - VIP

    var presenter: (any VoiceStrongmanPresentationLogic)?

    // MARK: - Deps

    private let childId: String
    private let childAge: Int
    private let voice: LessonVoiceWorker
    private let capture: any VoiceStrongmanCapturing
    private let analyzer: VoiceStrongmanAnalyzer
    private let adaptivePlanner: (any AdaptivePlannerService)?
    /// Тестовый seam: детерминированная сессия в юнит-тестах (в проде nil).
    private let seededSession: VoiceStrongmanSession?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "VoiceStrongman.Interactor")

    // MARK: - State

    private var session = VoiceStrongmanSession(loudness: [], pitch: [])
    private var modeOrder: [VoiceStrongmanMode] = []
    private var modePointer: Int = 0
    private var taskPointer: Int = 0

    // Громкость: выбранный уровень (может отличаться от целевого — выбор ребёнка).
    private var currentLevel: LoudnessLevel = .medium
    // Высота: выбранное направление.
    private var currentDirection: PitchDirection = .up
    // Ребёнок явно сменил уровень/направление в текущем задании — уважаем выбор
    // и не сбрасываем обратно к целевому при перерисовке. Сбрасывается при
    // переходе к следующему заданию (`resetTaskState`).
    private var levelOverridden = false
    private var directionOverridden = false

    // Прогресс/счёт.
    private var attempts: Int = 0
    private var matches: Int = 0
    private var lastAttemptMatched = false
    private var isFinished = false
    private var isRecording = false

    private var speakTask: Task<Void, Never>?
    private var liveTask: Task<Void, Never>?

    // MARK: - Init

    init(
        childId: String,
        childAge: Int,
        voice: LessonVoiceWorker = .shared,
        capture: any VoiceStrongmanCapturing,
        analyzer: VoiceStrongmanAnalyzer = VoiceStrongmanAnalyzer(),
        adaptivePlanner: (any AdaptivePlannerService)? = nil,
        seededSession: VoiceStrongmanSession? = nil
    ) {
        self.childId = childId
        self.childAge = max(5, min(childAge, 8))
        self.voice = voice
        self.capture = capture
        self.analyzer = analyzer
        self.adaptivePlanner = adaptivePlanner
        self.seededSession = seededSession
    }

    deinit {
        speakTask?.cancel()
        liveTask?.cancel()
    }

    // MARK: - start

    func start(_ request: VoiceStrongmanModels.Start.Request) async {
        session = seededSession ?? VoiceStrongmanCorpus.buildSession(age: childAge)
        modeOrder = [VoiceStrongmanMode]([
            session.loudness.isEmpty ? nil : .loudness,
            session.pitch.isEmpty ? nil : .pitch
        ].compactMap { $0 })
        modePointer = 0
        taskPointer = 0
        attempts = 0
        matches = 0
        isFinished = false
        levelOverridden = false
        directionOverridden = false
        guard !modeOrder.isEmpty else {
            logger.error("VoiceStrongman session empty — nothing to play")
            await complete()
            return
        }
        logger.info("start child=\(self.childId, privacy: .public) modes=\(self.modeOrder.count, privacy: .public)")
        presentCurrentTask()
    }

    // MARK: - playPrompt (озвучка подсказки Ляли)

    func playPrompt() {
        let text: String
        switch currentMode {
        case .loudness:
            guard let task = currentLoudnessTask else { return }
            text = task.prompt
        case .pitch:
            guard let task = currentPitchTask else { return }
            text = task.prompt
        }
        speak(text)
    }

    // MARK: - selectLevel

    func selectLevel(_ request: VoiceStrongmanModels.SelectLevel.Request) {
        guard currentMode == .loudness else { return }
        currentLevel = request.level
        levelOverridden = true
        presentCurrentTask()
    }

    // MARK: - selectDirection

    func selectDirection(_ request: VoiceStrongmanModels.SelectDirection.Request) {
        guard currentMode == .pitch else { return }
        currentDirection = request.direction
        directionOverridden = true
        presentCurrentTask()
    }

    // MARK: - Recording

    func startRecording() async {
        guard !isRecording, !isFinished else { return }
        do {
            try await capture.start()
            isRecording = true
            presenter?.presentRecording(true)
            startLiveStream()
            logger.info("recording started mode=\(self.currentMode.rawValue, privacy: .public)")
        } catch VoiceStrongmanCaptureError.microphonePermissionDenied {
            // Без доступа к микрофону игра молча давала бы 1★ — показываем
            // понятное сообщение вместо тихого провала.
            isRecording = false
            logger.info("recording blocked: microphone permission denied")
            presenter?.presentRecording(false)
            presenter?.presentMicrophoneDenied()
        } catch {
            logger.error("capture start failed: \(error.localizedDescription, privacy: .public)")
            isRecording = false
            presenter?.presentRecording(false)
        }
    }

    func stopRecording() async {
        guard isRecording else { return }
        isRecording = false
        liveTask?.cancel()
        liveTask = nil
        capture.stop()
        presenter?.presentRecording(false)
        let snapshot = await capture.finalSnapshot()
        evaluate(snapshot: snapshot)
    }

    private func startLiveStream() {
        liveTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled, self.isRecording {
                let snapshot = await self.capture.liveSnapshot()
                self.presentLive(snapshot: snapshot)
                try? await Task.sleep(nanoseconds: 70_000_000)
            }
        }
    }

    private func presentLive(snapshot: VoiceStrongmanSnapshot) {
        switch currentMode {
        case .loudness:
            let inBand = analyzer.isInBand(loudness: snapshot.loudness, level: currentLevel)
            presenter?.presentLiveSample(.init(
                loudness: snapshot.loudness,
                pitchNorm: 0,
                inTarget: inBand,
                liveContour: []
            ))
        case .pitch:
            presenter?.presentLiveSample(.init(
                loudness: snapshot.loudness,
                pitchNorm: snapshot.pitchNorm,
                inTarget: false,
                liveContour: snapshot.contour
            ))
        }
    }

    // MARK: - Evaluation (per mode)

    private func evaluate(snapshot: VoiceStrongmanSnapshot) {
        attempts += 1
        switch currentMode {
        case .loudness: evaluateLoudness(snapshot: snapshot)
        case .pitch:    evaluatePitch(snapshot: snapshot)
        }
    }

    private func evaluateLoudness(snapshot: VoiceStrongmanSnapshot) {
        let average = analyzer.averageLoudness(frames: snapshot.loudnessFrames)
        let inBand = analyzer.didHitBand(frames: snapshot.loudnessFrames, level: currentLevel)
        lastAttemptMatched = inBand
        if inBand { matches += 1 }
        presenter?.presentScore(.init(
            mode: .loudness,
            loudnessAverage: average,
            loudnessInBand: inBand,
            ladderReached: 0,
            directionMatched: false,
            liveContour: [],
            isMatch: inBand
        ))
    }

    private func evaluatePitch(snapshot: VoiceStrongmanSnapshot) {
        let reached = analyzer.ladderReached(contour: snapshot.contour, direction: currentDirection)
        let directionMatched = analyzer.didMatchDirection(
            contour: snapshot.contour, direction: currentDirection
        )
        let climbed = reached >= VoiceStrongmanScoring.ladderReachThreshold && directionMatched
        lastAttemptMatched = climbed
        if climbed { matches += 1 }
        presenter?.presentScore(.init(
            mode: .pitch,
            loudnessAverage: 0,
            loudnessInBand: false,
            ladderReached: reached,
            directionMatched: directionMatched,
            liveContour: snapshot.contour,
            isMatch: climbed
        ))
    }

    // MARK: - advance

    func advance() async {
        guard !isFinished else { return }
        await recordItemOutcome()

        // Следующее задание внутри режима.
        if taskPointer + 1 < taskCount(for: currentMode) {
            taskPointer += 1
            resetTaskState()
            presentCurrentTask()
            return
        }

        // Следующий режим.
        if modePointer + 1 < modeOrder.count {
            modePointer += 1
            taskPointer = 0
            resetTaskState()
            presentCurrentTask()
            return
        }

        await complete()
    }

    // MARK: - complete

    private func complete() async {
        guard !isFinished else { return }
        isFinished = true
        liveTask?.cancel()
        speakTask?.cancel()
        voice.stop()
        let rate = attempts == 0 ? 0 : Float(matches) / Float(attempts)
        logger.info("complete matches=\(self.matches, privacy: .public)/\(self.attempts, privacy: .public)")
        await recordSession(matchRate: rate)
        presenter?.presentComplete(.init(
            tasksCompleted: attempts,
            totalTasks: max(attempts, 1),
            matchRate: rate
        ))
    }

    // MARK: - cancel

    func cancel() {
        isFinished = true
        isRecording = false
        liveTask?.cancel(); liveTask = nil
        speakTask?.cancel(); speakTask = nil
        capture.stop()
        voice.stop()
        logger.info("VoiceStrongman cancelled")
    }

    // MARK: - Presentation

    private func presentCurrentTask() {
        let mode = currentMode
        var vowel = ""
        var prompt = ""
        var mascot = ""
        var level = currentLevel
        var animal = ""
        var direction = currentDirection
        var steps = 5
        let subtitle: String

        switch mode {
        case .loudness:
            guard let task = currentLoudnessTask else { return }
            // По умолчанию подсветить целевой уровень задания; если ребёнок уже
            // выбрал свой уровень в этом задании — уважаем его выбор.
            if !levelOverridden { currentLevel = task.level }
            level = currentLevel
            vowel = task.vowel
            prompt = task.prompt
            animal = task.animal
            mascot = task.hint
            subtitle = String(localized: "voiceStrongman.subtitle.loudness",
                              defaultValue: "Голос управляет шаром")
        case .pitch:
            guard let task = currentPitchTask else { return }
            if !directionOverridden { currentDirection = task.direction }
            direction = currentDirection
            steps = task.steps
            vowel = task.vowel
            prompt = task.prompt
            mascot = task.hint
            subtitle = String(localized: "voiceStrongman.subtitle.pitch",
                              defaultValue: "Веди голос по ступенькам")
        }

        presenter?.presentStart(VoiceStrongmanStartViewModel(
            mode: mode,
            phase: phase(for: mode),
            title: mode.title,
            subtitle: subtitle,
            mascotText: mascot,
            taskIndex: taskPointer,
            totalTasks: taskCount(for: mode),
            vowel: vowel,
            prompt: prompt,
            loudnessLevel: level,
            animal: animal,
            bandLower: CGFloat(level.lowerBound),
            bandUpper: CGFloat(level.upperBound),
            pitchDirection: direction,
            ladderSteps: steps
        ))
    }

    // MARK: - Persistence

    private func recordItemOutcome() async {
        guard let planner = adaptivePlanner else { return }
        await planner.recordItemOutcome(
            childId: childId,
            itemId: currentItemId,
            sound: "голос",
            correct: lastAttemptMatched
        )
    }

    private func recordSession(matchRate: Float) async {
        guard let planner = adaptivePlanner else { return }
        let quality = SM2Quality.fromSuccessRate(Double(matchRate))
        do {
            try await planner.recordSessionResult(
                childId: childId,
                soundTarget: "голос",
                qualityScore: quality
            )
        } catch {
            logger.error("recordSessionResult failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Voice

    private func speak(_ text: String) {
        guard !text.isEmpty else { return }
        speakTask?.cancel()
        voice.stop()
        presenter?.presentPlaying(true)
        speakTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.voice.speak(text, lessonType: "voice_strongman")
            guard !Task.isCancelled, !self.isFinished else { return }
            self.presenter?.presentPlaying(false)
            self.speakTask = nil
        }
    }

    // MARK: - Helpers / accessors

    private var currentMode: VoiceStrongmanMode {
        modeOrder.indices.contains(modePointer) ? modeOrder[modePointer] : .loudness
    }
    private var currentLoudnessTask: LoudnessExercise? {
        session.loudness.indices.contains(taskPointer) ? session.loudness[taskPointer] : nil
    }
    private var currentPitchTask: PitchExercise? {
        session.pitch.indices.contains(taskPointer) ? session.pitch[taskPointer] : nil
    }
    private var currentItemId: String {
        switch currentMode {
        case .loudness: return currentLoudnessTask?.id ?? "loud-?"
        case .pitch:    return currentPitchTask?.id ?? "pitch-?"
        }
    }

    private func taskCount(for mode: VoiceStrongmanMode) -> Int {
        switch mode {
        case .loudness: return session.loudness.count
        case .pitch:    return session.pitch.count
        }
    }

    private func phase(for mode: VoiceStrongmanMode) -> VoiceStrongmanPhase {
        switch mode {
        case .loudness: return .loudness
        case .pitch:    return .pitch
        }
    }

    private func resetTaskState() {
        // Новое задание начинается с целевого уровня/направления — снимаем
        // пользовательские override'ы предыдущего задания.
        levelOverridden = false
        directionOverridden = false
    }

    // MARK: - Test seams

    /// Доля совпавших попыток (для тестов и расчётов).
    var matchFraction: Float {
        attempts == 0 ? 0 : Float(matches) / Float(attempts)
    }
}
