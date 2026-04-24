import Foundation

// MARK: - PuzzleRevealDisplayLogic
//
// Протокол View-слоя. Presenter вызывает эти методы, чтобы обновить
// PuzzleRevealDisplay — @Observable модель, к которой привязан SwiftUI.

@MainActor
protocol PuzzleRevealDisplayLogic: AnyObject {
    func displayLoadPuzzle(_ viewModel: PuzzleRevealModels.LoadPuzzle.ViewModel)
    func displayStartRecord(_ viewModel: PuzzleRevealModels.StartRecord.ViewModel)
    func displayStopRecord(_ viewModel: PuzzleRevealModels.StopRecord.ViewModel)
    func displayRevealTile(_ viewModel: PuzzleRevealModels.RevealTile.ViewModel)
    func displayNextPuzzle(_ viewModel: PuzzleRevealModels.NextPuzzle.ViewModel)
    func displayComplete(_ viewModel: PuzzleRevealModels.Complete.ViewModel)
}
