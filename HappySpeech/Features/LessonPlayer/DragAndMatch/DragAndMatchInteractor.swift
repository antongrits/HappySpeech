import Foundation
import OSLog

// MARK: - DragAndMatchBusinessLogic

@MainActor
protocol DragAndMatchBusinessLogic: AnyObject {
    func loadSession(_ request: DragAndMatchModels.LoadSession.Request) async
    func dropWord(_ request: DragAndMatchModels.DropWord.Request) async
    func requestHint(_ request: DragAndMatchModels.RequestHint.Request) async
    func advanceRound(_ request: DragAndMatchModels.CompleteRound.Request) async
    func completeSession(_ request: DragAndMatchModels.CompleteSession.Request) async
    func cancelSession()
}

// MARK: - DragAndMatchInteractor
//
// Бизнес-логика игры «Перетащи и совмести».
//
// Жизненный цикл:
//   loadSession(soundGroup, childName, totalRounds)
//     → разбивает полный набор слов на раунды по roundSize карточек
//     → infers ConfusedPair по soundGroup (для отображения в шапке)
//     → presentLoadSession (первый раунд)
//
//   dropWord(wordId, bucketId)
//     → проверяет correctBucketId == bucketId
//     → обновляет scoring (streak, per-round счётчики)
//     → haptic: cardSelect — успех, wrong — ошибка
//     → sound: correct / incorrect
//     → presentDropWord (feedbackText, streakBonus)
//     → если все карточки раунда размещены → автозавершение раунда через 800 мс
//
//   requestHint(wordId)
//     → 3 уровня: highlightBin → voicePrompt → autoSolve
//     → autoSolve: карточка считается правильно размещённой, но баллы не начисляются
//     → presentHint
//
//   advanceRound()
//     → фиксирует RoundStats текущего раунда
//     → presentCompleteRound
//     → если раунды закончились → completeSession
//     → иначе → loadSession следующего раунда
//
//   completeSession()
//     → агрегирует allRoundStats, считает итоговый score
//     → presentCompleteSession

@MainActor
final class DragAndMatchInteractor: DragAndMatchBusinessLogic {

    // MARK: - Dependencies

    var presenter: (any DragAndMatchPresentationLogic)?
    private let hapticService: any HapticService
    private let logger = Logger(subsystem: "ru.happyspeech", category: "DragAndMatch")

    // MARK: - Configuration

    /// Количество карточек в одном раунде (5–6 для детей 5–8 лет).
    private static let roundSize: Int = 6
    /// Максимальное число подсказок на один раунд.
    private static let maxHintsPerRound: Int = 3
    /// Задержка перед автопереходом к следующему раунду (мс).
    private static let roundAdvanceDelay: Duration = .milliseconds(800)
    /// Количество правильных подряд для стрик-бонуса.
    private static let streakThreshold: Int = 3

    // MARK: - Session state

    private var soundGroup: String = ""
    private var childName: String = ""
    private var totalRounds: Int = 3
    private var confusedPair: ConfusedPair?
    private var isSessionOver: Bool = false

    // MARK: - Full word pool (разбитый на раунды)

    /// Все слова сессии, разбитые на раунды по roundSize.
    private var roundWordBatches: [[DragWord]] = []
    private var buckets: [DragBucket] = []

    // MARK: - Current round state

    private var currentRoundIndex: Int = 0
    /// Слова текущего раунда.
    private var currentWords: [DragWord] = []
    /// wordId → bucketId (куда дроп произошёл).
    private var currentPlaced: [String: String] = [:]
    /// Количество правильных дропов в текущем раунде.
    private var currentCorrect: Int = 0
    /// Количество неправильных дропов в текущем раунде.
    private var currentIncorrect: Int = 0
    /// Подсказки использованные в текущем раунде: wordId → уровень.
    private var currentHints: [String: HintLevel] = [:]
    /// Время начала текущего раунда.
    private var roundStartTime: Date = Date()

