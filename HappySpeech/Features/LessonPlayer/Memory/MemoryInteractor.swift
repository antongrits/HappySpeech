import Foundation
import OSLog

// MARK: - MemoryBusinessLogic

@MainActor
protocol MemoryBusinessLogic: AnyObject {
    func loadSession(_ request: MemoryModels.LoadSession.Request) async
    func flipCard(_ request: MemoryModels.FlipCard.Request) async
    func useHint(_ request: MemoryModels.UseHint.Request) async
    func advanceToNextRound() async
    func cancel()
}

// MARK: - MemoryInteractor
//
// «Найди пару» — полная игровая логика.
//
// Сложности и сетки:
//   easy   → 4×4 (8 пар, 60 с)
//   medium → 4×6 (12 пар, 90 с)
//   hard   → 6×6 (18 пар, 120 с)
//
// Раунды: 3 раунда за сессию (easy → medium → hard). Каждый раунд —
// полная новая колода соответствующей сложности.
//
// Card flip mechanics:
//   flipCard → если карта не matched и не faceUp — переворачиваем.
//   Если 2 открытых:
//     • pairId равны → mark matched, matchedPairs++, streak++.
//     • не равны     → isFlipDisabled, ждём 1.5 с, закрываем обе.
//   allMatched → completeRound.
//
// Стрик:
//   3 матча подряд → streakBonus (voice + haptic).
//   5 матча подряд → megaStreak (extra feedback).
//
// Подсказки (3 уровня, 3 штуки на сессию):
//   Уровень 1 (single):  подсвечиваем одну случайную несовпавшую карту 0.5 с.
//   Уровень 2 (pair):    подсвечиваем обе карты одной несовпавшей пары 0.5 с.
//   Уровень 3 (all):     показываем все несовпавшие пары на 1.0 с.
//   Кнопка Hint disabled если hintsRemaining == 0 или isFlipDisabled.
//
// Per-card stats:
//   Каждая карта считает: flipCount, firstFlipTimestamp.
//   По окончании раунда строим [MemoryCardStat] — передаём в Presenter.
//
// Таймер: отдельный Task, каждую секунду считает elapsed.
//   При elapsed >= timeLimit → completeRound(.timeExpired).
//   При remaining == 15 → voice cue timeWarning.

@MainActor
final class MemoryInteractor: MemoryBusinessLogic {

    // MARK: - Dependencies

    var presenter: (any MemoryPresentationLogic)?
    private let hapticService: any HapticService
    private let logger = Logger(subsystem: "ru.happyspeech", category: "Memory")

    // MARK: - Session config

    private static let totalRounds = 3
    private let difficulties: [MemoryDifficulty] = [.easy, .medium, .hard]

    // MARK: - Session state

    private var soundGroup: String = ""
    private var childName: String = ""
    private var currentRoundIndex: Int = 0
    private var roundResults: [MemoryRoundResult] = []
    private var hintsRemaining: Int = 3
    private var sessionStartTime: TimeInterval = 0
    private var timeWarningFired: Bool = false

    // MARK: - Round state

    private var cards: [MemoryCard] = []
    private var openIndices: [Int] = []
    private var matchedPairs: Int = 0
    private var totalPairs: Int = 8
    private var isFlipDisabled: Bool = false
    private var isGameOver: Bool = false
    private var elapsed: Int = 0
    private var timerTask: Task<Void, Never>?

    // MARK: - Streak state

    private var currentStreak: Int = 0
    private var hasFireStreak3: Bool = false
    private var hasFireMegaStreak: Bool = false

    // MARK: - Hint state

    private var hintTask: Task<Void, Never>?

    // MARK: - Init

    init(hapticService: any HapticService) {
        self.hapticService = hapticService
    }

    deinit {
        timerTask?.cancel()
        hintTask?.cancel()
    }

    // MARK: - loadSession

    func loadSession(_ request: MemoryModels.LoadSession.Request) async {
        soundGroup = request.soundGroup
        childName = request.childName
        currentRoundIndex = 0
        roundResults = []
        hintsRemaining = 3
        sessionStartTime = Date().timeIntervalSinceReferenceDate
        timeWarningFired = false
        logger.info("Memory session start soundGroup=\(request.soundGroup, privacy: .public)")

        await beginRound(
            index: currentRoundIndex,
            difficulty: difficulties[currentRoundIndex],
            voiceCue: .welcome
        )
    }

    // MARK: - flipCard

