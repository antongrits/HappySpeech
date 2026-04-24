import Foundation
import OSLog

// MARK: - PuzzleRevealPresentationLogic

@MainActor
protocol PuzzleRevealPresentationLogic: AnyObject {
    func presentLoadPuzzle(_ response: PuzzleRevealModels.LoadPuzzle.Response)
    func presentStartRecord(_ response: PuzzleRevealModels.StartRecord.Response)
    func presentStopRecord(_ response: PuzzleRevealModels.StopRecord.Response)
    func presentRevealTile(_ response: PuzzleRevealModels.RevealTile.Response)
    func presentNextPuzzle(_ response: PuzzleRevealModels.NextPuzzle.Response)
    func presentComplete(_ response: PuzzleRevealModels.Complete.Response)
}

// MARK: - PuzzleRevealPresenter
//
// Превращает Response от Interactor в ViewModel — форматирует тексты, считает
// прогресс, готовит feedback-сообщения. Сам по себе без состояния, но держит
// ссылку на @Observable Display, чтобы писать туда напрямую (пусть даже через
// протокол DisplayLogic).

@MainActor
final class PuzzleRevealPresenter: PuzzleRevealPresentationLogic {

    weak var viewModel: (any PuzzleRevealDisplayLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "PuzzleRevealPresenter")

    // MARK: - LoadPuzzle

    func presentLoadPuzzle(_ response: PuzzleRevealModels.LoadPuzzle.Response) {
        let totalTiles = max(1, response.tiles.count)
        let revealed = response.tiles.filter { $0.isRevealed }.count
        let progress = Double(revealed) / Double(totalTiles)

        let vm = PuzzleRevealModels.LoadPuzzle.ViewModel(
            tiles: response.tiles,
            word: response.word,
            emoji: response.emoji,
            hintText: response.hintText,
            puzzleIndex: response.puzzleIndex,
            totalPuzzles: response.totalPuzzles,
            attemptNumber: response.attemptNumber,
            progressFraction: progress,
            isASRAvailable: response.isASRAvailable
        )
        viewModel?.displayLoadPuzzle(vm)
    }

    // MARK: - StartRecord

    func presentStartRecord(_ response: PuzzleRevealModels.StartRecord.Response) {
        viewModel?.displayStartRecord(.init())
    }

    // MARK: - StopRecord

    func presentStopRecord(_ response: PuzzleRevealModels.StopRecord.Response) {
        viewModel?.displayStopRecord(.init())
    }

    // MARK: - RevealTile

    func presentRevealTile(_ response: PuzzleRevealModels.RevealTile.Response) {
        let feedback = Self.feedbackText(for: response.score)
        let revealedCount = response.tiles.filter { $0.isRevealed }.count
        let total = max(1, response.tiles.count)
        let progress = Double(revealedCount) / Double(total)

        logger.info("revealTile idx=\(response.tileIndex, privacy: .public) score=\(response.score, privacy: .public) allRevealed=\(response.allRevealed, privacy: .public)")

        let vm = PuzzleRevealModels.RevealTile.ViewModel(
            tileIndex: response.tileIndex,
            tiles: response.tiles,
            feedbackText: feedback,
            lastScore: response.score,
            progressFraction: progress,
            attemptNumber: response.attemptNumber,
            allRevealed: response.allRevealed
        )
        viewModel?.displayRevealTile(vm)
    }

    // MARK: - NextPuzzle

    func presentNextPuzzle(_ response: PuzzleRevealModels.NextPuzzle.Response) {
        viewModel?.displayNextPuzzle(.init(hasNext: response.hasNext))
    }

    // MARK: - Complete

    func presentComplete(_ response: PuzzleRevealModels.Complete.Response) {
        let percent = Int((response.averageScore * 100).rounded())
        let scoreLabel = String(localized: "Ты открыл \(percent) процентов пазла!")
        let message = Self.completionMessage(for: response.starsEarned)

        let vm = PuzzleRevealModels.Complete.ViewModel(
            finalScore: response.averageScore,
            starsEarned: response.starsEarned,
            scoreLabel: scoreLabel,
            completionMessage: message
        )
        viewModel?.displayComplete(vm)
    }

    // MARK: - Helpers

    private static func feedbackText(for score: Float) -> String {
        if score >= 0.85 {
            return String(localized: "Отлично!")
        } else if score >= 0.6 {
            return String(localized: "Хорошо!")
        } else {
            return String(localized: "Попробуй в следующий раз")
        }
    }

    private static func completionMessage(for stars: Int) -> String {
        switch stars {
        case 3: return String(localized: "Ты собрал все пазлы! Ляля в восторге.")
        case 2: return String(localized: "Здорово! Ты почти собрал всё.")
        case 1: return String(localized: "Молодец, что дошёл до конца!")
        default: return String(localized: "Попробуй ещё раз — у тебя получится.")
        }
    }
}
