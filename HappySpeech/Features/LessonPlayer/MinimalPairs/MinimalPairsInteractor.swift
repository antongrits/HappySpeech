import Foundation
import OSLog

// MARK: - MinimalPairsBusinessLogic

@MainActor
protocol MinimalPairsBusinessLogic: AnyObject {
    func loadSession(_ request: MinimalPairsModels.LoadSession.Request) async
    func startRound(_ request: MinimalPairsModels.StartRound.Request) async
    func selectOption(_ request: MinimalPairsModels.SelectOption.Request) async
    func replayCurrentWord() async
    func requestHint(_ request: MinimalPairsModels.RequestHint.Request) async
    func completeSession(_ request: MinimalPairsModels.CompleteSession.Request) async
    func cancelSession()
}

// MARK: - MinimalPairsInteractor
//
// Бизнес-логика игры «Минимальные пары» — дифференциация фонетически
// близких звуков (С/Ш, З/Ж, Р/Л, Б/П, Д/Т, Г/К, В/Ф, Ж/Ш, Ч/Щ…).
//
// Жизненный цикл сессии:
//   loadSession(soundContrast, childId, childName, age)
//     → buildRounds()          — 16+ пар, фильтр по контрасту, shuffle
//     → adaptRoundCount()      — длина сессии по возрасту (5-6л=7, 6-7л=8, 7-8л=10)
//     → startRound(0)
//       → speak(targetWord)    — LessonVoiceWorker (m4a → TTS fallback)
//       → selectOption(isTarget: Bool)
//         → scoring (streak, per-pair accuracy, mastery check)
//         → haptic + voice feedback
//         → presentSelectOption
//         → autoAdvance (1.5 с)
//         → startRound(next) | completeSession
//
// Подсказки (2 на раунд):
//   Hint 1 — highlight + 1 с подсветка правильной карточки
//   Hint 2 — voice clarification «Это слово на звук Ш»
//
// Адаптивность:
//   • Mastery learning: если пара 3 раза подряд неверно → добавить бонус-раунд
//   • Streak 5 подряд → бонус haptic + voice praise
//   • Replay cap: 3 повтора на раунд
//
// Скоринг:
//   ≥ 0.9 → 3 звезды, ≥ 0.7 → 2, ≥ 0.5 → 1, иначе 0

@MainActor
final class MinimalPairsInteractor: MinimalPairsBusinessLogic {

    // MARK: - Dependencies

    var presenter: (any MinimalPairsPresentationLogic)?
    private let hapticService: (any HapticService)?
    private let logger = Logger(subsystem: "ru.happyspeech", category: "MinimalPairs")

    // MARK: - Configuration

    /// Максимальное число подсказок на раунд.
    private static let maxHintsPerRound: Int = 2
    /// Максимальное число повторов слова за раунд.
    private static let maxReplaysPerRound: Int = 3
    /// Задержка автоперехода после фидбека (мс).
    private static let advanceDelay: Duration = .milliseconds(1500)
    /// Порог стрика для бонус-поощрения.
    private static let streakThreshold: Int = 5
    /// Сколько ошибок подряд на одну пару → добавить бонус-раунд (повторное закрепление).
    private static let errorThresholdForBonus: Int = 3

    // MARK: - Session metadata

    private var childId: String = ""
    private var childName: String = ""
    private var childAge: Int = 6
    private var soundContrast: String = ""
    private var sessionStartTime: Date = .distantPast
    private var isSessionOver: Bool = false

    // MARK: - Round state

    private var rounds: [MinimalPairRound] = []
    private var currentIndex: Int = 0
    private var roundStartTime: Date = .distantPast

    // MARK: - Scoring & streak

    /// Количество верных ответов (без учёта авто-решённых).
    private var correctCount: Int = 0
    /// Количество отвеченных раундов (верно + неверно).
    private var answeredCount: Int = 0
    /// Текущий стрик верных ответов подряд.
    private var streakCount: Int = 0
    /// Максимальный стрик за всю сессию.
    private var maxStreak: Int = 0