    func flipCard(_ request: MemoryModels.FlipCard.Request) async {
        guard !isGameOver, !isFlipDisabled else { return }
        guard let idx = cards.firstIndex(where: { $0.id == request.cardId }) else {
            logger.error("flipCard: unknown cardId \(request.cardId, privacy: .public)")
            return
        }
        guard !cards[idx].isMatched, !cards[idx].isFaceUp else { return }

        // Flip the card and update stats
        cards[idx].isFaceUp = true
        cards[idx].flipCount += 1
        if cards[idx].firstFlipTimestamp == nil {
            cards[idx].firstFlipTimestamp = Date().timeIntervalSinceReferenceDate
        }
        openIndices.append(idx)
        hapticService.selection()

        // One card open — update UI
        if openIndices.count == 1 {
            presenter?.presentFlipCard(MemoryModels.FlipCard.Response(
                cards: cards,
                matchFound: false,
                matchedPairId: nil,
                gameOver: false,
                streakCount: currentStreak,
                megaStreak: false,
                voiceCue: nil
            ))
            return
        }

        // Two cards open — check pair
        let firstIdx  = openIndices[0]
        let secondIdx = openIndices[1]
        let firstCard  = cards[firstIdx]
        let secondCard = cards[secondIdx]

        if firstCard.pairId == secondCard.pairId {
            await handleMatch(firstIdx: firstIdx, secondIdx: secondIdx)
        } else {
            await handleMismatch(firstIdx: firstIdx, secondIdx: secondIdx)
        }
    }

    // MARK: - useHint

    func useHint(_ request: MemoryModels.UseHint.Request) async {
        guard hintsRemaining > 0, !isGameOver, !isFlipDisabled else { return }

        hintsRemaining -= 1
        let level = resolveHintLevel()
        let targets = hintTargets(for: level)
        let duration: TimeInterval = level == .all ? 1.0 : 0.5

        hapticService.impact(.light)
        logger.info("Hint used level=\(level.rawValue, privacy: .public) remaining=\(self.hintsRemaining, privacy: .public)")

        presenter?.presentUseHint(MemoryModels.UseHint.Response(
            highlightedCardIds: targets,
            hintLevel: level,
            hintsRemaining: hintsRemaining
        ))

        hintTask?.cancel()
        hintTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self.presenter?.presentUseHint(MemoryModels.UseHint.Response(
                highlightedCardIds: [],
                hintLevel: level,
                hintsRemaining: self.hintsRemaining
            ))
        }

