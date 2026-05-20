import Foundation

@MainActor
protocol SpeechGrowthDiaryDisplayLogic: AnyObject {
    func displayList(viewModel: SpeechGrowthDiaryModels.List.ViewModel) async
    func displayShare(viewModel: SpeechGrowthDiaryModels.Share.ViewModel) async
}