    // MARK: - Streak state

    /// Серия правильных ответов подряд (включая все раунды сессии).
    private var streakCount: Int = 0

    // MARK: - Session-level stats

    private var allRoundStats: [RoundStats] = []
    private var sessionStartTime: Date = Date()

    // MARK: - Tasks

    private var roundAdvanceTask: Task<Void, Never>?

    // MARK: - Init

    init(hapticService: any HapticService) {
        self.hapticService = hapticService
    }

    deinit {
        roundAdvanceTask?.cancel()
    }

    // MARK: - loadSession

    func loadSession(_ request: DragAndMatchModels.LoadSession.Request) async {
        guard !isSessionOver else { return }

        // Первый вход: инициализируем сессию и разбиваем слова на раунды.
        if roundWordBatches.isEmpty {
            sessionStartTime = Date()
            soundGroup = request.soundGroup
            childName = request.childName
            totalRounds = max(1, request.totalRounds)
            confusedPair = Self.inferConfusedPair(for: soundGroup)

            let (allWords, bucketList) = DragWord.set(for: soundGroup)
            buckets = bucketList
            roundWordBatches = Self.split(words: allWords.shuffled(), rounds: totalRounds)
            let logMsg = "loadSession group=\(self.soundGroup) rounds=\(self.totalRounds) words=\(allWords.count)"
            logger.info("\(logMsg, privacy: .public)")
        }

        // Загружаем текущий раунд.
        let safeIndex = min(currentRoundIndex, roundWordBatches.count - 1)
        currentWords = roundWordBatches[safeIndex].shuffled()
        currentPlaced = [:]
        currentCorrect = 0
        currentIncorrect = 0
        currentHints = [:]
        roundStartTime = Date()

        logger.info(
            "Round \(self.currentRoundIndex + 1, privacy: .public)/\(self.totalRounds, privacy: .public) words=\(self.currentWords.count, privacy: .public)"
        )

        let response = DragAndMatchModels.LoadSession.Response(
            words: currentWords,
            buckets: buckets,
            childName: childName,
            roundIndex: currentRoundIndex,
            totalRounds: totalRounds,
            confusedPair: confusedPair
        )
        presenter?.presentLoadSession(response)
    }

    // MARK: - dropWord

    func dropWord(_ request: DragAndMatchModels.DropWord.Request) async {
        guard !isSessionOver else { return }
        guard let word = currentWords.first(where: { $0.id == request.wordId }) else {
            logger.error("dropWord: unknown wordId=\(request.wordId, privacy: .public)")
            return
        }

        // Если слово уже было авто-решено подсказкой — игнорируем повторный дроп.
        if let hintLevel = currentHints[request.wordId], hintLevel == .autoSolve {
            logger.info("dropWord: skipped, word=\(word.word, privacy: .public) was auto-solved")
            return
        }

        let isRedrop = currentPlaced[request.wordId] != nil
        currentPlaced[request.wordId] = request.bucketId

        let correct = (word.correctBucketId == request.bucketId)

        // Обновляем счётчики только при первом дропе каждой карточки.
        if !isRedrop {
            if correct {
                currentCorrect += 1
            } else {
                currentIncorrect += 1
            }
        } else if correct {
            // Редроп в правильную корзину после ошибки — засчитываем успех,
            // ошибку уже учли при первом дропе.
            currentCorrect += 1
            currentIncorrect = max(0, currentIncorrect - 1)
        }

        // Streak: сбрасываем при ошибке, накапливаем при успехе.
        if correct {
            streakCount += 1
        } else {
            streakCount = 0
        }
        let isStreakBonus = correct && (streakCount % Self.streakThreshold == 0) && streakCount > 0

        // Тактильный и звуковой фидбек.
        if correct {
            hapticService.selection()
            if isStreakBonus {
                await hapticService.play(pattern: .celebration)
            }
        } else {
            hapticService.notification(.warning)
        }

        let dropMsg = "Drop word=\(word.word) bucket=\(request.bucketId) correct=\(correct) streak=\(self.streakCount)"
        logger.info("\(dropMsg, privacy: .public)")

        let response = DragAndMatchModels.DropWord.Response(
            correct: correct,
            wordId: request.wordId,
            feedbackText: correct ? "Верно!" : "Попробуй другую корзину.",
            streakCount: streakCount,
            isStreakBonus: isStreakBonus,
            hintBucketId: nil
        )
        presenter?.presentDropWord(response)

        // Авто-завершение раунда когда все карточки размещены в правильные корзины.
        let allPlacedCorrectly = currentWords.allSatisfy { word in
            currentPlaced[word.id] == word.correctBucketId
        }
        if allPlacedCorrectly {
            scheduleRoundAdvance()
        }
    }

