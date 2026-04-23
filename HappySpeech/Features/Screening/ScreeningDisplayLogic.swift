import Foundation

// MARK: - ScreeningDisplayLogic

@MainActor
protocol ScreeningDisplayLogic: AnyObject {
    func displayStartScreening(_ viewModel: ScreeningModels.StartScreening.ViewModel)
    func displaySubmitAnswer(_ viewModel: ScreeningModels.SubmitAnswer.ViewModel)
    func displayFinishScreening(_ viewModel: ScreeningModels.FinishScreening.ViewModel)
}
