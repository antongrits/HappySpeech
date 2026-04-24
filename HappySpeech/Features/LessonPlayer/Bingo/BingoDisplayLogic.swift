import Foundation

// MARK: - BingoDisplayLogic
//
// Контракт между `BingoPresenter` и SwiftUI-слоем (`BingoViewDisplay`).
// Презентер вызывает методы только на @MainActor.

@MainActor
protocol BingoDisplayLogic: AnyObject {
    func displayLoadGame(_ viewModel: BingoModels.LoadGame.ViewModel)
    func displayCallWord(_ viewModel: BingoModels.CallWord.ViewModel)
    func displayMarkCell(_ viewModel: BingoModels.MarkCell.ViewModel)
    func displayCompleteGame(_ viewModel: BingoModels.CompleteGame.ViewModel)
}

// MARK: - BingoViewDisplay conformance

extension BingoViewDisplay: BingoDisplayLogic {

    func displayLoadGame(_ viewModel: BingoModels.LoadGame.ViewModel) {
        cells = viewModel.cells
        totalWords = viewModel.totalWords
        calledWord = viewModel.calledWord
        progressFraction = viewModel.progressFraction
        bingoLines = []
        isCalling = false
        phase = .playing
    }

    func displayCallWord(_ viewModel: BingoModels.CallWord.ViewModel) {
        calledWord = viewModel.calledWord
        calledWordIndex = viewModel.calledWordIndex
        totalWords = viewModel.totalWords
        progressFraction = viewModel.progressFraction
        isCalling = viewModel.isCalling
    }

    func displayMarkCell(_ viewModel: BingoModels.MarkCell.ViewModel) {
        cells = viewModel.cells
        bingoLines = viewModel.bingoLines
        // Если случилось бинго — переключаем фазу для overlay.
        if viewModel.phase == .bingo {
            phase = .bingo
            isCalling = false
        }
    }

    func displayCompleteGame(_ viewModel: BingoModels.CompleteGame.ViewModel) {
        scoreLabel = viewModel.scoreLabel
        starsEarned = viewModel.starsEarned
        completionMessage = viewModel.completionMessage
        lastScore = viewModel.finalScore
        phase = .completed
        isCalling = false
    }
}