    // MARK: - requestHint

    func requestHint(_ request: DragAndMatchModels.RequestHint.Request) async {
        guard !isSessionOver else { return }
        guard let word = currentWords.first(where: { $0.id == request.wordId }) else {
            logger.error("requestHint: unknown wordId=\(request.wordId, privacy: .public)")
            return
        }

        let totalHintsUsed = currentHints.count
        guard totalHintsUsed < Self.maxHintsPerRound else {
            logger.info("requestHint: max hints reached for round \(self.currentRoundIndex, privacy: .public)")
            return
        }

        // Определяем следующий уровень подсказки для данного слова.
        let nextLevel: HintLevel
        if let prev = currentHints[request.wordId] {
            nextLevel = HintLevel(rawValue: prev.rawValue + 1) ?? .autoSolve
        } else {
            nextLevel = .highlightBin
        }
        currentHints[request.wordId] = nextLevel

        let hintsRemaining = Self.maxHintsPerRound - currentHints.count
        let targetBucket = buckets.first { $0.id == word.correctBucketId }

        var voiceText: String?
        var autoSolvedWordId: String?
        var autoSolvedBucketId: String?

        switch nextLevel {
        case .highlightBin:
            // Визуальная подсветка целевой корзины — только через View.
            hapticService.impact(.light)
            logger.info("Hint L1 highlightBin word=\(word.word, privacy: .public) bucket=\(targetBucket?.id ?? "", privacy: .public)")

        case .voicePrompt:
            // Формируем текст для озвучки через LessonVoiceWorker.
            let bucketTitle = targetBucket?.title ?? word.correctBucketId
            voiceText = String(
                localized: "Слово «\(word.word)» идёт в корзину «\(bucketTitle)»"
            )
            hapticService.impact(.light)
            logger.info("Hint L2 voicePrompt word=\(word.word, privacy: .public)")
            // Озвучка запускается в View через displayHint.

        case .autoSolve:
            // Авто-дроп: слово считается размещённым правильно, но без начисления очков.
            currentPlaced[request.wordId] = word.correctBucketId
            autoSolvedWordId = request.wordId
            autoSolvedBucketId = word.correctBucketId
            hapticService.notification(.success)
            logger.info("Hint L3 autoSolve word=\(word.word, privacy: .public) → bucket=\(word.correctBucketId, privacy: .public)")

            // Проверяем, завершился ли раунд после авто-решения.
            let allPlacedCorrectly = currentWords.allSatisfy { w in
                currentPlaced[w.id] == w.correctBucketId
            }
            if allPlacedCorrectly {
                scheduleRoundAdvance()
            }
        }

        let response = DragAndMatchModels.RequestHint.Response(
            level: nextLevel,
            targetBucketId: targetBucket?.id,
            voicePromptText: voiceText,
            autoSolvedWordId: autoSolvedWordId,
            autoSolvedBucketId: autoSolvedBucketId,
            hintsRemaining: hintsRemaining
        )
        presenter?.presentHint(response)
    }

    // MARK: - advanceRound

