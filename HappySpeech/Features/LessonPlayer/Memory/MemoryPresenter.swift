import Foundation

// MARK: - MemoryPresentationLogic

@MainActor
protocol MemoryPresentationLogic: AnyObject {
    func presentLoadSession(_ response: MemoryModels.LoadSession.Response)
    func presentFlipCard(_ response: MemoryModels.FlipCard.Response)
    func presentTimerTick(_ response: MemoryModels.TimerTick.Response)
    func presentCompleteSession(_ response: MemoryModels.CompleteSession.Request)
}

// MARK: - MemoryPresenter
//
// Конвертирует доменные Response в ViewModel с локализацией и формулой звёзд.
// Скоринг:
//   base   = matchedPairs / totalPairs
//   bonus  = max(0, (timeLimit - elapsed) / timeLimit) * 0.3
//   score  = clamp(base * 0.7 + bonus, 0...1)
// Звёзды: ≥0.85 → 3, ≥0.65 → 2, ≥0.40 → 1, иначе 0.

@MainActor
final class MemoryPresenter: MemoryPresentationLogic {

    weak var viewModel: (any MemoryDisplayLogic)?

    private let totalPairs: Int = 8
    private let timeLimit: Int = 60

    // MARK: LoadSession

    func presentLoadSession(_ response: MemoryModels.LoadSession.Response) {
        let greeting = response.childName.isEmpty
            ? String(localized: "Найди все пары!")
            : String(localized: "Привет, \(response.childName)! Найди пары.")
        let minutes = response.timeLimit / 60
        let seconds = response.timeLimit % 60
        let timeLabel = String(format: "%02d:%02d", minutes, seconds)
        let vm = MemoryModels.LoadSession.ViewModel(
            cards: response.cards,
            greeting: greeting,
            timeLimitLabel: timeLabel
        )
        viewModel?.displayLoadSession(vm)
    }

    // MARK: FlipCard

    func presentFlipCard(_ response: MemoryModels.FlipCard.Response) {
        let vm = MemoryModels.FlipCard.ViewModel(
            cards: response.cards,
            matchedPairId: response.matchedPairId,
            gameOverReason: response.gameOver ? .allMatched : nil
        )
        viewModel?.displayFlipCard(vm)
    }

    // MARK: TimerTick

    func presentTimerTick(_ response: MemoryModels.TimerTick.Response) {
        let minutes = response.remaining / 60
        let seconds = response.remaining % 60
        let label = String(format: "%02d:%02d", minutes, seconds)
        let color: String
        switch response.remaining {
        case 0:       color = "red"
        case 1...10:  color = "red"
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

    // MARK: CompleteSession

    /// Request несёт данные из Interactor — здесь конвертируем в ViewModel.
    func presentCompleteSession(_ request: MemoryModels.CompleteSession.Request) {
        let totalPairsNonZero = max(totalPairs, 1)
        let base = Float(request.matchedPairs) / Float(totalPairsNonZero)
        let remaining = max(0, timeLimit - request.elapsedSeconds)
        let bonus = Float(remaining) / Float(max(timeLimit, 1)) * 0.3
        let rawScore = base * 0.7 + bonus
        let score = min(1, max(0, rawScore))

        let stars: Int
        switch score {
        case 0.85...:      stars = 3
        case 0.65..<0.85:  stars = 2
        case 0.40..<0.65:  stars = 1
        default:           stars = 0
        }
        let scoreLabel = "\(request.matchedPairs) / \(totalPairs)"
        let message: String
        switch (stars, request.reason) {
        case (3, _):
            message = String(localized: "Превосходно! Ты нашёл все пары.")
        case (2, _):
            message = String(localized: "Отличная работа!")
        case (1, _):
            message = String(localized: "Хорошо! Тренируйся дальше.")
        case (_, .timeExpired):
            message = String(localized: "Время вышло — попробуй ещё раз!")
        default:
            message = String(localized: "Попробуй ещё раз — у тебя получится!")
        }
        let vm = MemoryModels.CompleteSession.ViewModel(
            starsEarned: stars,
            scoreLabel: scoreLabel,
            message: message,
            finalScore: score
        )
        viewModel?.displayCompleteSession(vm)
    }
}
