import Foundation

// MARK: - BedtimeModeDisplayLogic

@MainActor
protocol BedtimeModeDisplayLogic: AnyObject {
    func displayStart(viewModel: BedtimeModeModels.Start.ViewModel) async
    func displayAdvance(stage: BedtimeStage) async
    func displayNewStory(viewModel: BedtimeModeModels.Start.ViewModel) async
}
