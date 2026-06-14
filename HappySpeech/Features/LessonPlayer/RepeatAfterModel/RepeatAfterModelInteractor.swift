import Foundation
import OSLog

// MARK: - RepeatAfterModelBusinessLogic

@MainActor
protocol RepeatAfterModelBusinessLogic: AnyObject {
    func loadSession(_ request: RepeatAfterModelModels.LoadSession.Request)
    func startWord(_ request: RepeatAfterModelModels.StartWord.Request)
    func toggleRecording()
    func startRecordingIntent()
    func stopRecordingIntent()
    func submitTranscript(_ request: RepeatAfterModelModels.EvaluateAttempt.Request)
    func handleNoInput(_ request: RepeatAfterModelModels.NoInput.Request)
    func submitMLScore(_ request: RepeatAfterModelModels.MLEvaluate.Request)
    func advanceWord()
    func completeSession()
    func requestHint(_ request: RepeatAfterModelModels.Hint.Request)
    func requestSloMo(_ request: RepeatAfterModelModels.SloMo.Request)
    func replayModel(_ request: RepeatAfterModelModels.ReplayModel.Request)
    func cancel()
}

// MARK: - RepeatAfterModelInteractor
//
// Игра «Повтори за Лялей»:
//   loading → [wordPreview → recording → feedback] × N → completed
//
// Расширенная логика (A.16 v14):
//   • До maxAttempts (3) попыток на каждое слово.
//   • После 3-й неудачной — forced advance (canAdvance=true, passed=false).
//   • 5-10 раундов в сессии (wordsPerSession).
//   • Replay model audio: до replayLimit раз за слово.
//   • Slo-mo режим: флаг sloMoRequested для View.
//   • 3-ступенчатая система подсказок (слогоразделение → артикуляционная схема → slo-mo).
//   • ML-скор через PronunciationScorerService (primaryScore) +
//     ASR-скор через RepeatScoring (secondaryScore) → финальный weighted blend.
//   • Диагностика ошибки: distortion / substitution / omission / addition.
//   • Encouragement при улучшении результата между попытками.
//   • Итог: нормализованный средний лучший-за-слово, starsEarned [0..3].
//   • Block H: KidLLMNarrationService для адаптивного feedback (Tier A/C).
//   • Persistence-stub: bestScorePerWord, attemptHistoryPerWord для экспорта.

@MainActor
final class RepeatAfterModelInteractor: RepeatAfterModelBusinessLogic {

    // MARK: - Dependencies

    var presenter: (any RepeatAfterModelPresentationLogic)?
    private var narrationService: (any KidLLMNarrationServiceProtocol)?
    /// F1-016: планировщик интервальных повторов — фиксируем исход каждой
    /// зачтённой/незачтённой попытки слова в дневном расписании повторов.
    private var reviewScheduler: (any ReviewSchedulerService)?
    /// Запись с микрофона. Внедряется по DI из View (gap #10) — пайплайн
    /// записи/ASR живёт в Interactor, не во View (Clean Swift / VIP).
    private var audioService: (any AudioService)?
    /// Распознавание речи (WhisperKit + word-list biasing на ожидаемое слово).
    private var asrService: (any ASRService)?
    /// Активная задача записи/ASR. Отменяется при cancel() и повторном старте.
    private var recordingTask: Task<Void, Never>?
    private let logger = HSLogger.asr

    // MARK: - Tunables

    /// Количество слов в одной сессии (5–10 в зависимости от длительности).
    private let wordsPerSession: Int = 6
    /// Максимум попыток на слово (детский UX: не блокировать ребёнка).
    private let maxAttempts: Int = 3
    /// Максимум прослушиваний эталона за слово до заблокирования кнопки.
    private let replayLimit: Int = 3
    /// Вес ML-скора в финальном blend (0.6 ML + 0.4 ASR).
    private let mlScoreWeight: Float = 0.6
    /// Порог «хорошо» — 80 из 100.
    private static let thresholdExcellent: Float = 0.80
    /// Порог «достаточно» — 60 из 100.
    private static let thresholdGood: Float = 0.60
    /// Порог «попробуй ещё» — 40 из 100.
    private static let thresholdTrying: Float = 0.40

