import Foundation

// MARK: - DragAndMatchDisplayLogic
//
// Протокол для Presenter → View (store). Все методы main-actor — пишут в
// @Observable state.

@MainActor
protocol DragAndMatchDisplayLogic: AnyObject {
    func displayLoadSession(_ viewModel: DragAndMatchModels.LoadSession.ViewModel)
    func displayDropWord(_ viewModel: DragAndMatchModels.DropWord.ViewModel)
    func displayCompleteSession(_ viewModel: DragAndMatchModels.CompleteSession.ViewModel)
}