    func advanceRound(_ request: DragAndMatchModels.CompleteRound.Request) async {
        guard !isSessionOver else { return }
        roundAdvanceTask?.cancel()

        let duration = Date().timeIntervalSince(roundStartTime)
        let stats = RoundStats(
            roundIndex: currentRoundIndex,
            totalCards: currentWords.count,
            correctDrops: currentCorrect,
            incorrectDrops: currentIncorrect,
            hintsUsed: currentHints.count,
            durationSeconds: duration
        )
        allRoundStats.append(stats)

        let nextIndex = currentRoundIndex + 1
        let hasNext = nextIndex < totalRounds

        let roundAccuracy = Int(stats.accuracy * 100)
        let roundMsg = "Round \(self.currentRoundIndex + 1) done accuracy=\(roundAccuracy)% hints=\(stats.hintsUsed)"
        logger.info("\(roundMsg, privacy: .public)")

        let response = DragAndMatchModels.CompleteRound.Response(
            stats: stats,
            hasNextRound: hasNext,
            nextRoundIndex: nextIndex
        )
        presenter?.presentCompleteRound(response)

        if hasNext {
            currentRoundIndex = nextIndex
        } else {
            await completeSession(DragAndMatchModels.CompleteSession.Request())
        }
    }

    // MARK: - completeSession

    func completeSession(_ request: DragAndMatchModels.CompleteSession.Request) async {
        guard !isSessionOver else { return }
        isSessionOver = true
        roundAdvanceTask?.cancel()

        // Если последний раунд ещё не зафиксирован в allRoundStats — добавляем.
        if allRoundStats.count <= currentRoundIndex {
            let duration = Date().timeIntervalSince(roundStartTime)
            let stats = RoundStats(
                roundIndex: currentRoundIndex,
                totalCards: currentWords.count,
                correctDrops: currentCorrect,
                incorrectDrops: currentIncorrect,
                hintsUsed: currentHints.count,
                durationSeconds: duration
            )
            allRoundStats.append(stats)
        }

        let totalCorrect = allRoundStats.reduce(0) { $0 + $1.correctDrops }
        let totalWords = roundWordBatches.reduce(0) { $0 + $1.count }
        let totalHints = allRoundStats.reduce(0) { $0 + $1.hintsUsed }
        let totalDuration = Date().timeIntervalSince(sessionStartTime)

        let dur = Int(totalDuration)
        let sessionMsg = "Session complete \(totalCorrect)/\(totalWords) hints=\(totalHints) dur=\(dur)s"
        logger.info("\(sessionMsg, privacy: .public)")

        // Тактильный фидбек по итоговому результату.
        let ratio = totalWords > 0 ? Double(totalCorrect) / Double(totalWords) : 0
        if ratio >= 0.9 {
            await hapticService.play(pattern: .celebration)
        } else if ratio >= 0.7 {
            await hapticService.play(pattern: .rewardCollected)
        } else {
            hapticService.impact(.soft)
        }

        let response = DragAndMatchModels.CompleteSession.Response(
            correctCount: totalCorrect,
            totalWords: totalWords,
            allRoundStats: allRoundStats,
            totalHintsUsed: totalHints,
            totalDurationSeconds: totalDuration
        )
        presenter?.presentCompleteSession(response)
    }

    // MARK: - cancelSession

    func cancelSession() {
        isSessionOver = true
        roundAdvanceTask?.cancel()
        logger.info("DragAndMatch session cancelled at round=\(self.currentRoundIndex, privacy: .public)")
    }

    // MARK: - Private: auto-advance

