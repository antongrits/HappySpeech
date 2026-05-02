import Foundation

// MARK: - StutteringDisplayLogic

@MainActor
protocol StutteringDisplayLogic: AnyObject {
    func displayLoadScreen(_ viewModel: StutteringModels.LoadScreen.ViewModel)
    func displaySelectMode(_ viewModel: StutteringModels.SelectMode.ViewModel)
    func displayLoadProgress(_ viewModel: StutteringModels.LoadProgress.ViewModel)
    func displayAdaptiveRecommendation(_ viewModel: StutteringModels.LoadAdaptiveRecommendation.ViewModel)
}