    // MARK: - Session state

    private(set) var words: [TargetWordItem] = []
    private(set) var currentIndex: Int = 0
    private(set) var attemptsLeft: Int = 3
    private(set) var isRecording: Bool = false
    private(set) var childName: String = ""
    /// Активный ребёнок для записи исхода в расписание повторов (F1-016).
    private(set) var childId: String = ""

    /// Счётчик прослушиваний эталона для текущего слова.
    private var replayCountPerWord: [String: Int] = [:]

    /// Лучший финальный score на слово (ключ = word.id). Используется для итогового average.
    private var bestScorePerWord: [String: Float] = [:]

    /// История попыток: [wordId: [attemptScore]].
    /// Нужна для encouragement ("Уже лучше!") и будущего экспорта.
    private var attemptHistoryPerWord: [String: [Float]] = [:]

    /// Pending ML-score из PronunciationScorerService (хранится до получения ASR).
    private var pendingMLScore: Float?

    /// URL последней успешно записанной попытки ребёнка (16kHz mono WAV из
    /// `AudioService`). Источник РЕАЛЬНОГО аудио для on-device анализа эмоции
    /// (`EmotionDetectionService`) на уровне `SessionShell`. Обновляется в
    /// `stopAndTranscribe` после успешной остановки записи; nil до первой записи
    /// или при сбое (тогда эмоция не анализируется — без фабрикации).
    private(set) var lastRecordedURL: URL?

    /// Фоновая задача LLM-feedback (Block H). Отменяется при advanceWord/cancel.
    private var llmFeedbackTask: Task<Void, Never>?

    /// Активная подсказка для текущего слова (nil = не запрошена).
    private(set) var currentRepeatHintLevel: RepeatHintLevel = .none

    /// P2-4 (Fable): порядок слов раунда. В проде — реальный `shuffled()`, чтобы
    /// сессия не предъявляла одну и ту же последовательность каждый запуск. Тесты
    /// инъектируют детерминированный провайдер (identity / seeded), сохраняя ПОЛНЫЙ
    /// набор слов — перемешивается только порядок, ни одно слово не теряется.
    private let wordOrderProvider: ([TargetWordItem]) -> [TargetWordItem]

    // MARK: - Init

    init(
        narrationService: (any KidLLMNarrationServiceProtocol)? = nil,
        reviewScheduler: (any ReviewSchedulerService)? = nil,
        wordOrderProvider: @escaping ([TargetWordItem]) -> [TargetWordItem] = { $0.shuffled() }
    ) {
        self.narrationService = narrationService
        self.reviewScheduler = reviewScheduler
        self.wordOrderProvider = wordOrderProvider
    }

    // MARK: - Block H: подключение narrationService из View

    func connect(narrationService: any KidLLMNarrationServiceProtocol) {
        self.narrationService = narrationService
    }

    // MARK: - F1-016: подключение планировщика повторов из View

    func connect(reviewScheduler: any ReviewSchedulerService) {
        self.reviewScheduler = reviewScheduler
    }

    // MARK: - gap #10: подключение записи/ASR из View

    /// Внедряет сервисы записи и распознавания. Вызывается из View при
    /// bootstrap (`startSessionOnce`). До подключения `beginRecording`/
    /// `stopAndTranscribe` мягко переходят в noInput, не фабрикуя оценку.
    func connect(audioService: any AudioService, asrService: any ASRService) {
        self.audioService = audioService
        self.asrService = asrService
    }

    // MARK: - loadSession

