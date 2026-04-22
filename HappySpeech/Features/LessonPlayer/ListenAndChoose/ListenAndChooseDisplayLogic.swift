import Foundation

// MARK: - ListenAndChooseDisplayLogic

@MainActor
protocol ListenAndChooseDisplayLogic: AnyObject {
    func displayLoadSession(_ viewModel: ListenAndChooseModels.LoadSession.ViewModel)
    func displaySubmitAttempt(_ viewModel: ListenAndChooseModels.SubmitAttempt.ViewModel)
}
