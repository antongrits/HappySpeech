import Foundation
import OSLog

// MARK: - SortingBusinessLogic

@MainActor
protocol SortingBusinessLogic: AnyObject {
    func loadSession(_ request: SortingModels.LoadSession.Request) async
    func classifyWord(_ request: SortingModels.ClassifyWord.Request) async
    func requestHint(_ request: SortingModels.RequestHint.Request) async
    func autoDistribute() async
    func completeSession(_ request: SortingModels.CompleteSession.Request) async
    func cancel()
}

// MARK: - SortingInteractor
//
// Игра «Сортировка по категориям». Ребёнок видит слово по центру и 2–4 кнопки
// с категориями под ним. Tap по кнопке классифицирует слово, даётся haptic
// + короткая подсветка, индекс сдвигается на следующее слово. После всех
// слов (или по таймеру) — авто-completeSession.
//
// Ключевая логика:
//   • 5 типов задач: по первому звуку / по позиции / по слогам /
//     гласные-согласные / звонкие-глухие. Каждый набор SortingSet хранит
//     `taskType` для аналитики и подсказок.
//   • Streak: 3+ правильных ответа подряд — hapticService.notification(.success)
//     и streakBadgeVisible=true. Голосовая похвала через presentStreakBonus.
//   • Hints (3 уровня):
//       1 — подсветить правильную корзину (highlight)
//       2 — голосовая подсказка «Это слово на звук Ш»
//       3 — авто-placement без баллов
//   • Auto-distribute: если ребёнок не отвечает 30 с — размещаем все
//     оставшиеся слова автоматически (без баллов) и завершаем.
//   • Per-task accuracy: каждый набор → свой TaskStats (correct/total/time).
//   • Adaptive difficulty: если hitRate < 0.6 — следующий задание берётся из
//     problematic-groups (через AdaptivePlannerService, fallback — тот же набор).
//   • Double-tap защита: повторная классификация одного слова игнорируется.
//   • Скор = hitRate*0.70 + timeBonus*0.15 + streakBonus*(до 0.15), clamp 0…1.
//
// Жизненный цикл:
//   loadSession → presentLoadSession + startIdleTimer + startTimer
//   classifyWord → проверка / streak++ / haptic / presentClassifyWord
//                → resetIdleTimer
//                → если classifiedWords.count == words.count → completeSession(.allClassified)
//   requestHint  → уровень 1/2/3 → presentHint
//   autoDistribute → расставить оставшиеся правильно (без баллов)
//   timer expired → completeSession(.timeExpired)
//   idle (30s)   → autoDistribute → completeSession(.autoDistributed)
//   cancel()     — снять таймеры при onDisappear.

@MainActor
final class SortingInteractor: SortingBusinessLogic {

    // MARK: - Dependencies

    var presenter: (any SortingPresentationLogic)?
    private let hapticService: any HapticService
    private let logger = Logger(subsystem: "ru.happyspeech", category: "Sorting")

    // MARK: - Configuration

    /// Мягкий лимит времени на весь набор (сек).
    private static let timeLimit: Int = 90
    /// Порог серии для бонуса и дополнительного «вау»-фидбека.
    private static let streakBonusThreshold: Int = 3
    /// Максимум подсказок на одно слово (3 уровня).
    private static let maxHintsPerWord: Int = 3
    /// Тайм-аут бездействия (сек) — автораспределение.
    private static let idleTimeout: Int = 30

    // MARK: - Session state

    private var currentSet: SortingSet?
    private var words: [SortingWord] = []
    private var categories: [SortingCategory] = []

    /// wordId → categoryId, куда ребёнок положил слово.
    private var classifiedWords: [String: String] = [:]
    /// wordId → true/false (правильно ли).
    private var correctnessMap: [String: Bool] = [:]
    /// wordId → hintLevel (1, 2, или 3 — автоплейс).
    private var hintLevels: [String: Int] = [:]
    /// wordId-ы, которые были авторасставлены (без баллов).
    private var autoPlaced: Set<String> = []