    func loadSession(_ request: RepeatAfterModelModels.LoadSession.Request) {
        childName = request.childName
        childId = request.childId
        // P2-4 (Fable): перемешиваем ВЕСЬ пул, затем берём префикс — так порядок
        // слов раунда меняется от запуска к запуску (раньше — всегда фиксированный),
        // а при `count == pool.count` в сессию попадает полный набор слов группы.
        let pool = wordOrderProvider(TargetWordItem.words(for: request.soundGroup))
        // Берём до wordsPerSession слов из пула, но не меньше 2-х.
        let count = max(2, min(wordsPerSession, pool.count))
        words = Array(pool.prefix(count))
        currentIndex = 0
        attemptsLeft = maxAttempts
        bestScorePerWord = [:]
        attemptHistoryPerWord = [:]
        replayCountPerWord = [:]
        pendingMLScore = nil
        currentRepeatHintLevel = .none
        isRecording = false

        logger.info("repeat loadSession soundGroup=\(request.soundGroup, privacy: .public) count=\(self.words.count)")

        let response = RepeatAfterModelModels.LoadSession.Response(
            words: words,
            childName: childName,
            totalRounds: words.count
        )
        presenter?.presentLoadSession(response)
    }

    // MARK: - startWord

    func startWord(_ request: RepeatAfterModelModels.StartWord.Request) {
        guard !words.isEmpty else { return }
        currentIndex = max(0, min(request.wordIndex, words.count - 1))
        attemptsLeft = maxAttempts
        currentRepeatHintLevel = .none
        pendingMLScore = nil
        isRecording = false

        let word = words[currentIndex]
        let replayCount = replayCountPerWord[word.id] ?? 0
        let canReplay = replayCount < replayLimit

        let response = RepeatAfterModelModels.StartWord.Response(
            word: word,
            wordNumber: currentIndex + 1,
            total: words.count,
            attemptsLeft: attemptsLeft,
            canReplay: canReplay,
            replayCount: replayCount
        )
        presenter?.presentStartWord(response)
    }

    // MARK: - toggleRecording

    func toggleRecording() {
        isRecording.toggle()
        let response = RepeatAfterModelModels.RecordAttempt.Response(
            isRecording: isRecording,
            phase: .idle
        )
        presenter?.presentRecordAttempt(response)
    }

    // MARK: - Recording intents (gap #10: пайплайн записи из View → Interactor)

    /// Интент «начать запись» из View. Владеет жизненным циклом задачи записи —
    /// отменяется в cancel()/onDisappear, поэтому View не держит Task сам.
    func startRecordingIntent() {
        recordingTask?.cancel()
        recordingTask = Task { @MainActor [weak self] in
            await self?.beginRecording()
        }
    }

    /// Интент «остановить и распознать» из View.
    func stopRecordingIntent() {
        recordingTask?.cancel()
        recordingTask = Task { @MainActor [weak self] in
            await self?.stopAndTranscribe()
        }
    }

    /// Запускает запись с микрофона. Лениво запрашивает разрешение (в проде
    /// оно уже выдано на PermissionsView). Переводит UI в фазу `.recording`.
    /// При отказе/сбое — мягкий noInput, без фабрикации оценки.
    func beginRecording() async {
        guard let audioService else {
            handleNoInput(.init(reason: .recordingFailed))
            return
        }
        isRecording = true
        // Фаза .recording — экран записи (то же, что раньше делал View).
        presenter?.presentRecordAttempt(.init(isRecording: true, phase: .recording))

        if !audioService.isPermissionGranted {
            let granted = await audioService.requestPermission()
            if !granted {
                handleNoInput(.init(reason: .micDenied))
                return
            }
        }
        do {
            try await audioService.startRecording()
        } catch {
            logger.error("repeat beginRecording failed: \(error.localizedDescription, privacy: .public)")
            handleNoInput(.init(reason: .recordingFailed))
        }
    }

    // MARK: - stopAndTranscribe

