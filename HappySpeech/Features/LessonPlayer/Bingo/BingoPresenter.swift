import Foundation
import OSLog

// MARK: - BingoPresentationLogic

@MainActor
protocol BingoPresentationLogic: AnyObject {
    func presentLoadGame(_ response: BingoModels.LoadGame.Response)
    func presentCallWord(_ response: BingoModels.CallWord.Response)
    func presentMarkCell(_ response: BingoModels.MarkCell.Response)
    func presentCompleteGame(_ response: BingoModels.CompleteGame.Response)
}

// MARK: - BingoPresenter
//
// Конвертирует Response → ViewModel и передаёт в `BingoDisplayLogic`.
// Вся бизнес-логика (выбор слов, проверка линий, расчёт score) — в Interactor;
// здесь — только форматирование строк, локализация и формула звёзд.

@MainActor
final class BingoPresenter: BingoPresentationLogic {

    weak var display: (any BingoDisplayLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "BingoPresenter")

    // MARK: - LoadGame

    func presentLoadGame(_ response: BingoModels.LoadGame.Response) {
        logger.info("presentLoadGame cells=\(response.cells.count, privacy: .public) totalWords=\(response.totalWords, privacy: .public)")
        let viewModel = BingoModels.LoadGame.ViewModel(
            cells: response.cells,
            totalWords: response.totalWords,
            calledWord: response.firstWord ?? "",
            progressFraction: 0
        )
        display?.displayLoadGame(viewModel)
    }

    // MARK: - CallWord

    func presentCallWord(_ response: BingoModels.CallWord.Response) {
        let total = max(response.total, 1)
        let fraction = Double(response.index) / Double(total)
        let viewModel = BingoModels.CallWord.ViewModel(
            calledWord: response.word,
            calledWordIndex: response.index,
            totalWords: response.total,
            progressFraction: min(max(fraction, 0), 1),
            isCalling: true
        )
        display?.displayCallWord(viewModel)
    }

    // MARK: - MarkCell

    func presentMarkCell(_ response: BingoModels.MarkCell.Response) {
        let isBingo = !response.bingoLines.isEmpty
        // Если все клетки помечены — это всё ещё .playing с переходом в complete
        // на стороне Interactor; для UI-фазы важен сам факт «бинго».
        let phase: BingoPhase = isBingo ? .bingo : .playing
        let viewModel = BingoModels.MarkCell.ViewModel(
            cells: response.cells,
            bingoLines: response.bingoLines,
            phase: phase
        )
        display?.displayMarkCell(viewModel)
    }

    // MARK: - CompleteGame

    func presentCompleteGame(_ response: BingoModels.CompleteGame.Response) {
        let stars = Self.starsForScore(response.score)
        let scorePct = Int((response.score * 100).rounded())
        let scoreLabel = String(localized: "\(scorePct)%")

        let message: String
        if response.bingoAchieved {
            message = String(localized: "Молодец! Ты собрал бинго.")
        } else if stars >= 2 {
            message = String(localized: "Здорово! Ты услышал почти все слова.")
        } else if stars >= 1 {
            message = String(localized: "Хорошее начало! Попробуем ещё разок?")
        } else {
            message = String(localized: "Ничего страшного — давай послушаем внимательнее в следующий раз.")
        }

        logger.info("presentCompleteGame score=\(response.score, privacy: .public) stars=\(stars, privacy: .public) bingo=\(response.bingoAchieved, privacy: .public)")

        let viewModel = BingoModels.CompleteGame.ViewModel(
            scoreLabel: scoreLabel,
            starsEarned: stars,
            completionMessage: message,
            finalScore: response.score
        )
        display?.displayCompleteGame(viewModel)
    }

    // MARK: - Helpers

    /// Жёсткая шкала звёзд по итоговому score.
    /// ≥0.9 → 3, ≥0.7 → 2, ≥0.5 → 1, иначе 0.
    static func starsForScore(_ score: Float) -> Int {
        switch score {
        case 0.9...:    return 3
        case 0.7..<0.9: return 2
        case 0.5..<0.7: return 1
        default:        return 0
        }
    }
}
