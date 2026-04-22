import Foundation

// MARK: - ARZoneDisplayLogic

@MainActor
protocol ARZoneDisplayLogic: AnyObject {
    func displayLoadGames(_ viewModel: ARZoneModels.LoadGames.ViewModel)
    func displaySelectGame(_ viewModel: ARZoneModels.SelectGame.ViewModel)
}