    // MARK: - Per-pair accuracy

    /// Словарь: soundContrast → (correct, total).
    private var pairAccuracy: [String: (correct: Int, total: Int)] = [:]

    // MARK: - Consecutive error tracking (adaptive learning)

    /// Словарь: soundContrast → количество ошибок подряд.
    private var consecutiveErrors: [String: Int] = [:]
    /// Набор контрастов, по которым уже добавлен бонус-раунд.
    private var bonusRoundAdded: Set<String> = []

    // MARK: - Per-round state

    private var currentHintsUsed: Int = 0
    private var currentReplaysUsed: Int = 0

    // MARK: - Async tasks

    private var advanceTask: Task<Void, Never>?
    private var speakTask: Task<Void, Never>?

    // MARK: - Init

    init(hapticService: (any HapticService)? = nil) {
        self.hapticService = hapticService
    }

    deinit {
        advanceTask?.cancel()
        speakTask?.cancel()
    }

    // MARK: - loadSession

    func loadSession(_ request: MinimalPairsModels.LoadSession.Request) async {
        guard !isSessionOver else { return }
        sessionStartTime = Date()
        childId = request.childId
        childName = request.childName
        childAge = request.childAge
        soundContrast = request.soundContrast
        correctCount = 0
        answeredCount = 0
        streakCount = 0
        maxStreak = 0
        pairAccuracy = [:]
        consecutiveErrors = [:]
        bonusRoundAdded = []
        currentHintsUsed = 0
        currentReplaysUsed = 0

        rounds = Self.buildRounds(contrast: soundContrast, count: sessionRoundCount)
        let logMsg = "loadSession contrast=\(soundContrast) rounds=\(rounds.count) age=\(childAge)"
        logger.info("\(logMsg, privacy: .public)")

        let response = MinimalPairsModels.LoadSession.Response(
            rounds: rounds,
            childName: childName,
            totalRounds: rounds.count
        )
        presenter?.presentLoadSession(response)
    }

    // MARK: - startRound

    func startRound(_ request: MinimalPairsModels.StartRound.Request) async {
        guard !isSessionOver else { return }
        guard request.roundIndex >= 0, request.roundIndex < rounds.count else {
            logger.error("startRound out of bounds: index=\(request.roundIndex) total=\(self.rounds.count)")
            return
        }
        currentIndex = request.roundIndex
        roundStartTime = Date()
        currentHintsUsed = 0
        currentReplaysUsed = 0

        let pair = rounds[currentIndex]
        logger.info("Round \(self.currentIndex + 1, privacy: .public)/\(self.rounds.count, privacy: .public) pair=\(pair.soundContrast, privacy: .public)")

        let response = MinimalPairsModels.StartRound.Response(
            pair: pair,
            roundNumber: currentIndex + 1,
            total: rounds.count,
            hintsAvailable: Self.maxHintsPerRound
        )
        presenter?.presentStartRound(response)

        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        speakWord(pair.targetWord)
    }

    // MARK: - selectOption

