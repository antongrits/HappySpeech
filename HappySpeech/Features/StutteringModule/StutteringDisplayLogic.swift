import Foundation

// MARK: - StutteringDisplayLogic

@MainActor
protocol StutteringDisplayLogic: AnyObject {
    func displayLoadScreen(_ viewModel: StutteringModels.LoadScreen.ViewModel)
    func displaySelectMode(_ viewModel: StutteringModels.SelectMode.ViewModel)
}