        // Voice cue for hint used
        presenter?.presentFlipCard(MemoryModels.FlipCard.Response(
            cards: cards,
            matchFound: false,
            matchedPairId: nil,
            gameOver: false,
            streakCount: currentStreak,
            megaStreak: false,
            voiceCue: .hintUsed
        ))
    }

    // MARK: - advanceToNextRound

    func advanceToNextRound() async {
        let nextIndex = currentRoundIndex + 1
        guard nextIndex < Self.totalRounds else {
            await finalizeSession()
            return
        }
        currentRoundIndex = nextIndex
        timeWarningFired = false
        logger.info("Advancing to round \(nextIndex, privacy: .public)")
        await beginRound(
            index: nextIndex,
            difficulty: difficulties[nextIndex],
            voiceCue: nil
        )
    }

    // MARK: - cancel

    func cancel() {
        isGameOver = true
        timerTask?.cancel()
        timerTask = nil
        hintTask?.cancel()
        hintTask = nil
        logger.info("Memory cancelled at round=\(self.currentRoundIndex, privacy: .public)")
    }

    // MARK: - Private: beginRound

    private func beginRound(
        index: Int,
        difficulty: MemoryDifficulty,
        voiceCue: MemoryVoiceCue?
    ) async {
        let deck = MemoryCard.deck(for: soundGroup, difficulty: difficulty)
        cards = deck
        totalPairs = difficulty.pairCount
        matchedPairs = 0
        openIndices = []
        isFlipDisabled = false
        isGameOver = false
        elapsed = 0
        currentStreak = 0
        hasFireStreak3 = false
        hasFireMegaStreak = false

        let roundInfo = "difficulty=\(difficulty.rawValue) cards=\(deck.count) limit=\(difficulty.timeLimit)s"
        logger.info("Round \(index, privacy: .public) started \(roundInfo, privacy: .public)")

        let response = MemoryModels.LoadSession.Response(
            cards: cards,
            childName: childName,
            timeLimit: difficulty.timeLimit,
            difficulty: difficulty,
            roundIndex: index,
            totalRounds: Self.totalRounds,
            hintsRemaining: hintsRemaining
        )
        presenter?.presentLoadSession(response)

        if let cue = voiceCue {
            presenter?.presentFlipCard(MemoryModels.FlipCard.Response(
                cards: cards,
                matchFound: false,
                matchedPairId: nil,
                gameOver: false,
                streakCount: 0,
                megaStreak: false,
                voiceCue: cue
            ))
        }

        presenter?.presentTimerTick(MemoryModels.TimerTick.Response(
            remaining: difficulty.timeLimit,
            expired: false
        ))

        startTimer(timeLimit: difficulty.timeLimit)
    }

    // MARK: - Private: handleMatch

    private func handleMatch(firstIdx: Int, secondIdx: Int) async {
        cards[firstIdx].isMatched = true
        cards[secondIdx].isMatched = true
        matchedPairs += 1
        currentStreak += 1
        hapticService.notification(.success)

        let pairId = cards[firstIdx].pairId
        let allMatched = matchedPairs >= totalPairs

        let matchInfo = "\(matchedPairs)/\(totalPairs) streak=\(currentStreak)"
        logger.info("Match pair=\(pairId, privacy: .public) \(matchInfo, privacy: .public)")

        // Determine streak voice cue
        let voiceCue: MemoryVoiceCue? = resolveStreakCue()

        let isMegaStreak = currentStreak >= 5 && !hasFireMegaStreak
        if isMegaStreak {
            hasFireMegaStreak = true
            hapticService.notification(.success)
        }

        presenter?.presentFlipCard(MemoryModels.FlipCard.Response(
            cards: cards,
            matchFound: true,
            matchedPairId: pairId,
            gameOver: allMatched,
            streakCount: currentStreak,
            megaStreak: isMegaStreak,
            voiceCue: voiceCue ?? .match
        ))
        openIndices.removeAll()

        if allMatched {
            await completeRound(reason: .allMatched)
        }
    }

    // MARK: - Private: handleMismatch

    private func handleMismatch(firstIdx: Int, secondIdx: Int) async {
        currentStreak = 0
        hasFireStreak3 = false
        hasFireMegaStreak = false
        hapticService.notification(.warning)
        isFlipDisabled = true

        presenter?.presentFlipCard(MemoryModels.FlipCard.Response(
            cards: cards,
            matchFound: false,
            matchedPairId: nil,
            gameOver: false,
            streakCount: 0,
            megaStreak: false,
            voiceCue: .mismatch
        ))

        try? await Task.sleep(for: .seconds(1.5))
        guard !isGameOver else { return }

        for openIdx in [firstIdx, secondIdx] where !cards[openIdx].isMatched {
            cards[openIdx].isFaceUp = false
        }
        openIndices.removeAll()
        isFlipDisabled = false

        presenter?.presentFlipCard(MemoryModels.FlipCard.Response(
            cards: cards,
            matchFound: false,
            matchedPairId: nil,
            gameOver: false,
            streakCount: 0,
            megaStreak: false,
            voiceCue: nil
        ))
    }

    // MARK: - Private: resolveStreakCue

    private func resolveStreakCue() -> MemoryVoiceCue? {
        if currentStreak >= 5 && !hasFireMegaStreak {
            return .megaStreak
        }
        if currentStreak == 3 && !hasFireStreak3 {
            hasFireStreak3 = true
            return .streak3
        }
        return nil
    }

    // MARK: - Private: resolveHintLevel

    private func resolveHintLevel() -> MemoryHintLevel {
        let usedHints = 3 - hintsRemaining
        switch usedHints {
        case 0: return .single
        case 1: return .pair
        default: return .all
        }
    }

    // MARK: - Private: hintTargets

    private func hintTargets(for level: MemoryHintLevel) -> [String] {
        let unmatchedGroups = Dictionary(
            grouping: cards.filter { !$0.isMatched && !$0.isFaceUp },
            by: { $0.pairId }
        )
        let pairs = unmatchedGroups.values.filter { $0.count == 2 }

        switch level {
        case .single:
            return [pairs.randomElement()?.first?.id].compactMap { $0 }
        case .pair:
            if let pair = pairs.randomElement() {
                return pair.map { $0.id }
            }
            return []
        case .all:
            return pairs.flatMap { $0.map { $0.id } }
        }
    }

    // MARK: - Private: buildCardStats

    private func buildCardStats() -> [MemoryCardStat] {
        let matched = cards.filter { $0.isMatched }
        let now = Date().timeIntervalSinceReferenceDate
        var seen = Set<String>()
        var stats: [MemoryCardStat] = []
        for card in matched {
            guard !seen.contains(card.pairId) else { continue }
            seen.insert(card.pairId)
            let flipCount = matched
                .filter { $0.pairId == card.pairId }
                .map { $0.flipCount }
                .reduce(0, +)
            let firstFlip = matched
                .filter { $0.pairId == card.pairId }
                .compactMap { $0.firstFlipTimestamp }
                .min() ?? now
            let matchTime = now - firstFlip
            stats.append(MemoryCardStat(
                pairId: card.pairId,
                word: card.word,
                flipCount: flipCount,
                matchTimeSeconds: matchTime
            ))
        }
        return stats
    }

    // MARK: - Private: completeRound

    private func completeRound(reason: MemoryGameOverReason) async {
        timerTask?.cancel()
        timerTask = nil
        isGameOver = true

        let difficulty = difficulties[currentRoundIndex]
        let stats = buildCardStats()
        let hasNextRound = currentRoundIndex + 1 < Self.totalRounds
        let streakBonus = currentStreak >= 3
        let megaStreakBonus = currentStreak >= 5

        let completeInfo = "matched=\(matchedPairs)/\(totalPairs) elapsed=\(elapsed)s hasNext=\(hasNextRound)"
        logger.info(
            "Round \(self.currentRoundIndex, privacy: .public) complete \(completeInfo, privacy: .public)"
        )

        let result = MemoryRoundResult(
            difficulty: difficulty,
            matchedPairs: matchedPairs,
            totalPairs: totalPairs,
            elapsedSeconds: elapsed,
            timeLimit: difficulty.timeLimit,
            reason: reason,
            cardStats: stats,
            streakBonus: streakBonus,
            megaStreakBonus: megaStreakBonus
        )
        roundResults.append(result)

        let endCue: MemoryVoiceCue = reason == .allMatched
            ? (hasNextRound ? .roundDone : .allDone)
            : .timeExpired

        presenter?.presentFlipCard(MemoryModels.FlipCard.Response(
            cards: cards,
            matchFound: false,
            matchedPairId: nil,
            gameOver: true,
            streakCount: currentStreak,
            megaStreak: megaStreakBonus,
            voiceCue: endCue
        ))

        presenter?.presentCompleteRound(MemoryModels.CompleteRound.Request(
            result: result,
            hasNextRound: hasNextRound
        ))

        if !hasNextRound {
            await finalizeSession()
        }
    }

    // MARK: - Private: finalizeSession

    private func finalizeSession() async {
        let totalMatched = roundResults.map { $0.matchedPairs }.reduce(0, +)
        let totalPossible = roundResults.map { $0.totalPairs }.reduce(0, +)
        let avgScore = roundResults.isEmpty
            ? 0
            : roundResults.map { $0.score }.reduce(0, +) / Float(roundResults.count)
        let totalElapsed = roundResults.map { $0.elapsedSeconds }.reduce(0, +)

        logger.info(
            "Session final avgScore=\(avgScore, privacy: .public) totalMatched=\(totalMatched, privacy: .public)/\(totalPossible, privacy: .public)"
        )

        let lastReason = roundResults.last?.reason ?? .allMatched
        presenter?.presentCompleteSession(MemoryModels.CompleteSession.Request(
            matchedPairs: totalMatched,
            elapsedSeconds: totalElapsed,
            reason: lastReason
        ))
    }

    // MARK: - Private: startTimer

    private func startTimer(timeLimit: Int) {
        timerTask?.cancel()
        timerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                guard !self.isGameOver else { return }
                self.elapsed += 1
                let remaining = max(0, timeLimit - self.elapsed)
                let expired = remaining == 0

                self.presenter?.presentTimerTick(MemoryModels.TimerTick.Response(
                    remaining: remaining,
                    expired: expired
                ))

                if remaining == 15 && !self.timeWarningFired {
                    self.timeWarningFired = true
                    self.presenter?.presentFlipCard(MemoryModels.FlipCard.Response(
                        cards: self.cards,
                        matchFound: false,
                        matchedPairId: nil,
                        gameOver: false,
                        streakCount: self.currentStreak,
                        megaStreak: false,
                        voiceCue: .timeWarning
                    ))
                }

                if expired {
                    self.isGameOver = true
                    await self.completeRound(reason: .timeExpired)
                    return
                }
            }
        }
    }
}