    // MARK: - Streak state

    private var currentStreak: Int = 0
    private var bestStreak: Int = 0

    // MARK: - Per-task statistics

    /// Для финального summary: categoryId → (correct, total).
    private var categoryStats: [String: (correct: Int, total: Int)] = [:]

    // MARK: - Timing

    private var elapsed: Int = 0
    private var idleElapsed: Int = 0
    private var timerTask: Task<Void, Never>?
    private var idleTimerTask: Task<Void, Never>?
    private var isGameOver: Bool = false

    // MARK: - Init

    init(hapticService: any HapticService) {
        self.hapticService = hapticService
    }

    deinit {
        timerTask?.cancel()
        idleTimerTask?.cancel()
    }

    // MARK: - loadSession

    func loadSession(_ request: SortingModels.LoadSession.Request) async {
        let set = SortingSet.set(for: request.soundGroup)
        self.currentSet = set
        self.words = set.words.shuffled()
        self.categories = set.categories
        self.classifiedWords = [:]
        self.correctnessMap = [:]
        self.hintLevels = [:]
        self.autoPlaced = []
        self.currentStreak = 0
        self.bestStreak = 0
        self.elapsed = 0
        self.idleElapsed = 0
        self.isGameOver = false

        // Инициализируем categoryStats для каждой категории.
        for category in categories {
            categoryStats[category.id] = (correct: 0, total: 0)
        }

        let sortInfo = "words=\(self.words.count) categories=\(self.categories.count) group=\(request.soundGroup) taskType=\(set.taskType)"
        logger.info("Sorting loaded set=\(set.id, privacy: .public) \(sortInfo, privacy: .public)")

        let response = SortingModels.LoadSession.Response(
            setTitle: set.title,
            taskType: set.taskType,
            taskDescription: set.taskDescription,
            words: self.words,
            categories: self.categories,
            childName: request.childName,
            timeLimit: Self.timeLimit
        )
        presenter?.presentLoadSession(response)

        // Немедленный tick — чтобы таймер-лейбл сразу отрисовался.
        presenter?.presentTimerTick(SortingModels.TimerTick.Response(
            remaining: Self.timeLimit,
            expired: false
        ))

        startTimer()
        startIdleTimer()
    }

    // MARK: - classifyWord

    func classifyWord(_ request: SortingModels.ClassifyWord.Request) async {
        guard !isGameOver else { return }
        guard let word = words.first(where: { $0.id == request.wordId }) else {
            logger.error("classifyWord: unknown wordId \(request.wordId, privacy: .public)")
            return
        }

        // Повторная классификация одного слова игнорируется — double-tap защита.
        guard classifiedWords[request.wordId] == nil else {
            logger.debug("classifyWord: wordId=\(request.wordId, privacy: .public) already classified, ignore")
            return
        }

        classifiedWords[request.wordId] = request.categoryId
        let correct = word.isCorrect(targetCategory: request.categoryId)
        correctnessMap[request.wordId] = correct

        // Обновляем per-category stats.
        updateCategoryStats(word: word, correct: correct)

        // Streak.
        if correct {
            currentStreak += 1
            bestStreak = max(bestStreak, currentStreak)
        } else {
            currentStreak = 0
        }
        let streakTriggered = correct && currentStreak >= Self.streakBonusThreshold

        // Haptic.
        if correct {
            if streakTriggered {
                hapticService.notification(.success)
            } else {
                hapticService.selection()
            }
        } else {
            hapticService.notification(.warning)
        }

        let classInfo = "correct=\(correct) streak=\(self.currentStreak) best=\(self.bestStreak)"
        logger.info(
            "classify word=\(word.word, privacy: .public) → \(request.categoryId, privacy: .public) \(classInfo, privacy: .public)"
        )

        // Сбросить idle-таймер при активности.
        resetIdleTimer()

        // Формируем feedback с учётом streak и категории.
        let feedbackText = buildFeedback(correct: correct, streakTriggered: streakTriggered, word: word)

        let response = SortingModels.ClassifyWord.Response(
            correct: correct,
            wordId: request.wordId,
            categoryId: request.categoryId,
            streak: currentStreak,
            streakBonusTriggered: streakTriggered,
            feedback: feedbackText,
            remainingCount: words.count - classifiedWords.count
        )
        presenter?.presentClassifyWord(response)

        // Если streak — дополнительно голосовой бонус.
        if streakTriggered {
            presenter?.presentStreakBonus(SortingModels.StreakBonus.Response(
                streak: currentStreak
            ))
        }

        if classifiedWords.count >= words.count {
            await completeSession(reason: .allClassified)
        }
    }

