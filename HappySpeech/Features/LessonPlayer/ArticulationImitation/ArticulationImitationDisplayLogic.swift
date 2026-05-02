import Foundation

// MARK: - ArticulationImitationDisplayLogic
//
// Presenter пишет в объект, подписанный на этот протокол.
// Для Clean Swift + SwiftUI эту роль играет StoreBridge.

@MainActor
protocol ArticulationImitationDisplayLogic: AnyObject {

    // MARK: Deep VIP
    func displayLoadSession(_ viewModel: ArticulationImitationModels.LoadSession.ViewModel)
    func displayStartPose(_ viewModel: ArticulationImitationModels.StartPose.ViewModel)
    func displayBeginMirroring(_ mode: MirroringMode)
    func displayBlendshapeUpdate(_ viewModel: ArticulationImitationModels.BlendshapeUpdate.ViewModel)
    func displayConfirmPose(_ viewModel: ArticulationImitationModels.ConfirmPose.ViewModel)
    func displayHint(_ viewModel: ArticulationImitationModels.RequestHint.ViewModel)
    func displayParentConfirmRequest(_ pose: ArticulationPose)
    func displaySessionComplete(_ viewModel: ArticulationImitationModels.SessionComplete.ViewModel)

    // MARK: Legacy
    func displayStartExercise(_ viewModel: ArticulationImitationModels.StartExercise.ViewModel)
    func displayHoldProgress(_ viewModel: ArticulationImitationModels.HoldProgress.ViewModel)
    func displayCompleteExercise(_ viewModel: ArticulationImitationModels.CompleteExercise.ViewModel)
}
