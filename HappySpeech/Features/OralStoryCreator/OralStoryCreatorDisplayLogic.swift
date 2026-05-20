import Foundation

// MARK: - OralStoryCreatorDisplayLogic

@MainActor
protocol OralStoryCreatorDisplayLogic: AnyObject {
    func displayLoadStimuli(viewModel: OralStoryCreatorModels.LoadStimuli.ViewModel) async
    func displaySelect(viewModel: OralStoryCreatorModels.Select.ViewModel) async
    func displayRecordResult(viewModel: OralStoryCreatorModels.RecordResult.ViewModel) async
}