    // MARK: - requestHint

    func requestHint(_ request: SortingModels.RequestHint.Request) async {
        guard !isGameOver else { return }
        guard let word = words.first(where: { $0.id == request.wordId }) else {
            logger.error("requestHint: unknown wordId \(request.wordId, privacy: .public)")
            return
        }
        guard classifiedWords[request.wordId] == nil else {
            logger.debug("requestHint: word already classified, skip")
            return
        }

        let currentLevel = hintLevels[request.wordId] ?? 0
        let nextLevel = min(currentLevel + 1, Self.maxHintsPerWord)
        hintLevels[request.wordId] = nextLevel

        hapticService.impact(.light)
        logger.info("hint level=\(nextLevel, privacy: .public) for word=\(word.word, privacy: .public)")

        let hintText = buildHintText(level: nextLevel, word: word)
        let response = SortingModels.RequestHint.Response(
            wordId: request.wordId,
            hintLevel: nextLevel,
            highlightCategoryId: word.correctCategory,
            hintText: hintText,
            isAutoPlace: nextLevel >= Self.maxHintsPerWord
        )
        presenter?.presentHint(response)

        // Уровень 3 — авторасстановка без баллов.
        if nextLevel >= Self.maxHintsPerWord {
            await autoPlaceWord(word)
            // Если авторасставлено последнее слово — завершаем сессию,
            // иначе игра зависнет без экрана итогов.
            if classifiedWords.count >= words.count {
                await completeSession(reason: .allClassified)
            }
        }
    }

    // MARK: - autoDistribute

    /// Автоматически расставляет все оставшиеся слова (без баллов) — срабатывает
    /// по 30-секундному таймеру бездействия.
    func autoDistribute() async {
        guard !isGameOver else { return }
        let remaining = words.filter { classifiedWords[$0.id] == nil }
        guard !remaining.isEmpty else { return }

        logger.warning("autoDistribute: placing \(remaining.count, privacy: .public) remaining words")

        for word in remaining {
            await autoPlaceWord(word)
            try? await Task.sleep(for: .milliseconds(120))
        }
        await completeSession(reason: .autoDistributed)
    }

    // MARK: - completeSession (public protocol)

    func completeSession(_ request: SortingModels.CompleteSession.Request) async {
        await completeSession(reason: .allClassified)
    }

    // MARK: - cancel

    func cancel() {
        isGameOver = true
        timerTask?.cancel()
        timerTask = nil
        idleTimerTask?.cancel()
        idleTimerTask = nil
        logger.info("Sorting cancelled")
    }

    // MARK: - Private: auto-place single word

    private func autoPlaceWord(_ word: SortingWord) async {
        guard classifiedWords[word.id] == nil else { return }
        classifiedWords[word.id] = word.correctCategory
        correctnessMap[word.id] = true // технически правильно
        autoPlaced.insert(word.id)

        // Per-category stats: не начисляем в correct, только total.
        if var stats = categoryStats[word.correctCategory] {
            stats.total += 1
            categoryStats[word.correctCategory] = stats
        }

        logger.debug("autoPlace word=\(word.word, privacy: .public) → \(word.correctCategory, privacy: .public)")
        presenter?.presentAutoPlace(SortingModels.AutoPlace.Response(wordId: word.id, categoryId: word.correctCategory))
    }

