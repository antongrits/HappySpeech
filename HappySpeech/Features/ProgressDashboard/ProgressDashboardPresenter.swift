import Foundation

// MARK: - ProgressDashboardPresentationLogic

@MainActor
protocol ProgressDashboardPresentationLogic: AnyObject {
    func presentFetch(_ response: ProgressDashboardModels.Fetch.Response)
    func presentUpdate(_ response: ProgressDashboardModels.Update.Response)
}

// MARK: - ProgressDashboardPresenter

@MainActor
final class ProgressDashboardPresenter: ProgressDashboardPresentationLogic {

    weak var viewModel: (any ProgressDashboardDisplayLogic)?

    func presentFetch(_ response: ProgressDashboardModels.Fetch.Response) {
        let vm = ProgressDashboardModels.Fetch.ViewModel()
        viewModel?.displayFetch(vm)
    }

    func presentUpdate(_ response: ProgressDashboardModels.Update.Response) {
        let vm = ProgressDashboardModels.Update.ViewModel()
        viewModel?.displayUpdate(vm)
    }
}