    func selectOption(_ request: MinimalPairsModels.SelectOption.Request) async {
        guard !isSessionOver, currentIndex < rounds.count else { return }
        let pair = rounds[currentIndex]
        let correct = request.selectedIsTarget

        // Обновляем счётчики.
        answeredCount += 1
        if correct {
            correctCount += 1
            streakCount += 1
            if streakCount > maxStreak { maxStreak = streakCount }
        } else {
            streakCount = 0
        }

        // Per-pair статистика.
        var entry = pairAccuracy[pair.soundContrast] ?? (0, 0)
        entry.total += 1
        if correct { entry.correct += 1 }
        pairAccuracy[pair.soundContrast] = entry

        // Mastery learning: трекинг последовательных ошибок.
        if correct {
            consecutiveErrors[pair.soundContrast] = 0
        } else {
            let errors = (consecutiveErrors[pair.soundContrast] ?? 0) + 1
            consecutiveErrors[pair.soundContrast] = errors
            if errors >= Self.errorThresholdForBonus,
               !bonusRoundAdded.contains(pair.soundContrast) {
                bonusRoundAdded.insert(pair.soundContrast)
                appendBonusRound(for: pair)
            }
        }

        // Стрик-бонус.
        let isStreakBonus = correct && (streakCount % Self.streakThreshold == 0) && streakCount > 0

        // Тактильный фидбек.
        if correct {
            hapticService?.selection()
            if isStreakBonus {
                await hapticService?.play(pattern: .celebration)
            }
        } else {
            hapticService?.notification(.warning)
        }

        let duration = Date().timeIntervalSince(roundStartTime)
        let roundMsg = "selectOption round=\(currentIndex + 1) correct=\(correct) streak=\(streakCount) dur=\(Int(duration))s"
        logger.info("\(roundMsg, privacy: .public)")

        let response = MinimalPairsModels.SelectOption.Response(
            correct: correct,
            correctAnswer: pair.targetWord,
            foilAnswer: pair.foilWord,
            soundContrast: pair.soundContrast,
            streakCount: streakCount,
            isStreakBonus: isStreakBonus,
            hintsUsedThisRound: currentHintsUsed,
            roundDurationSeconds: duration
        )
        presenter?.presentSelectOption(response)

        // Голосовой фидбек с небольшой паузой.
        scheduleVoiceFeedback(correct: correct, isStreakBonus: isStreakBonus, word: pair.targetWord)

        // Автопереход.
        scheduleAdvance()
    }

    // MARK: - replayCurrentWord

    func replayCurrentWord() async {
        guard !isSessionOver, currentIndex < rounds.count else { return }
        guard currentReplaysUsed < Self.maxReplaysPerRound else {
            logger.info("Replay cap reached (\(Self.maxReplaysPerRound, privacy: .public)) for round \(self.currentIndex + 1, privacy: .public)")
            let response = MinimalPairsModels.ReplayWord.Response(
                word: rounds[currentIndex].targetWord,
                replaysRemaining: 0,
                capReached: true
            )
            presenter?.presentReplayWord(response)
            return
        }
        currentReplaysUsed += 1
        let remaining = Self.maxReplaysPerRound - currentReplaysUsed
        let word = rounds[currentIndex].targetWord
        logger.info("Replay #\(self.currentReplaysUsed, privacy: .public) word=\(word, privacy: .public) remaining=\(remaining, privacy: .public)")

        let response = MinimalPairsModels.ReplayWord.Response(
            word: word,
            replaysRemaining: remaining,
            capReached: false
        )
        presenter?.presentReplayWord(response)
        speakWord(word)
    }

    // MARK: - requestHint

    func requestHint(_ request: MinimalPairsModels.RequestHint.Request) async {
        guard !isSessionOver, currentIndex < rounds.count else { return }
        guard currentHintsUsed < Self.maxHintsPerRound else {
            logger.info("Hint cap reached for round \(self.currentIndex + 1, privacy: .public)")
            presenter?.presentHint(MinimalPairsModels.RequestHint.Response(
                level: .voiceClarification,
                highlightDuration: 0,
                voiceText: nil,
                hintsRemaining: 0,
                capReached: true
            ))
            return
        }
        currentHintsUsed += 1
        let hintsRemaining = Self.maxHintsPerRound - currentHintsUsed
        let pair = rounds[currentIndex]

        let level: MinimalPairsHintLevel = currentHintsUsed == 1 ? .highlight : .voiceClarification
        var voiceText: String?

        switch level {
        case .highlight:
            // Hint 1: подсветка правильной карточки на 1 секунду.
            hapticService?.impact(.light)
            logger.info("Hint L1 highlight round=\(self.currentIndex + 1, privacy: .public)")

        case .voiceClarification:
            // Hint 2: голосовая подсказка «Это слово на звук Ш».
            let parts = pair.soundContrast.split(separator: "-")
            let targetSound = parts.first.map(String.init) ?? pair.soundContrast
            voiceText = String(localized: "Это слово на звук \(targetSound)")
            hapticService?.impact(.light)
            logger.info("Hint L2 voiceClarification sound=\(targetSound, privacy: .public)")
            if let text = voiceText {
                speakWord(text)
            }
        }

        let response = MinimalPairsModels.RequestHint.Response(
            level: level,
            highlightDuration: level == .highlight ? 1.0 : 0.0,
            voiceText: voiceText,
            hintsRemaining: hintsRemaining,
            capReached: false
        )
        presenter?.presentHint(response)
    }

