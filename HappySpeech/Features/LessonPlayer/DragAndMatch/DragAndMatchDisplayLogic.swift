import Foundation

// MARK: - DragAndMatchDisplayLogic

@MainActor
protocol DragAndMatchDisplayLogic: AnyObject {
    func displayLoadSession(_ viewModel: DragAndMatchModels.LoadSession.ViewModel)
    func displaySubmitAttempt(_ viewModel: DragAndMatchModels.SubmitAttempt.ViewModel)
}
