import Foundation

// MARK: - ObjectHuntDisplayLogic

/// Контракт между Presenter и View (display side).
@MainActor
protocol ObjectHuntDisplayLogic: AnyObject {
    func displayLoadScene(_ viewModel: ObjectHuntModels.LoadScene.ViewModel)
    func displayTapObject(_ viewModel: ObjectHuntModels.TapObject.ViewModel)
    func displayUseHint(_ viewModel: ObjectHuntModels.UseHint.ViewModel)
    func displayTimerTick(_ viewModel: ObjectHuntModels.TimerTick.ViewModel)
    func displayCompleteScene(_ viewModel: ObjectHuntModels.CompleteScene.ViewModel)
    func displayCompleteGame(_ viewModel: ObjectHuntModels.CompleteGame.ViewModel)
}

// MARK: - ObjectHuntPresentationLogic

/// Контракт со стороны Interactor → Presenter.
@MainActor
protocol ObjectHuntPresentationLogic: AnyObject {
    func presentLoadScene(_ response: ObjectHuntModels.LoadScene.Response)
    func presentTapObject(_ response: ObjectHuntModels.TapObject.Response)
    func presentUseHint(_ response: ObjectHuntModels.UseHint.Response)
    func presentTimerTick(_ response: ObjectHuntModels.TimerTick.Response)
    func presentCompleteScene(_ response: ObjectHuntModels.CompleteScene.Response)
    func presentCompleteGame(_ response: ObjectHuntModels.CompleteGame.Response)
}

// MARK: - ObjectHuntRoutingLogic

/// Навигационный контракт.
@MainActor
protocol ObjectHuntRoutingLogic: AnyObject {
    func routeToComplete(score: Float)
}