    /// Останавливает запись, распознаёт речь с word-list biasing на ожидаемое
    /// слово урока и передаёт транскрипт в скоринг (`submitTranscript`).
    /// Переводит UI в фазу `.processing` на время ASR. При сбое — noInput.
    func stopAndTranscribe() async {
        guard let audioService, let asrService else {
            handleNoInput(.init(reason: .asrFailed))
            return
        }
        isRecording = false
        // Фаза .processing — «Проверяю…» пока идёт ASR (то же, что делал View).
        presenter?.presentRecordAttempt(.init(isRecording: false, phase: .processing))

        do {
            let url = try await audioService.stopRecording()
            // Сохраняем URL реальной записи — SessionShell прочитает из него PCM
            // для on-device анализа эмоции (COPPA: on-device, не сохраняется в облако).
            lastRecordedURL = url
            // Word-list biasing: ожидаемое слово урока повышает устойчивость
            // распознавания искажённой детской речи.
            let expected = currentIndex < words.count ? words[currentIndex].word : nil
            let result = try await asrService.transcribe(url: url, expectedWord: expected)
            submitTranscript(.init(
                transcript: result.transcript,
                confidence: Float(result.confidence)
            ))
        } catch {
            logger.error("repeat stopAndTranscribe failed: \(error.localizedDescription, privacy: .public)")
            handleNoInput(.init(reason: .asrFailed))
        }
    }

    // MARK: - replayModel

    /// Воспроизведение эталона Ляли. Ограничено replayLimit раз за слово.
    func replayModel(_ request: RepeatAfterModelModels.ReplayModel.Request) {
        guard currentIndex < words.count else { return }
        let word = words[currentIndex]
        let current = replayCountPerWord[word.id] ?? 0
        guard current < replayLimit else {
            // Лимит исчерпан — не разрешаем, сигнализируем через Presenter.
            let response = RepeatAfterModelModels.ReplayModel.Response(
                word: word,
                replayCount: current,
                replayLimitReached: true,
                audioFilename: word.audioFilename
            )
            presenter?.presentReplayModel(response)
            return
        }
        replayCountPerWord[word.id] = current + 1
        logger.info("repeat replayModel word=\(word.id, privacy: .public) count=\(current + 1)/\(self.replayLimit)")
        let response = RepeatAfterModelModels.ReplayModel.Response(
            word: word,
            replayCount: current + 1,
            replayLimitReached: (current + 1) >= replayLimit,
            audioFilename: word.audioFilename
        )
        presenter?.presentReplayModel(response)
    }

    // MARK: - submitMLScore

    /// Принимает результат PronunciationScorer от View (вызывается после ML inference).
    /// Хранит score — будет blend-ован с ASR в submitTranscript.
    func submitMLScore(_ request: RepeatAfterModelModels.MLEvaluate.Request) {
        pendingMLScore = request.mlScore
        logger.info("repeat mlScore=\(request.mlScore) word=\(request.wordId, privacy: .public)")
    }

    // MARK: - submitTranscript

