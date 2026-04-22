import Foundation

@MainActor
protocol SessionShellDisplayLogic: AnyObject {
    func displayStartSession(_ viewModel: SessionShellModels.StartSession.ViewModel)
    func displayCompleteActivity(_ viewModel: SessionShellModels.CompleteActivity.ViewModel)
    func displayPauseSession(_ viewModel: SessionShellModels.PauseSession.ViewModel)
}
