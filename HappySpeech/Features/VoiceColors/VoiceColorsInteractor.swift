import Foundation
import OSLog

// MARK: - VoiceColorsBusinessLogic

@MainActor
protocol VoiceColorsBusinessLogic: AnyObject {
    func start(_ request: VoiceColorsModels.Start.Request) async
    func playModel()
    func selectIntonation(_ request: VoiceColorsModels.SelectIntonation.Request)
    func selectStressWord(_ request: VoiceColorsModels.SelectStressWord.Request)
    func selectEmotion(_ request: VoiceColorsModels.SelectEmotion.Request)
    func startRecording() async
    func stopRecording() async
    func advance() async
    func cancel()
}

// MARK: - VoiceColorsInteractor
//
// Бизнес-логика «Голосовых красок». Три режима, проходимые последовательно
// (интонация → ударение → эмоция), внутри каждого — несколько заданий.
//
//   • start            — собирает сессию через `VoiceColorsCorpus` по возрасту,
//                        выставляет первый режим и первое задание.
//   • playModel        — озвучивает образец Ляли (фраза в нужной краске).
//   • selectIntonation — выбор «домика» (вопрос/восклицание/спокойно): меняет
//                        целевой контур и подсказку.
//   • selectStressWord — выбор главного слова (какое выделить голосом).
//   • selectEmotion    — выбор эмоции, которой произнести фразу.
//   • startRecording   — захват голоса (`VoiceCaptureControlling`): pitch-контур,
//                        амплитудная огибающая, PCM. Live-стрим в presenter.
//   • stopRecording    — анализ по режиму:
//        интонация → `ContourComparator` (сходство контура с целевым),
//        ударение  → `WordStressAnalyzer` (самое громкое слово vs целевое),
//        эмоция    → `EmotionDetectionService` (распознанная окраска → зеркало).
//   • advance          — следующее задание / следующий режим / завершение.
//
// Безоценочность: ни один режим не «проваливает» ребёнка. matchRate влияет
// только на число звёзд (минимум 1) и SM-2 quality для адаптивного планировщика.

@MainActor
final class VoiceColorsInteractor: VoiceColorsBusinessLogic {

    // MARK: - VIP

    var presenter: (any VoiceColorsPresentationLogic)?

    // MARK: - Deps

