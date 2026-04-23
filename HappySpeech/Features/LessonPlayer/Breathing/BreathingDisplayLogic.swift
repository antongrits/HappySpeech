import Foundation

// MARK: - BreathingDisplayLogic
//
// Contract between the Breathing `Presenter` and the SwiftUI view.
// The view holds an `@Observable` store that conforms to this protocol
// (see `BreathingView.Store`).

@MainActor
protocol BreathingDisplayLogic: AnyObject {
    func displayLoadSession(_ viewModel: BreathingModels.LoadSession.ViewModel)
    func displaySubmitAttempt(_ viewModel: BreathingModels.SubmitAttempt.ViewModel)
    func displayUpdateSignal(_ viewModel: BreathingModels.UpdateSignal.ViewModel)
    func displayFinish(_ viewModel: BreathingModels.Finish.ViewModel)
}