    // MARK: - completeSession

    func completeSession(_ request: MinimalPairsModels.CompleteSession.Request) async {
        guard !isSessionOver else { return }
        isSessionOver = true
        advanceTask?.cancel()
        speakTask?.cancel()
        speakTask = nil
        LessonVoiceWorker.shared.stop()

        let totalDuration = Date().timeIntervalSince(sessionStartTime)
        let totalAnswered = max(answeredCount, 1)
        let accuracy = Double(correctCount) / Double(totalAnswered)
        let hintsTotal = rounds.prefix(currentIndex + 1).isEmpty ? 0 : currentHintsUsed

        // SM-2 качество для SpacedRepetitionEngine.
        let hadFatigue = hintsTotal > Self.maxHintsPerRound
        let quality = SM2Quality.fromSuccessRate(accuracy, hadFatigue: hadFatigue)

        let logMsg = "Session done \(correctCount)/\(totalAnswered) acc=\(Int(accuracy * 100))% streak=\(maxStreak) dur=\(Int(totalDuration))s"
        logger.info("\(logMsg, privacy: .public)")

        // Итоговый haptic по результату.
        if accuracy >= 0.9 {
            await hapticService?.play(pattern: .celebration)
        } else if accuracy >= 0.7 {
            await hapticService?.play(pattern: .rewardCollected)
        } else {
            hapticService?.impact(.soft)
        }

        let response = MinimalPairsModels.CompleteSession.Response(
            correctCount: correctCount,
            // totalRounds — общее число раундов в сессии (не число отвеченных).
            // accuracy/sm2Quality считаются отдельно по totalAnswered выше.
            totalRounds: rounds.count,
            pairAccuracy: pairAccuracy.mapValues { v in
                v.total > 0 ? Double(v.correct) / Double(v.total) : 0
            },
            maxStreak: maxStreak,
            totalHintsUsed: hintsTotal,
            totalDurationSeconds: totalDuration,
            sm2Quality: quality
        )
        presenter?.presentCompleteSession(response)
    }

    // MARK: - cancelSession

    func cancelSession() {
        isSessionOver = true
        advanceTask?.cancel()
        speakTask?.cancel()
        LessonVoiceWorker.shared.stop()
        logger.info("Session cancelled at round=\(self.currentIndex + 1, privacy: .public)")
    }

    // MARK: - Private: auto-advance

