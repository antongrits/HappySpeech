import Foundation

// MARK: - FingerPlayDisplayLogic

@MainActor
protocol FingerPlayDisplayLogic: AnyObject {
    func displayStart(viewModel: FingerPlayModels.Start.ViewModel) async
    func displayHandPoseUpdate(viewModel: FingerPlayModels.HandPoseUpdate.ViewModel) async
    func displayAdvance(viewModel: FingerPlayModels.Advance.ViewModel) async
}
