import Foundation

// MARK: - AssignedHomeworkDisplayLogic
//
// Clean Swift: контракт View ← Presenter.

@MainActor
protocol AssignedHomeworkDisplayLogic: AnyObject {
    func displayLoad(viewModel: AssignedHomeworkModels.Load.ViewModel) async
    func displayCreate(viewModel: AssignedHomeworkModels.Create.ViewModel) async
    func displayUpdateStatus(viewModel: AssignedHomeworkModels.UpdateStatus.ViewModel) async
    func displayFamilyLoad(viewModel: AssignedHomeworkModels.FamilyLoad.ViewModel) async
}