    private func scheduleRoundAdvance() {
        roundAdvanceTask?.cancel()
        roundAdvanceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.roundAdvanceDelay)
            guard let self, !Task.isCancelled, !self.isSessionOver else { return }
            await self.advanceRound(DragAndMatchModels.CompleteRound.Request())
        }
    }

    // MARK: - Static: round splitting

    /// Разбивает массив слов на `rounds` батчей.
    /// Если слов меньше чем rounds × roundSize — батчи перекрываются (rotate).
    private static func split(words: [DragWord], rounds: Int) -> [[DragWord]] {
        guard !words.isEmpty, rounds > 0 else { return [words] }
        var batches: [[DragWord]] = []
        let size = roundSize
        var pool = words

        for _ in 0..<rounds {
            if pool.count >= size {
                batches.append(Array(pool.prefix(size)))
                pool = Array(pool.dropFirst(size))
            } else {
                // Пул исчерпан — заново перетасовываем все слова.
                pool = words.shuffled()
                batches.append(Array(pool.prefix(size)))
                pool = Array(pool.dropFirst(size))
            }
        }
        return batches
    }

    // MARK: - Static: ConfusedPair inference

    /// Определяет пару звуков для дифференциации по ключу soundGroup.
    static func inferConfusedPair(for soundGroup: String) -> ConfusedPair? {
        switch soundGroup.lowercased() {
        case "с/ш", "с-ш":     return ConfusedPair(primary: "С", secondary: "Ш")
        case "з/ж", "з-ж":     return ConfusedPair(primary: "З", secondary: "Ж")
        case "р/л", "р-л":     return ConfusedPair(primary: "Р", secondary: "Л")
        case "б/п", "б-п":     return ConfusedPair(primary: "Б", secondary: "П")
        case "д/т", "д-т":     return ConfusedPair(primary: "Д", secondary: "Т")
        case "г/к", "г-к":     return ConfusedPair(primary: "Г", secondary: "К")
        case "в/ф", "в-ф":     return ConfusedPair(primary: "В", secondary: "Ф")
        case "ж/ш", "ж-ш":     return ConfusedPair(primary: "Ж", secondary: "Ш")
        case "ч/щ", "ч-щ":     return ConfusedPair(primary: "Ч", secondary: "Щ")
        case "whistling", "с", "з", "ц":
            return ConfusedPair(primary: "С", secondary: "З")
        case "hissing", "ш", "ж", "ч", "щ":
            return ConfusedPair(primary: "Ш", secondary: "Ж")
        case "sonorant", "р", "л":
            return ConfusedPair(primary: "Р", secondary: "Л")
        case "velar", "к", "г", "х":
            return ConfusedPair(primary: "К", secondary: "Г")
        default:
            return nil
        }
    }

    // MARK: - Computed: per-pair accuracy

    /// Возвращает процент правильных дропов для каждой пары звуков из текущей сессии.
    /// Используется в итоговом экране или для передачи в SpacedRepetitionEngine.
    func perPairAccuracy() -> [String: Double] {
        guard !roundWordBatches.isEmpty else { return [:] }
        let allWords = roundWordBatches.flatMap { $0 }
        var groupCounts: [String: (correct: Int, total: Int)] = [:]

        for word in allWords {
            var entry = groupCounts[word.soundGroup] ?? (0, 0)
            entry.total += 1
            if currentPlaced[word.id] == word.correctBucketId {
                entry.correct += 1
            }
            groupCounts[word.soundGroup] = entry
        }
        return groupCounts.mapValues { counts in
            counts.total > 0 ? Double(counts.correct) / Double(counts.total) : 0
        }
    }

    // MARK: - Computed: SM2 quality for current session

    /// Преобразует итоговую точность сессии в качество SM-2 для spaced repetition.
    func sm2Quality() -> SM2Quality {
        let total = roundWordBatches.reduce(0) { $0 + $1.count }
        guard total > 0 else { return .blackout }
        let correct = allRoundStats.reduce(0) { $0 + $1.correctDrops }
        let rate = Double(correct) / Double(total)
        let hints = allRoundStats.reduce(0) { $0 + $1.hintsUsed }
        let hadFatigue = hints > Self.maxHintsPerRound
        return SM2Quality.fromSuccessRate(rate, hadFatigue: hadFatigue)
    }
}
