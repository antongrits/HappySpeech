import Foundation
import OSLog

// MARK: - SortingBusinessLogic

@MainActor
protocol SortingBusinessLogic: AnyObject {
    func loadSession(_ request: SortingModels.LoadSession.Request) async
    func classifyWord(_ request: SortingModels.ClassifyWord.Request) async
    func completeSession(_ request: SortingModels.CompleteSession.Request) async
    func cancel()
}

// MARK: - SortingInteractor
//
// Игра «Сортировка по категориям». Ребёнок видит слово по центру и 2 кнопки
// с категориями под ним. Tap по кнопке классифицирует слово, даётся haptic
// + короткая подсветка, индекс сдвигается на следующее слово. После всех
// 8 слов — авто-completeSession.
//
// Ключевая логика:
//   • Каталог: 6 наборов (универсальный + по группам звуков). В loadSession
//     Interactor выбирает набор по `soundGroup` и перемешивает слова.
//   • Streak: 3+ правильных ответа подряд — hapticService.notification(.success)
//     и streakBadgeVisible=true на следующей феедбек-подсветке.
//   • Таймер: мягкий (90 с по умолчанию). Если истёк — авто-completeSession
//     с reason=.timeExpired. Оставшееся время влияет на итоговый скор.
//   • Double-tap защита: повторная классификация одного слова игнорируется.
//   • Скор = hitRate*0.75 + timeBonus*0.2 + streakBonus*(до 0.15), clamp 0…1.
//
// Жизненный цикл:
//   loadSession → presentLoadSession + startTimer
//   classifyWord → проверка / streak++ / haptic / presentClassifyWord
//     → если classifiedWords.count == words.count → completeSession(.allClassified)
//   timer expired → completeSession(.timeExpired)
//   cancel() — снять таймер при onDisappear.

@MainActor
final class SortingInteractor: SortingBusinessLogic {

    // MARK: Dependencies

    var presenter: (any SortingPresentationLogic)?
    private let hapticService: any HapticService
    private let logger = Logger(subsystem: "ru.happyspeech", category: "Sorting")

    // MARK: Config

    /// Мягкий лимит времени на весь набор (сек).
    private let timeLimit: Int = 90
    /// Порог серии для бонуса и отдельного «вау»-фидбека.
    private let streakBonusThreshold: Int = 3

    // MARK: State

    private var currentSet: SortingSet?
    private var words: [SortingWord] = []
    private var categories: [SortingCategory] = []
    private var classifiedWords: [String: String] = [:]

    private var currentStreak: Int = 0
    private var bestStreak: Int = 0

    private var elapsed: Int = 0
    private var timerTask: Task<Void, Never>?
    private var isGameOver: Bool = false

    // MARK: Init

    init(hapticService: any HapticService) {
        self.hapticService = hapticService
    }

    deinit {
        timerTask?.cancel()
    }

    // MARK: - loadSession

    func loadSession(_ request: SortingModels.LoadSession.Request) async {
        let set = SortingSet.set(for: request.soundGroup)
        self.currentSet = set
        self.words = set.words.shuffled()
        self.categories = set.categories
        self.classifiedWords = [:]
        self.currentStreak = 0
        self.bestStreak = 0
        self.elapsed = 0
        self.isGameOver = false
        logger.info("Sorting loaded set=\(set.id, privacy: .public) words=\(self.words.count, privacy: .public) categories=\(self.categories.count, privacy: .public) group=\(request.soundGroup, privacy: .public)")

        let response = SortingModels.LoadSession.Response(
            setTitle: set.title,
            words: self.words,
            categories: self.categories,
            childName: request.childName,
            timeLimit: timeLimit
        )
        presenter?.presentLoadSession(response)

        // Немедленный tick — чтобы таймер-лейбл сразу отрисовался.
        presenter?.presentTimerTick(SortingModels.TimerTick.Response(
            remaining: timeLimit,
            expired: false
        ))

        startTimer()
    }

    // MARK: - classifyWord

