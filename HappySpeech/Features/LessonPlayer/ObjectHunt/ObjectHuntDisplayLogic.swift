import Foundation

// MARK: - ObjectHuntDisplayLogic

/// Контракт между Presenter и View (display side).
@MainActor
protocol ObjectHuntDisplayLogic: AnyObject {
    func displayLoadRound(_ viewModel: ObjectHuntModels.LoadRound.ViewModel)
    func displayFrameAnalyzed(_ viewModel: ObjectHuntModels.FrameAnalyzed.ViewModel)
    func displayCompleteRound(_ viewModel: ObjectHuntModels.CompleteRound.ViewModel)
    func displayCompleteGame(_ viewModel: ObjectHuntModels.CompleteGame.ViewModel)
}

// MARK: - ObjectHuntPresentationLogic

/// Контракт со стороны Interactor → Presenter.
@MainActor
protocol ObjectHuntPresentationLogic: AnyObject {
    func presentLoadRound(_ response: ObjectHuntModels.LoadRound.Response)
    func presentFrameAnalyzed(_ response: ObjectHuntModels.FrameAnalyzed.Response)
    func presentCompleteRound(_ response: ObjectHuntModels.CompleteRound.Response)
    func presentCompleteGame(_ response: ObjectHuntModels.CompleteGame.Response)
}

// MARK: - ObjectHuntRoutingLogic

/// Навигационный контракт.
@MainActor
protocol ObjectHuntRoutingLogic: AnyObject {
    func routeToComplete()
}
