import Foundation

// MARK: - VoicingSoftnessDisplayLogic
//
// «Карта звонкости и мягкости» — Clean Swift: контракт View ← Presenter.

@MainActor
protocol VoicingSoftnessDisplayLogic: AnyObject {
    func displayStart(viewModel: VoicingSoftnessModels.Start.ViewModel) async
    func displayAnswer(viewModel: VoicingSoftnessModels.Answer.ViewModel) async
}
