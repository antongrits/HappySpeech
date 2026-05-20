import Foundation

// MARK: - BilingualModeDisplayLogic

/// Контракт между Presenter и View (Holder).
@MainActor
protocol BilingualModeDisplayLogic: AnyObject {
    func displayLoadVocabulary(viewModel: BilingualModeModels.LoadVocabulary.ViewModel) async
    func displayStartPractice(viewModel: BilingualModeModels.StartPractice.ViewModel) async
    func displaySubmitAnswer(viewModel: BilingualModeModels.SubmitAnswer.ViewModel) async
    func displayFinishPractice(viewModel: BilingualModeModels.FinishPractice.ViewModel) async
}