    func classifyWord(_ request: SortingModels.ClassifyWord.Request) async {
        guard !isGameOver else { return }
        guard let word = words.first(where: { $0.id == request.wordId }) else {
            logger.error("classifyWord: unknown wordId \(request.wordId, privacy: .public)")
            return
        }
        // Повторная классификация одного слова игнорируется — считаем первый
        // выбор. Это защищает от двойных тапов и ре-енданжмента.
        guard classifiedWords[request.wordId] == nil else {
            logger.debug("classifyWord: wordId=\(request.wordId, privacy: .public) already classified, ignore")
            return
        }
        classifiedWords[request.wordId] = request.categoryId
        let correct = word.isCorrect(targetCategory: request.categoryId)

        if correct {
            currentStreak += 1
            bestStreak = max(bestStreak, currentStreak)
        } else {
            currentStreak = 0
        }
        let streakTriggered = correct && currentStreak >= streakBonusThreshold

        logger.info("classify word=\(word.word, privacy: .public) → \(request.categoryId, privacy: .public) correct=\(correct) streak=\(self.currentStreak, privacy: .public) best=\(self.bestStreak, privacy: .public)")

        if correct {
            if streakTriggered {
                hapticService.notification(.success)
            } else {
                hapticService.selection()
            }
        } else {
            hapticService.notification(.warning)
        }

        let response = SortingModels.ClassifyWord.Response(
            correct: correct,
            wordId: request.wordId,
            streak: currentStreak,
            streakBonusTriggered: streakTriggered,
            feedback: correct ? "Верно!" : "Не совсем. Идём дальше."
        )
        presenter?.presentClassifyWord(response)

        if classifiedWords.count >= words.count {
            await completeSession(reason: .allClassified)
        }
    }

    // MARK: - completeSession

    func completeSession(_ request: SortingModels.CompleteSession.Request) async {
        await completeSession(reason: .allClassified)
    }

    // MARK: - cancel

    func cancel() {
        isGameOver = true
        timerTask?.cancel()
        timerTask = nil
        logger.info("Sorting cancelled")
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
                let remaining = max(0, self.timeLimit - self.elapsed)
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

    /// Обработка таймаута — авто-завершение игры с reason=.timeExpired.
    private func handleTimeout() async {
        guard !isGameOver else { return }
        logger.warning("Sorting timeout: time expired at \(self.classifiedWords.count, privacy: .public)/\(self.words.count, privacy: .public) classified")
        await completeSession(reason: .timeExpired)
    }

    // MARK: - Private: completeSession core

    private func completeSession(reason: SortingModels.CompleteSession.Reason) async {
        guard !isGameOver else { return }
        isGameOver = true
        timerTask?.cancel()
        timerTask = nil

        var correct = 0
        for word in words where classifiedWords[word.id] == word.correctCategory {
            correct += 1
        }
        let total = max(words.count, 1)
        let score = computeScore(correct: correct, total: total, elapsed: elapsed, bestStreak: bestStreak)
        logger.info("Sorting complete \(correct, privacy: .public)/\(total, privacy: .public) elapsed=\(self.elapsed, privacy: .public)s best=\(self.bestStreak, privacy: .public) reason=\(String(describing: reason), privacy: .public) score=\(score, privacy: .public)")

        let response = SortingModels.CompleteSession.Response(
            correctCount: correct,
            total: total,
            elapsedSeconds: elapsed,
            timeLimit: timeLimit,
            bestStreak: bestStreak,
            reason: reason,
            finalScore: score
        )
        presenter?.presentCompleteSession(response)
    }

    // MARK: - Private: scoring

    /// Комбинированный скор = hitRate * 0.75 + timeBonus + streakBonus.
    /// Возвращает значение в [0…1].
    private func computeScore(correct: Int, total: Int, elapsed: Int, bestStreak: Int) -> Float {
        let totalNonZero = max(total, 1)
        let hitRate = Float(correct) / Float(totalNonZero)
        let remaining = max(0, timeLimit - elapsed)
        let timeBonus = Float(remaining) / Float(max(timeLimit, 1)) * 0.2
        let streakBonus = min(0.15, Float(bestStreak) * 0.03)
        let raw = hitRate * 0.75 + timeBonus + streakBonus
        return min(1, max(0, raw))
    }
}
