import Foundation

// MARK: - AssignedHomeworkDisplayLogic
//
// v29 Фаза 8, Функция 4 — Clean Swift: контракт View ← Presenter.

@MainActor
protocol AssignedHomeworkDisplayLogic: AnyObject {
    func displayLoad(viewModel: AssignedHomeworkModels.Load.ViewModel) async
    func displayCreate(viewModel: AssignedHomeworkModels.Create.ViewModel) async
}
