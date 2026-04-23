import Foundation

@MainActor
protocol ListenAndChooseDisplayLogic: AnyObject {
    func displayLoadRound(_ viewModel: ListenAndChooseModels.LoadRound.ViewModel)
    func displaySubmitAttempt(_ viewModel: ListenAndChooseModels.SubmitAttempt.ViewModel)
}