    private let childId: String
    private let childAge: Int
    private let voice: LessonVoiceWorker
    private let capture: any VoiceCaptureControlling
    private let comparator: ContourComparator
    private let stressAnalyzer: WordStressAnalyzer
    private let emotionService: (any EmotionDetectionServiceProtocol)?
    private let adaptivePlanner: (any AdaptivePlannerService)?
    /// Тестовый seam: детерминированная сессия в юнит-тестах (в проде nil).
    private let seededSession: VoiceColorsSession?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "VoiceColors.Interactor")

    // MARK: - State

    private var session = VoiceColorsSession(intonation: [], stress: [], emotion: [])
    private var modeOrder: [VoiceColorsMode] = []
    private var modePointer: Int = 0
    private var taskPointer: Int = 0

    // Интонация: выбранный домик, успешно пройденные (галочка) и просто
    // попробованные краски текущего задания (для цикла по домикам).
    private var currentIntonation: IntonationMode = .question
    private var doneIntonationModes: Set<IntonationMode> = []
    private var attemptedIntonationModes: Set<IntonationMode> = []

    // Ударение: целевое слово (по вопросу) и выбранное ребёнком.
    private var stressTargetIndex: Int = 0
    private var stressTargetCursor: Int = 0   // какой target текущего задания активен
    private var stressChosenIndex: Int = 0

    // Эмоция: выбранная окраска.
    private var currentEmotion: VoiceEmotion = .joy

    // Прогресс/счёт.
    private var attempts: Int = 0
    private var matches: Int = 0
    /// Совпала ли последняя попытка (для пословного outcome планировщика).
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
        capture: any VoiceCaptureControlling,
        comparator: ContourComparator = ContourComparator(),
        stressAnalyzer: WordStressAnalyzer = WordStressAnalyzer(),
        emotionService: (any EmotionDetectionServiceProtocol)? = nil,
        adaptivePlanner: (any AdaptivePlannerService)? = nil,
        seededSession: VoiceColorsSession? = nil
    ) {
        self.childId = childId
        self.childAge = max(5, min(childAge, 8))
        self.voice = voice
        self.capture = capture
        self.comparator = comparator
        self.stressAnalyzer = stressAnalyzer
        self.emotionService = emotionService
        self.adaptivePlanner = adaptivePlanner
        self.seededSession = seededSession
    }

    deinit {
        speakTask?.cancel()
        liveTask?.cancel()
    }

    // MARK: - start

    func start(_ request: VoiceColorsModels.Start.Request) async {
        session = seededSession ?? VoiceColorsCorpus.buildSession(age: childAge)
        // Порядок режимов — только непустые, в методической градации.
        modeOrder = [VoiceColorsMode]([
            session.intonation.isEmpty ? nil : .intonation,
            session.stress.isEmpty ? nil : .stress,
            session.emotion.isEmpty ? nil : .emotion
        ].compactMap { $0 })
        modePointer = 0
        taskPointer = 0
        attempts = 0
        matches = 0
        isFinished = false
        doneIntonationModes = []
        attemptedIntonationModes = []
        guard !modeOrder.isEmpty else {
            logger.error("VoiceColors session empty — nothing to play")
            await complete()
            return
        }
        logger.info("start child=\(self.childId, privacy: .private) modes=\(self.modeOrder.count, privacy: .public)")
        presentCurrentTask()
    }

    // MARK: - playModel (озвучка образца Ляли)

    func playModel() {
        let text: String
        switch currentMode {
        case .intonation:
            guard let task = currentIntonationTask else { return }
            text = task.text
        case .stress:
            guard let task = currentStressTask else { return }
            text = task.words.joined(separator: " ")
        case .emotion:
            guard let task = currentEmotionTask,
                  let opt = task.option(for: currentEmotion) else { return }
            text = opt.phrase
        }
        speak(text)
    }

    // MARK: - selectIntonation

    func selectIntonation(_ request: VoiceColorsModels.SelectIntonation.Request) {
        guard currentMode == .intonation, let task = currentIntonationTask,
              let variant = task.variant(for: request.mode) else { return }
        currentIntonation = request.mode
        let contour = VoiceColorsCorpus.targetContour(for: request.mode)
        presenter?.presentSelectIntonation(.init(
            mode: request.mode,
            mark: variant.mark,
            hint: variant.hint,
            targetContour: contour
        ))
    }

    // MARK: - selectStressWord

    func selectStressWord(_ request: VoiceColorsModels.SelectStressWord.Request) {
        guard currentMode == .stress, let task = currentStressTask,
              task.words.indices.contains(request.wordIndex) else { return }
        stressChosenIndex = request.wordIndex
        presenter?.presentSelectStressWord(.init(
            chosenIndex: request.wordIndex,
            targetIndex: stressTargetIndex,
            question: currentStressTarget?.question ?? ""
        ))
    }

    // MARK: - selectEmotion

    func selectEmotion(_ request: VoiceColorsModels.SelectEmotion.Request) {
        guard currentMode == .emotion, let task = currentEmotionTask,
              let opt = task.option(for: request.emotion) else { return }
        currentEmotion = request.emotion
        presenter?.presentSelectEmotion(.init(
            emotion: request.emotion,
            phrase: opt.phrase,
            hint: opt.hint
        ))
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
        } catch VoiceCaptureError.microphonePermissionDenied {
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
        await evaluate(snapshot: snapshot)
    }

    private func startLiveStream() {
        liveTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled, self.isRecording {
                let snapshot = await self.capture.liveSnapshot()
                self.presenter?.presentLiveSample(.init(
                    liveContour: snapshot.contour,
                    amplitude: snapshot.amplitude
                ))
                try? await Task.sleep(nanoseconds: 80_000_000)
            }
        }
    }

    // MARK: - Evaluation (per mode)

    private func evaluate(snapshot: VoiceCaptureSnapshot) async {
        attempts += 1
        switch currentMode {
        case .intonation:  evaluateIntonation(snapshot: snapshot)
        case .stress:      evaluateStress(snapshot: snapshot)
        case .emotion:     await evaluateEmotion(snapshot: snapshot)
        }
    }

    private func evaluateIntonation(snapshot: VoiceCaptureSnapshot) {
        let model = VoiceColorsCorpus.targetContour(for: currentIntonation)
        let similarity = comparator.similarity(model: model, live: snapshot.contour)
        let isMatch = similarity >= VoiceColorsScoring.intonationMatchThreshold
        lastAttemptMatched = isMatch
        attemptedIntonationModes.insert(currentIntonation)
        if isMatch { matches += 1; doneIntonationModes.insert(currentIntonation) }
        presenter?.presentScore(.init(
            mode: .intonation,
            intonationSimilarity: similarity,
            modelContour: model,
            liveContour: snapshot.contour,
            loudestWordIndex: -1,
            targetWordIndex: -1,
            perWordRMS: [],
            detectedEmotion: .joy,
            chosenEmotion: .joy,
            isMatch: isMatch
        ))
    }

    private func evaluateStress(snapshot: VoiceCaptureSnapshot) {
        guard let task = currentStressTask else { return }
        let rms = stressAnalyzer.perWordRMS(
            envelope: snapshot.amplitudeEnvelope, wordCount: task.words.count
        )
        let loudest = stressAnalyzer.loudestIndex(perWordRMS: rms)
        let isMatch = stressAnalyzer.didEmphasiseTarget(perWordRMS: rms, targetIndex: stressTargetIndex)
        lastAttemptMatched = isMatch
        if isMatch { matches += 1 }
        presenter?.presentScore(.init(
            mode: .stress,
            intonationSimilarity: 0,
            modelContour: [],
            liveContour: [],
            loudestWordIndex: loudest,
            targetWordIndex: stressTargetIndex,
            perWordRMS: rms,
            detectedEmotion: .joy,
            chosenEmotion: .joy,
            isMatch: isMatch
        ))
    }

    private func evaluateEmotion(snapshot: VoiceCaptureSnapshot) async {
        // Распознаём окраску голоса. При отсутствии сервиса / пустой записи
        // «зеркалим» выбранную ребёнком эмоцию (безоценочный модуль).
        var detected = currentEmotion
        // Тишина / нейтральная (немая) попытка не должна засчитываться как
        // совпадение — иначе ребёнок получает «успех» за молчание (звёзды за
        // не-речь). Интонация/ударение честно дают no-match на тишину; приводим
        // эмоцию к той же честности.
        var isNeutralOrSilent = snapshot.pcmData.isEmpty
        if let service = emotionService, !snapshot.pcmData.isEmpty {
            let result = await service.analyze(pcmData: snapshot.pcmData)
            isNeutralOrSilent = result.emotion == .neutral
            detected = VoiceEmotion.from(detected: result.emotion)
        }
        // Совпадение — мягкое: считается, если распознанная окраска = выбранной
        // И попытка не была нейтральной/немой.
        let isMatch = !isNeutralOrSilent && detected == currentEmotion
        lastAttemptMatched = isMatch
        if isMatch { matches += 1 }
        // Ляля всегда отражает выбранную эмоцию (зеркало поддержки, не оценка):
        // если модель не уверена, ребёнок не получает «непохоже».
        let reflected = isMatch ? detected : currentEmotion
        presenter?.presentScore(.init(
            mode: .emotion,
            intonationSimilarity: 0,
            modelContour: [],
            liveContour: [],
            loudestWordIndex: -1,
            targetWordIndex: -1,
            perWordRMS: [],
            detectedEmotion: reflected,
            chosenEmotion: currentEmotion,
            isMatch: isMatch
        ))
    }

    // MARK: - advance

    func advance() async {
        guard !isFinished else { return }
        await recordItemOutcome()

        // Внутри интонации проходим оставшиеся «домики» одной фразы по очереди
        // (вопрос → восклицание → спокойно), пока есть непройденные краски.
        if currentMode == .intonation, let task = currentIntonationTask,
           let nextMode = nextIntonationMode(in: task) {
            currentIntonation = nextMode
            presentCurrentTask()
            return
        }

        // Внутри ударения проходим все целевые позиции одной фразы по очереди.
        if currentMode == .stress, let task = currentStressTask,
           stressTargetCursor + 1 < task.targets.count {
            stressTargetCursor += 1
            applyStressTarget()
            presenter?.presentSelectStressWord(.init(
                chosenIndex: stressChosenIndex,
                targetIndex: stressTargetIndex,
                question: currentStressTarget?.question ?? ""
            ))
            presentCurrentTask(resetSelection: true)
            return
        }

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
        logger.info("VoiceColors cancelled")
    }

    // MARK: - Presentation

    private func presentCurrentTask(resetSelection: Bool = false) {
        let mode = currentMode
        var vmIntonationMode = currentIntonation
        var vmMark = "?"
        var vmContour: [PitchPoint] = []
        var phrase = ""
        var stressWords: [String] = []
        var stressEmojis: [String] = []
        var stressQuestion = ""
        var stressQuestionEmoji = ""
        var emotionPhrase = ""
        var firstEmotion = currentEmotion
        var mascot = ""
        var subtitle = ""

        switch mode {
        case .intonation:
            guard let task = currentIntonationTask else { return }
            phrase = task.text
            // По умолчанию — первый доступный домик (вопрос).
            let first = task.variants.first?.mode ?? .question
            if resetSelection || !task.variants.contains(where: { $0.mode == currentIntonation }) {
                currentIntonation = first
            }
            vmIntonationMode = currentIntonation
            vmMark = task.variant(for: currentIntonation)?.mark ?? currentIntonation.mark
            vmContour = VoiceColorsCorpus.targetContour(for: currentIntonation)
            mascot = task.variant(for: currentIntonation)?.hint ?? ""
            subtitle = String(localized: "voiceColors.subtitle.intonation",
                              defaultValue: "Скажи фразу с разной интонацией")

        case .stress:
            guard let task = currentStressTask else { return }
            stressWords = task.words
            stressEmojis = task.words.indices.map { idx in
                task.targets.first(where: { $0.index == idx })?.emoji ?? ""
            }
            applyStressTarget()
            stressQuestion = currentStressTarget?.question ?? ""
            stressQuestionEmoji = currentStressTarget?.emoji ?? ""
            mascot = String(
                format: String(localized: "voiceColors.mascot.stress %@",
                               defaultValue: "Скажи слово «%@» как будто стукнул в барабан — погромче. Остальные — тихонько."),
                stressWords.indices.contains(stressTargetIndex) ? stressWords[stressTargetIndex].uppercased() : ""
            )
            subtitle = String(localized: "voiceColors.subtitle.stress",
                              defaultValue: "Выдели голосом главное слово")

        case .emotion:
            guard let task = currentEmotionTask else { return }
            let first = task.options.first?.emotion ?? .joy
            if resetSelection || !task.options.contains(where: { $0.emotion == currentEmotion }) {
                currentEmotion = first
            }
            firstEmotion = currentEmotion
            emotionPhrase = task.option(for: currentEmotion)?.phrase ?? task.text
            phrase = task.text
            mascot = task.option(for: currentEmotion)?.hint ?? ""
            subtitle = String(localized: "voiceColors.subtitle.emotion",
                              defaultValue: "Скажи фразу с разным настроением")
        }

        presenter?.presentStart(VoiceColorsStartViewModel(
            mode: mode,
            phase: phase(for: mode),
            title: mode.title,
            subtitle: subtitle,
            mascotText: mascot,
            taskIndex: taskPointer,
            totalTasks: taskCount(for: mode),
            phraseText: phrase,
            firstIntonationMode: vmIntonationMode,
            firstMark: vmMark,
            firstContour: vmContour,
            doneIntonationModes: doneIntonationModes,
            stressWords: stressWords,
            stressEmojis: stressEmojis,
            targetWordIndex: stressTargetIndex,
            stressQuestion: stressQuestion,
            stressQuestionEmoji: stressQuestionEmoji,
            emotionPhrase: emotionPhrase,
            firstEmotion: firstEmotion
        ))
    }

    private func applyStressTarget() {
        guard let task = currentStressTask, task.targets.indices.contains(stressTargetCursor) else {
            return
        }
        stressTargetIndex = task.targets[stressTargetCursor].index
        stressChosenIndex = stressTargetIndex
    }

    /// Следующая непройденная интонация задания в каноническом порядке
    /// (вопрос → восклицание → спокойно). `nil`, если все краски пройдены.
    private func nextIntonationMode(in task: IntonationTask) -> IntonationMode? {
        let available = IntonationMode.allCases.filter { mode in
            task.variants.contains { $0.mode == mode }
        }
        // Цикл идёт по ПОПЫТКАМ (не по успеху): даже если краска не совпала,
        // ребёнок двигается дальше — модуль безоценочный, без застревания.
        return available.first { !attemptedIntonationModes.contains($0) }
    }

    // MARK: - Persistence

    private func recordItemOutcome() async {
        guard let planner = adaptivePlanner else { return }
        await planner.recordItemOutcome(
            childId: childId,
            itemId: currentItemId,
            sound: "просодика",
            correct: lastAttemptMatched
        )
    }

    private func recordSession(matchRate: Float) async {
        guard let planner = adaptivePlanner else { return }
        let quality = SM2Quality.fromSuccessRate(Double(matchRate))
        do {
            try await planner.recordSessionResult(
                childId: childId,
                soundTarget: "просодика",
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
            await self.voice.speak(text, lessonType: "voice_colors")
            guard !Task.isCancelled, !self.isFinished else { return }
            self.presenter?.presentPlaying(false)
            self.speakTask = nil
        }
    }

    // MARK: - Helpers / accessors

    private var currentMode: VoiceColorsMode {
        modeOrder.indices.contains(modePointer) ? modeOrder[modePointer] : .intonation
    }
    private var currentIntonationTask: IntonationTask? {
        session.intonation.indices.contains(taskPointer) ? session.intonation[taskPointer] : nil
    }
    private var currentStressTask: StressTask? {
        session.stress.indices.contains(taskPointer) ? session.stress[taskPointer] : nil
    }
    private var currentStressTarget: StressTask.Target? {
        guard let task = currentStressTask, task.targets.indices.contains(stressTargetCursor) else {
            return nil
        }
        return task.targets[stressTargetCursor]
    }
    private var currentEmotionTask: EmotionTask? {
        session.emotion.indices.contains(taskPointer) ? session.emotion[taskPointer] : nil
    }
    private var currentItemId: String {
        switch currentMode {
        case .intonation: return currentIntonationTask?.id ?? "into-?"
        case .stress:     return (currentStressTask?.id ?? "stress-?") + "-\(stressTargetIndex)"
        case .emotion:    return currentEmotionTask?.id ?? "emo-?"
        }
    }

    private func taskCount(for mode: VoiceColorsMode) -> Int {
        switch mode {
        case .intonation: return session.intonation.count
        case .stress:     return session.stress.count
        case .emotion:    return session.emotion.count
        }
    }

    private func phase(for mode: VoiceColorsMode) -> VoiceColorsPhase {
        switch mode {
        case .intonation: return .intonation
        case .stress:     return .stress
        case .emotion:    return .emotion
        }
    }

    private func resetTaskState() {
        stressTargetCursor = 0
        stressTargetIndex = 0
        stressChosenIndex = 0
        doneIntonationModes = []
        attemptedIntonationModes = []
    }

    // MARK: - Test seams

    /// Доля совпавших попыток (для тестов и расчётов).
    var matchFraction: Float {
        attempts == 0 ? 0 : Float(matches) / Float(attempts)
    }
}
