import Foundation

// MARK: - DemoPresentationLogic

@MainActor
protocol DemoPresentationLogic: AnyObject {
    func presentFetch(_ response: DemoModels.Fetch.Response)
    func presentUpdate(_ response: DemoModels.Update.Response)
}

// MARK: - DemoPresenter

@MainActor
final class DemoPresenter: DemoPresentationLogic {

    weak var viewModel: (any DemoDisplayLogic)?

    func presentFetch(_ response: DemoModels.Fetch.Response) {
        let vm = DemoModels.Fetch.ViewModel()
        viewModel?.displayFetch(vm)
    }

    func presentUpdate(_ response: DemoModels.Update.Response) {
        let vm = DemoModels.Update.ViewModel()
        viewModel?.displayUpdate(vm)
    }
}