    // MARK: - Private: timer

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                guard !self.isGameOver else { return }
                self.elapsed += 1
                let remaining = max(0, Self.timeLimit - self.elapsed)
                let expired = (remaining == 0)
                self.presenter?.presentTimerTick(SortingModels.TimerTick.Response(
                    remaining: remaining,
                    expired: expired
                ))
                if expired {
                    await self.handleTimeout()
                    return
                }
            }
        }
    }

    private func startIdleTimer() {
        idleTimerTask?.cancel()
        idleElapsed = 0
        idleTimerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                guard !self.isGameOver else { return }
                self.idleElapsed += 1
                if self.idleElapsed >= Self.idleTimeout {
                    logger.warning("Sorting idle timeout triggered")
                    await self.autoDistribute()
                    return
                }
            }
        }
    }

    private func resetIdleTimer() {
        idleElapsed = 0
    }

    private func handleTimeout() async {
        guard !isGameOver else { return }
        let classified = classifiedWords.count
        let total = words.count
        logger.warning("Sorting timeout: expired at \(classified, privacy: .public)/\(total, privacy: .public) classified")
        await completeSession(reason: .timeExpired)
    }

    // MARK: - Private: completeSession core

    private func completeSession(reason: SortingModels.CompleteSession.Reason) async {
        guard !isGameOver else { return }
        isGameOver = true
        timerTask?.cancel()
        timerTask = nil
        idleTimerTask?.cancel()
        idleTimerTask = nil

        // Считаем только те слова, которые ребёнок разместил сам (не авто).
        let humanClassified = classifiedWords.filter { !autoPlaced.contains($0.key) }
        var correctHuman = 0
        for word in words where humanClassified[word.id] == word.correctCategory {
            correctHuman += 1
        }
        let humanTotal = humanClassified.count
        let overallCorrect = words.filter { correctnessMap[$0.id] == true && !autoPlaced.contains($0.id) }.count
        let overallTotal = max(words.count, 1)

        // Per-category summary.
        let categoryBreakdown = buildCategoryBreakdown()

        // Лучшая и худшая категория.
        let bestCategory = categoryBreakdown.max(by: { $0.accuracy < $1.accuracy })
        let worstCategory = categoryBreakdown.min(by: { $0.accuracy < $1.accuracy })

        let score = computeScore(
            correct: overallCorrect,
            total: overallTotal,
            elapsed: elapsed,
            bestStreak: bestStreak,
            autoPlacedCount: autoPlaced.count
        )

        let completeInfo = "correct=\(overallCorrect)/\(overallTotal) human=\(correctHuman)/\(humanTotal) elapsed=\(self.elapsed)s best=\(self.bestStreak)"
        let completeInfo2 = "reason=\(String(describing: reason)) score=\(score)"
        logger.info("Sorting complete \(completeInfo, privacy: .public) \(completeInfo2, privacy: .public)")

        let response = SortingModels.CompleteSession.Response(
            correctCount: overallCorrect,
            total: overallTotal,
            humanCorrect: correctHuman,
            humanTotal: humanTotal,
            elapsedSeconds: elapsed,
            timeLimit: Self.timeLimit,
            bestStreak: bestStreak,
            autoPlacedCount: autoPlaced.count,
            reason: reason,
            finalScore: score,
            categoryBreakdown: categoryBreakdown,
            bestCategoryTitle: bestCategory?.title,
            worstCategoryTitle: worstCategory?.title
        )
        presenter?.presentCompleteSession(response)
    }

    // MARK: - Private: helpers

    private func updateCategoryStats(word: SortingWord, correct: Bool) {
        // Запись в правильную корзину (та, куда должно было попасть слово).
        if var stats = categoryStats[word.correctCategory] {
            stats.total += 1
            if correct { stats.correct += 1 }
            categoryStats[word.correctCategory] = stats
        }
    }

    private func buildCategoryBreakdown() -> [SortingModels.CategoryStat] {
        categories.map { category in
            let stats = categoryStats[category.id] ?? (correct: 0, total: 0)
            let accuracy: Float = stats.total > 0
                ? Float(stats.correct) / Float(stats.total)
                : 0
            return SortingModels.CategoryStat(
                categoryId: category.id,
                title: category.title,
                correct: stats.correct,
                total: stats.total,
                accuracy: accuracy
            )
        }
    }

    private func buildFeedback(correct: Bool, streakTriggered: Bool, word: SortingWord) -> String {
        if correct {
            if streakTriggered {
                return String(localized: "Вот это серия! Отлично!")
            }
            // Чередуем похвалы для разнообразия.
            let phrases = [
                String(localized: "Верно!"),
                String(localized: "Молодец!"),
                String(localized: "Правильно!"),
                String(localized: "Отлично!")
            ]
            return phrases[abs(word.id.hashValue) % phrases.count]
        } else {
            let tryPhrases = [
                String(localized: "Не совсем. Идём дальше."),
                String(localized: "Попробуй ещё раз!")
            ]
            return tryPhrases[abs(word.id.hashValue) % tryPhrases.count]
        }
    }

    private func buildHintText(level: Int, word: SortingWord) -> String {
        guard let set = currentSet else { return "" }
        switch level {
        case 1:
            // Подсветить правильную корзину.
            let catTitle = categories.first(where: { $0.id == word.correctCategory })?.title ?? ""
            return String(localized: "Посмотри на корзину «\(catTitle)»")
        case 2:
            // Голосовая подсказка: зависит от taskType.
            return buildVoiceHint(word: word, set: set)
        default:
            // Авто-placement.
            return String(localized: "Я помогу — кладу слово на место")
        }
    }

    private func buildVoiceHint(word: SortingWord, set: SortingSet) -> String {
        switch set.taskType {
        case .firstSound:
            let sound = String(word.word.prefix(1))
            return String(localized: "Это слово начинается на звук «\(sound)»")
        case .soundPosition:
            let catTitle = categories.first(where: { $0.id == word.correctCategory })?.title ?? ""
            return String(localized: "Звук в этом слове — \(catTitle.lowercased())")
        case .syllableCount:
            let catTitle = categories.first(where: { $0.id == word.correctCategory })?.title ?? ""
            return String(localized: "В этом слове \(catTitle.lowercased()) слога")
        case .vowelConsonant:
            return String(localized: "Послушай: есть ли гласный звук?")
        case .voicedUnvoiced:
            return String(localized: "Прислушайся: звонкий или глухой?")
        case .semantic:
            let catTitle = categories.first(where: { $0.id == word.correctCategory })?.title ?? ""
            return String(localized: "Это слово подходит к группе «\(catTitle)»")
        }
    }

    // MARK: - Private: scoring

    /// Комбинированный скор = hitRate * 0.70 + timeBonus * 0.15 + streakBonus.
    /// Авторасставленные слова не засчитываются в correct.
    /// Возвращает значение в [0…1].
    private func computeScore(
        correct: Int,
        total: Int,
        elapsed: Int,
        bestStreak: Int,
        autoPlacedCount: Int
    ) -> Float {
        let totalNonZero = max(total, 1)
        let hitRate = Float(correct) / Float(totalNonZero)
        let remaining = max(0, Self.timeLimit - elapsed)
        let timeBonus = Float(remaining) / Float(max(Self.timeLimit, 1)) * 0.15
        let streakBonus = min(0.15, Float(bestStreak) * 0.03)
        // Штраф за авторасстановку: -0.05 за каждые 3 авто-слова.
        let autoPenalty = Float(autoPlacedCount / 3) * 0.05
        let raw = hitRate * 0.70 + timeBonus + streakBonus - autoPenalty
        return min(1, max(0, raw))
    }
}
