import Foundation

// MARK: - MemoryPresentationLogic

@MainActor
protocol MemoryPresentationLogic: AnyObject {
    func presentLoadSession(_ response: MemoryModels.LoadSession.Response)
    func presentFlipCard(_ response: MemoryModels.FlipCard.Response)
    func presentTimerTick(_ response: MemoryModels.TimerTick.Response)
    func presentUseHint(_ response: MemoryModels.UseHint.Response)
    func presentCompleteRound(_ request: MemoryModels.CompleteRound.Request)
    func presentCompleteSession(_ request: MemoryModels.CompleteSession.Request)
}

// MARK: - MemoryPresenter
//
// Конвертирует доменные Response в ViewModel с локализацией и формулой звёзд.
//
// Скоринг (per round):
//   base   = matchedPairs / totalPairs
//   bonus  = max(0, (timeLimit - elapsed) / timeLimit) * 0.3
//   score  = clamp(base * 0.7 + bonus, 0...1)
// Итоговый: передаётся из Interactor (среднее по раундам).
// Звёзды: ≥0.85 → 3, ≥0.65 → 2, ≥0.40 → 1, иначе 0.

@MainActor
final class MemoryPresenter: MemoryPresentationLogic {

    weak var viewModel: (any MemoryDisplayLogic)?

    // MARK: - presentLoadSession

    func presentLoadSession(_ response: MemoryModels.LoadSession.Response) {
        let greeting = response.childName.isEmpty
            ? String(localized: "Найди все пары!")
            : String(localized: "Привет, \(response.childName)! Найди пары.")
        let minutes = response.timeLimit / 60
        let seconds = response.timeLimit % 60
        let timeLabel = String(format: "%02d:%02d", minutes, seconds)
        let roundLabel = String(
            localized: "Раунд \(response.roundIndex + 1) из \(response.totalRounds)"
        )
        let vm = MemoryModels.LoadSession.ViewModel(
            cards: response.cards,
            greeting: greeting,
            timeLimitLabel: timeLabel,
            difficultyLabel: response.difficulty.localizedTitle,
            roundLabel: roundLabel,
            hintsRemaining: response.hintsRemaining,
            columns: response.difficulty.columns
        )
        viewModel?.displayLoadSession(vm)
    }

    // MARK: - presentFlipCard

    func presentFlipCard(_ response: MemoryModels.FlipCard.Response) {
        let reason: MemoryGameOverReason? = response.gameOver ? .allMatched : nil
        let vm = MemoryModels.FlipCard.ViewModel(
            cards: response.cards,
            matchedPairId: response.matchedPairId,
            gameOverReason: reason,
            streakCount: response.streakCount,
            megaStreak: response.megaStreak,
            voiceCue: response.voiceCue
        )
        viewModel?.displayFlipCard(vm)
    }

    // MARK: - presentTimerTick

    func presentTimerTick(_ response: MemoryModels.TimerTick.Response) {
        let minutes = response.remaining / 60
        let seconds = response.remaining % 60
        let label = String(format: "%02d:%02d", minutes, seconds)
        let color: String
        switch response.remaining {
        case 0...10:  color = "red"
        case 11...20: color = "orange"
        default:      color = "green"
        }
        let vm = MemoryModels.TimerTick.ViewModel(
            timerLabel: label,
            expired: response.expired,
            timerColor: color
        )
        viewModel?.displayTimerTick(vm)
    }

    // MARK: - presentUseHint

    func presentUseHint(_ response: MemoryModels.UseHint.Response) {
        let vm = MemoryModels.UseHint.ViewModel(
            highlightedCardIds: response.highlightedCardIds,
            hintLevel: response.hintLevel,
            hintsRemaining: response.hintsRemaining,
            hintButtonEnabled: response.hintsRemaining > 0
        )
        viewModel?.displayUseHint(vm)
    }

    // MARK: - presentCompleteRound

    func presentCompleteRound(_ request: MemoryModels.CompleteRound.Request) {
        let result = request.result
        let stars = starsFor(score: result.score)
        let scoreLabel = "\(result.matchedPairs) / \(result.totalPairs)"
        let message = roundMessage(stars: stars, reason: result.reason, megaStreak: result.megaStreakBonus)
        let summary = roundSummary(result: result)

        let vm = MemoryModels.CompleteRound.ViewModel(
            starsEarned: stars,
            scoreLabel: scoreLabel,
            message: message,
            roundSummary: summary,
            hasNextRound: request.hasNextRound,
            finalScore: result.score
        )
        viewModel?.displayCompleteRound(vm)
    }

    // MARK: - presentCompleteSession

    func presentCompleteSession(_ request: MemoryModels.CompleteSession.Request) {
        let totalNonZero = max(request.matchedPairs, 1)
        let base = Float(request.matchedPairs) / Float(totalNonZero)
        let score = min(1, max(0, base))
        let stars = starsFor(score: score)
        let scoreLabel = "\(request.matchedPairs)"
        let message = sessionMessage(stars: stars, reason: request.reason)

        let vm = MemoryModels.CompleteSession.ViewModel(
            starsEarned: stars,
            scoreLabel: scoreLabel,
            message: message,
            finalScore: score
        )
        viewModel?.displayCompleteSession(vm)
    }

    // MARK: - Private helpers

    private func starsFor(score: Float) -> Int {
        switch score {
        case 0.85...:      return 3
        case 0.65..<0.85:  return 2
        case 0.40..<0.65:  return 1
        default:           return 0
        }
    }

    private func roundMessage(
        stars: Int,
        reason: MemoryGameOverReason,
        megaStreak: Bool
    ) -> String {
        if megaStreak {
            return String(localized: "Невероятно! Пять подряд — ты настоящий чемпион!")
        }
        switch (stars, reason) {
        case (3, _):
            return String(localized: "Превосходно! Ты нашёл все пары.")
        case (2, _):
            return String(localized: "Отличная работа!")
        case (1, _):
            return String(localized: "Хорошо! Тренируйся дальше.")
        case (_, .timeExpired):
            return String(localized: "Время вышло — попробуй ещё раз!")
        default:
            return String(localized: "Попробуй ещё раз — у тебя получится!")
        }
    }

    private func roundSummary(result: MemoryRoundResult) -> String {
        let minutes = result.elapsedSeconds / 60
        let seconds = result.elapsedSeconds % 60
        let timeStr = String(format: "%02d:%02d", minutes, seconds)
        return String(
            localized: "\(result.difficulty.localizedTitle) · \(result.matchedPairs)/\(result.totalPairs) пар · \(timeStr)"
        )
    }

    private func sessionMessage(stars: Int, reason: MemoryGameOverReason) -> String {
        switch (stars, reason) {
        case (3, _):
            return String(localized: "Все раунды пройдены отлично!")
        case (2, _):
            return String(localized: "Молодец — три раунда позади!")
        case (1, _):
            return String(localized: "Хорошая работа! Продолжай тренироваться.")
        case (_, .timeExpired):
            return String(localized: "Время вышло — попробуй ещё раз!")
        default:
            return String(localized: "Попробуй ещё раз — у тебя получится!")
        }
    }
}
