import Foundation

// MARK: - HomeTasksPresentationLogic

@MainActor
protocol HomeTasksPresentationLogic: AnyObject {
    func presentFetch(_ response: HomeTasksModels.Fetch.Response)
    func presentUpdate(_ response: HomeTasksModels.Update.Response)
}

// MARK: - HomeTasksPresenter

@MainActor
final class HomeTasksPresenter: HomeTasksPresentationLogic {

    weak var viewModel: (any HomeTasksDisplayLogic)?

    func presentFetch(_ response: HomeTasksModels.Fetch.Response) {
        let vm = HomeTasksModels.Fetch.ViewModel()
        viewModel?.displayFetch(vm)
    }

    func presentUpdate(_ response: HomeTasksModels.Update.Response) {
        let vm = HomeTasksModels.Update.ViewModel()
        viewModel?.displayUpdate(vm)
    }
}
