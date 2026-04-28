import Foundation
import OSLog

// MARK: - GrammarScoringWorker

/// Вычисляет score за раунд, ведёт сессионную статистику, сигнализирует о наградах.
@MainActor
final class GrammarScoringWorker {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "GrammarScoring")

    // MARK: - Session state

    private(set) var correctCount: Int = 0
    private(set) var totalAnswered: Int = 0
    private var errorsPerRound: [UUID: Int] = [:]
    private var sessionStart: Date = .now
    private var roundsTotal: Int = 0

    // MARK: - Public API

    /// Записывает результат попытки и возвращает score (0 или 1) за раунд.
    func recordAttempt(
        roundId: UUID,
        isCorrect: Bool,
        difficulty: GrammarDifficulty
    ) -> AttemptResult {
        let errors = errorsPerRound[roundId] ?? 0

        if isCorrect {
            let score: Int = errors == 0 ? 1 : 0   // очко только за первую попытку
            correctCount += 1
            totalAnswered += 1
            let shouldShowReward = correctCount > 0 && correctCount % rewardThreshold(difficulty) == 0
            logger.debug(
                "Correct roundId=\(roundId) errors=\(errors) reward=\(shouldShowReward)"
            )
            return AttemptResult(
                isCorrect: true,
                scorePoints: score,
                shouldShowReward: shouldShowReward,
                errorsOnThisRound: errors
            )
        } else {
            errorsPerRound[roundId] = errors + 1
            totalAnswered += 1
            logger.debug("Wrong roundId=\(roundId) errors=\(errors + 1)")
            return AttemptResult(
                isCorrect: false,
                scorePoints: 0,
                shouldShowReward: false,
                errorsOnThisRound: errors + 1
            )
        }
    }

    /// Возвращает successRate за сессию [0.0, 1.0].
    /// Делитель — roundsTotal (а не totalAnswered), чтобы несколько ошибок на одном раунде не занижали rate.
    func sessionSuccessRate() -> Float {
        guard roundsTotal > 0 else { return 0 }
        return Float(correctCount) / Float(roundsTotal)
    }

    /// Длительность сессии в секундах.
    func sessionDurationSeconds() -> Int {
        Int(Date.now.timeIntervalSince(sessionStart))
    }

    /// Ошибок на конкретном раунде.
    func errorsOnRound(_ roundId: UUID) -> Int {
        errorsPerRound[roundId] ?? 0
    }

    /// Сброс состояния при старте новой игры.
    func reset(totalRounds: Int = 0) {
        correctCount = 0
        totalAnswered = 0
        errorsPerRound = [:]
        sessionStart = .now
        roundsTotal = totalRounds
    }

    // MARK: - Private helpers

    /// После скольких правильных ответов показываем промежуточную награду.
    private func rewardThreshold(_ difficulty: GrammarDifficulty) -> Int {
        switch difficulty {
        case .easy:   return 3
        case .medium: return 4
        case .hard:   return 5
        }
    }

    // MARK: - Result type

    struct AttemptResult: Sendable {
        let isCorrect: Bool
        let scorePoints: Int
        let shouldShowReward: Bool
        let errorsOnThisRound: Int
    }
}