    private func scheduleAdvance() {
        advanceTask?.cancel()
        advanceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.advanceDelay)
            guard let self, !Task.isCancelled, !self.isSessionOver else { return }
            await self.advanceAfterFeedback()
        }
    }

    private func advanceAfterFeedback() async {
        let nextIndex = currentIndex + 1
        if nextIndex >= rounds.count {
            await completeSession(MinimalPairsModels.CompleteSession.Request())
        } else {
            await startRound(MinimalPairsModels.StartRound.Request(roundIndex: nextIndex))
        }
    }

    // MARK: - Private: voice feedback scheduling

    private func scheduleVoiceFeedback(correct: Bool, isStreakBonus: Bool, word: String) {
        speakTask?.cancel()
        speakTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled, !self.isSessionOver else { return }
            if isStreakBonus {
                await LessonVoiceWorker.shared.speak(
                    String(localized: "Потрясающе! Пять подряд!"),
                    lessonType: "minimal_pairs"
                )
            } else if correct {
                await LessonVoiceWorker.shared.speak(
                    String(localized: "Молодец!"),
                    lessonType: "minimal_pairs"
                )
            } else {
                await LessonVoiceWorker.shared.speak(
                    String(localized: "Послушай внимательно"),
                    lessonType: "minimal_pairs"
                )
            }
            self.speakTask = nil
        }
    }

    // MARK: - Private: word speech

    private func speakWord(_ word: String) {
        speakTask?.cancel()
        speakTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await LessonVoiceWorker.shared.speak(word, lessonType: "minimal_pairs")
            self.speakTask = nil
        }
    }

    // MARK: - Private: mastery bonus round

    /// Добавляет один бонус-раунд после текущего для проблемной пары.
    private func appendBonusRound(for pair: MinimalPairRound) {
        let bonus = Self.pickBonusRound(for: pair.soundContrast, excluding: pair.id)
        let insertIndex = min(currentIndex + 1, rounds.count)
        rounds.insert(bonus, at: insertIndex)
        logger.info("Mastery bonus round added at index=\(insertIndex, privacy: .public) pair=\(pair.soundContrast, privacy: .public)")

        let response = MinimalPairsModels.BonusRoundAdded.Response(
            message: String(localized: "Потренируемся ещё раз!"),
            totalRounds: rounds.count
        )
        presenter?.presentBonusRoundAdded(response)
    }

    // MARK: - Static: session round count by age

    var sessionRoundCount: Int {
        switch childAge {
        case ..<6:   return 7
        case 6:      return 8
        case 7:      return 9
        default:     return 10
        }
    }

    // MARK: - Static: round building

    /// Строит список раундов для сессии.
    /// - Если контраст задан — берём только пары данного контраста (С-Ш, Р-Л…).
    /// - Если контраст пустой — весь каталог, shuffle.
    /// - Повтор пар если пул меньше запрошенного количества.
    static func buildRounds(contrast: String, count: Int) -> [MinimalPairRound] {
        let pool: [MinimalPairRound] = contrast.isEmpty
            ? MinimalPairRound.extendedCatalog
            : MinimalPairRound.extendedCatalog.filter { $0.soundContrast == contrast }
        let source = pool.isEmpty ? MinimalPairRound.extendedCatalog : pool
        let shuffled = source.shuffled()
        var result: [MinimalPairRound] = []
        result.reserveCapacity(count)
        var idx = 0
        while result.count < count {
            let base = shuffled[idx % shuffled.count]
            let side = Bool.random()
            result.append(MinimalPairRound(
                id: "\(base.id)-\(result.count)",
                targetWord: base.targetWord,
                foilWord: base.foilWord,
                targetEmoji: base.targetEmoji,
                foilEmoji: base.foilEmoji,
                soundContrast: base.soundContrast,
                targetIsLeft: side
            ))
            idx += 1
        }
        return result
    }

    /// Выбирает один бонус-раунд для данного контраста, исключая уже показанный.
    private static func pickBonusRound(for contrast: String, excluding id: String) -> MinimalPairRound {
        let candidates = MinimalPairRound.extendedCatalog.filter {
            $0.soundContrast == contrast && !$0.id.hasPrefix(id)
        }
        let base = candidates.randomElement()
            ?? MinimalPairRound.extendedCatalog.filter { $0.soundContrast == contrast }.randomElement()
            ?? MinimalPairRound.extendedCatalog[0]
        return MinimalPairRound(
            id: "\(base.id)-bonus-\(Int.random(in: 1000...9999))",
            targetWord: base.targetWord,
            foilWord: base.foilWord,
            targetEmoji: base.targetEmoji,
            foilEmoji: base.foilEmoji,
            soundContrast: base.soundContrast,
            targetIsLeft: Bool.random()
        )
    }
}
