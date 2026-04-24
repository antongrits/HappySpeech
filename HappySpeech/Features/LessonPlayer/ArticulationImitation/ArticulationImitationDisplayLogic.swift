import Foundation

// MARK: - ArticulationImitationDisplayLogic
//
// Presenter пишет в объект, подписанный на этот протокол. Для
// Clean Swift + SwiftUI эту роль играет `@Observable` store
// (см. `ArticulationImitationDisplay`).

@MainActor
protocol ArticulationImitationDisplayLogic: AnyObject {
    func displayLoadSession(_ viewModel: ArticulationImitationModels.LoadSession.ViewModel)
    func displayStartExercise(_ viewModel: ArticulationImitationModels.StartExercise.ViewModel)
    func displayHoldProgress(_ viewModel: ArticulationImitationModels.HoldProgress.ViewModel)
    func displayCompleteExercise(_ viewModel: ArticulationImitationModels.CompleteExercise.ViewModel)
    func displaySessionComplete(_ viewModel: ArticulationImitationModels.SessionComplete.ViewModel)
}
