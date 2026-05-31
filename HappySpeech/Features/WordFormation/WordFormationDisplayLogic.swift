import Foundation

// MARK: - WordFormationDisplayLogic
//
// F2-007 «Назови ласково / Один-много-нет» — Clean Swift: контракт
// View ← Presenter.

@MainActor
protocol WordFormationDisplayLogic: AnyObject {
    func displayStart(viewModel: WordFormationModels.Start.ViewModel) async
    func displayAnswer(viewModel: WordFormationModels.Answer.ViewModel) async
}