    /// Финальная оценка: ASR + (optional) ML score.
    func submitTranscript(_ request: RepeatAfterModelModels.EvaluateAttempt.Request) {
        guard !words.isEmpty, currentIndex < words.count else { return }
        let word = words[currentIndex]

        // Защита от ре-submit при issuance <=0.
        if attemptsLeft <= 0 {
            let response = RepeatAfterModelModels.EvaluateAttempt.Response(
                score: 0,
                passed: false,
                feedback: String(localized: "repeat.feedback.forced_advance"),
                attemptsLeft: 0,
                canAdvance: true,
                diagnostic: .none,
                encouragement: nil,
                hintLevel: currentRepeatHintLevel,
                stars: 0
            )
            presenter?.presentEvaluateAttempt(response)
            return
        }

        isRecording = false

        // Вычисляем ASR-score через эвристику.
        let asrScore = RepeatScoring.score(
            transcript: request.transcript,
            target: word.word,
            confidence: request.confidence
        )

        // Финальный score: blend ML (0.6) + ASR (0.4), если ML доступен.
        let finalScore: Float
        if let mlScore = pendingMLScore {
            finalScore = mlScoreWeight * mlScore + (1 - mlScoreWeight) * asrScore
        } else {
            finalScore = asrScore
        }
        pendingMLScore = nil

        let passed = finalScore >= Self.thresholdGood

        // Обновляем историю попыток.
        var history = attemptHistoryPerWord[word.id] ?? []
        history.append(finalScore)
        attemptHistoryPerWord[word.id] = history

        // Обновляем лучший score.
        let previousBest = bestScorePerWord[word.id] ?? 0
        if finalScore > previousBest {
            bestScorePerWord[word.id] = finalScore
        }

        attemptsLeft = max(0, attemptsLeft - 1)
        let canAdvance = passed || attemptsLeft == 0

        // Диагностика ошибки произношения.
        let diagnostic = diagnosePronunciationError(
            transcript: request.transcript,
            target: word.word,
            score: finalScore
        )

        // Encouragement при прогрессе между попытками.
        let encouragement = buildEncouragement(history: history, score: finalScore)

        // Количество звёзд за этот раунд.
        let roundStars = Self.starCountForScore(finalScore)

        logger.info("repeat evaluate word=\(word.id, privacy: .public) score=\(finalScore)")
        logger.info("passed=\(passed) left=\(self.attemptsLeft) diag=\(diagnostic.rawValue, privacy: .public)")

        // Статичный feedback (покажем немедленно, затем обновим через LLM).
        let staticFeedback = buildStaticFeedback(score: finalScore, passed: passed, attemptsLeft: attemptsLeft)

        let response = RepeatAfterModelModels.EvaluateAttempt.Response(
            score: finalScore,
            passed: passed,
            feedback: staticFeedback,
            attemptsLeft: attemptsLeft,
            canAdvance: canAdvance,
            diagnostic: diagnostic,
            encouragement: encouragement,
            hintLevel: currentRepeatHintLevel,
            stars: roundStars
        )
        presenter?.presentEvaluateAttempt(response)

        // F1-016: фиксируем исход в расписании повторов ОДИН раз на слово — в
        // момент его разрешения (зачёт ИЛИ исчерпаны попытки). `correct = passed`
        // — слово, освоенное со 2-3-й попытки, не штрафуется (errorless).
        // Хот-путь kid-UX: запускаем fire-and-forget, чтобы не задерживать
        // презентацию фидбэка ребёнку.
        if canAdvance {
            recordReviewOutcome(word: word, correct: passed)
        }

        // Block H: обновляем feedback через LLM в фоне (Tier A/C, kid-safe).
        // Сохраняем Task — отменяется в cancel() и advanceWord() при переходе к следующему слову.
        if let narrationService, !canAdvance {
            llmFeedbackTask?.cancel()
            llmFeedbackTask = Task { @MainActor [weak self] in
                guard let self else { return }
                let scoreInt = Int(finalScore * 100)
                let llmFeedback = await narrationService.generateAdaptiveFeedback(
                    score: scoreInt,
                    soundId: word.soundGroup
                )
                guard !Task.isCancelled else { return }
                let updatedResponse = RepeatAfterModelModels.EvaluateAttempt.Response(
                    score: finalScore,
                    passed: passed,
                    feedback: llmFeedback,
                    attemptsLeft: self.attemptsLeft,
                    canAdvance: canAdvance,
                    diagnostic: diagnostic,
                    encouragement: encouragement,
                    hintLevel: self.currentRepeatHintLevel,
                    stars: roundStars
                )
                self.presenter?.presentEvaluateAttempt(updatedResponse)
            }
        }
    }

    // MARK: - handleNoInput

    /// Реального аудио/транскрипта нет (отказ микрофона, сбой записи или ASR).
    /// НЕ начисляем балл, НЕ трогаем историю/лучший результат, НЕ списываем попытку,
    /// НЕ сбрасываем pendingMLScore — просто мягко просим повторить.
    func handleNoInput(_ request: RepeatAfterModelModels.NoInput.Request) {
        isRecording = false
        pendingMLScore = nil
        logger.info("repeat noInput reason=\(request.reason.rawValue, privacy: .public) word=\(self.currentIndex)")
        let response = RepeatAfterModelModels.NoInput.Response(
            attemptsLeft: attemptsLeft,
            message: String(localized: "repeat.feedback.try_again")
        )
        presenter?.presentNoInput(response)
    }

    // MARK: - requestHint

    /// 3-ступенчатая система подсказок:
    ///   .none → .syllabification (слогоразделение)
    ///         → .articulationDiagram (схема положения языка)
    ///         → .sloMoReplay (медленное воспроизведение эталона)
    func requestHint(_ request: RepeatAfterModelModels.Hint.Request) {
        guard currentIndex < words.count else { return }
        let word = words[currentIndex]

        // Повышаем уровень подсказки.
        switch currentRepeatHintLevel {
        case .none:              currentRepeatHintLevel = .syllabification
        case .syllabification:   currentRepeatHintLevel = .articulationDiagram
        case .articulationDiagram: currentRepeatHintLevel = .sloMoReplay
        case .sloMoReplay:       break // максимум достигнут
        }

        logger.info("repeat hint level=\(self.currentRepeatHintLevel.rawValue, privacy: .public) word=\(word.id, privacy: .public)")

        let response = RepeatAfterModelModels.Hint.Response(
            hintLevel: currentRepeatHintLevel,
            syllabification: word.syllabification,
            articulationAsset: articulationAsset(for: word.soundGroup),
            word: word
        )
        presenter?.presentHint(response)
    }

    // MARK: - requestSloMo

    /// Переключает воспроизведение в режим 0.75× (slow-motion).
    func requestSloMo(_ request: RepeatAfterModelModels.SloMo.Request) {
        guard currentIndex < words.count else { return }
        let word = words[currentIndex]
        logger.info("repeat slo-mo requested word=\(word.id, privacy: .public) rate=\(request.playbackRate)")
        let response = RepeatAfterModelModels.SloMo.Response(
            audioFilename: word.audioFilename,
            playbackRate: request.playbackRate,
            word: word
        )
        presenter?.presentSloMo(response)
    }

    // MARK: - advanceWord

    func advanceWord() {
        llmFeedbackTask?.cancel()
        llmFeedbackTask = nil
        let nextIndex = currentIndex + 1
        if nextIndex >= words.count {
            completeSession()
        } else {
            startWord(.init(wordIndex: nextIndex))
        }
    }

    // MARK: - completeSession

    func completeSession() {
        guard !words.isEmpty else { return }
        let outOf = Float(words.count)
        let totalScore = bestScorePerWord.values.reduce(0, +) / outOf
        let normalized = max(0, min(totalScore, 1))
        let starsEarned = Self.starCountForScore(normalized)

        // Суммарная статистика для экспорта.
        let totalAttempts = attemptHistoryPerWord.values.reduce(0) { $0 + $1.count }
        let wordsWithPerfect = bestScorePerWord.values.filter { $0 >= Self.thresholdExcellent }.count

        logger.info(
            "repeat completeSession score=\(normalized) stars=\(starsEarned) totalAttempts=\(totalAttempts) perfect=\(wordsWithPerfect)"
        )

        let response = RepeatAfterModelModels.CompleteSession.Response(
            totalScore: normalized,
            starsEarned: starsEarned,
            totalAttempts: totalAttempts,
            wordsWithPerfectScore: wordsWithPerfect,
            wordsCompleted: words.count
        )
        presenter?.presentCompleteSession(response)
    }

    // MARK: - cancel

    func cancel() {
        llmFeedbackTask?.cancel()
        llmFeedbackTask = nil
        recordingTask?.cancel()
        recordingTask = nil
        isRecording = false
        pendingMLScore = nil
    }

    // MARK: - F1-016: spaced repetition

    /// Пишет исход слова в `ReviewSchedulerService`. itemId — id слова
    /// (стабилен между сессиями); sound — целевой кириллический звук группы.
    /// Fire-and-forget: оценка уже показана ребёнку, запись не на хот-пути UX.
    private func recordReviewOutcome(word: TargetWordItem, correct: Bool) {
        guard let reviewScheduler, !childId.isEmpty else { return }
        let sound = SoundFamily.cyrillicSound(forGroup: word.soundGroup)
        let cid = childId
        let itemId = word.id
        Task { await reviewScheduler.recordOutcome(childId: cid, itemId: itemId, sound: sound, correct: correct) }
    }

    // MARK: - Diagnostic

    /// Определяет тип ошибки произношения по транскрипту и цели.
    private func diagnosePronunciationError(
        transcript: String,
        target: String,
        score: Float
    ) -> PronunciationDiagnostic {
        guard score < Self.thresholdGood else { return .none }

        let normTranscript = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normTarget = target.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Пропуск: транскрипт пустой.
        if normTranscript.isEmpty { return .omission }

        // Полная замена: совпадение < 30% от длины.
        let targetChars = Set(normTarget)
        let transcriptChars = Set(normTranscript)
        let intersection = targetChars.intersection(transcriptChars).count
        let unionCount = targetChars.union(transcriptChars).count
        let jaccardSimilarity = unionCount > 0 ? Float(intersection) / Float(unionCount) : 0

        if jaccardSimilarity < 0.3 { return .substitution }

        // Добавление: транскрипт значительно длиннее цели.
        let lengthRatio = Float(normTranscript.count) / Float(max(normTarget.count, 1))
        if lengthRatio > 1.6 { return .addition }

        // Искажение: первая буква совпала, но score низкий.
        if normTranscript.hasPrefix(normTarget.prefix(1)) { return .distortion }

        return .substitution
    }

    // MARK: - Encouragement

    /// Сообщение при прогрессе между попытками.
    private func buildEncouragement(history: [Float], score: Float) -> String? {
        guard history.count >= 2 else { return nil }
        let previousScore = history[history.count - 2]
        let improvement = score - previousScore
        if improvement > 0.1 {
            return String(localized: "repeat.encouragement.better")
        } else if improvement > 0.05 {
            return String(localized: "repeat.encouragement.slight_better")
        }
        return nil
    }

    // MARK: - Static feedback

    private func buildStaticFeedback(score: Float, passed: Bool, attemptsLeft: Int) -> String {
        if passed {
            if score >= Self.thresholdExcellent {
                return String(localized: "repeat.feedback.excellent")
            }
            return String(localized: "repeat.feedback.great")
        }
        if attemptsLeft == 0 {
            return String(localized: "repeat.feedback.forced_advance")
        }
        if score >= Self.thresholdTrying {
            return String(localized: "repeat.feedback.almost")
        }
        return String(localized: "repeat.feedback.try_again")
    }

    // MARK: - Articulation asset lookup

    /// Возвращает имя иллюстрации из Assets для группы звуков.
    private func articulationAsset(for soundGroup: String) -> String {
        switch soundGroup {
        case SoundFamily.whistling.rawValue:  return "articulation_whistling"
        case SoundFamily.hissing.rawValue:    return "articulation_hissing"
        case SoundFamily.sonorant.rawValue:   return "articulation_sonorant"
        default:                              return "articulation_velar"
        }
    }

    // MARK: - Star count

    private static func starCountForScore(_ score: Float) -> Int {
        switch score {
        case thresholdExcellent...:          return 3
        case thresholdGood..<thresholdExcellent: return 2
        case thresholdTrying..<thresholdGood:    return 1
        default:                             return 0
        }
    }
}

// MARK: - RepeatHintLevel

enum RepeatHintLevel: String, Sendable, Equatable {
    /// Подсказки нет.
    case none
    /// Слогоразделение: «Ма-ши-на».
    case syllabification
    /// Диаграмма артикуляции (иллюстрация).
    case articulationDiagram
    /// Медленное воспроизведение эталона (0.75×).
    case sloMoReplay
}

// MARK: - PronunciationDiagnostic

enum PronunciationDiagnostic: String, Sendable, Equatable {
    /// Нет ошибки (произношение зачтено).
    case none
    /// Искажение: звук присутствует, но нечёткий.
    case distortion
    /// Замена целевого звука другим.
    case substitution
    /// Пропуск: целевой звук отсутствует.
    case omission
    /// Добавление: лишний звук или слог.
    case addition
}
