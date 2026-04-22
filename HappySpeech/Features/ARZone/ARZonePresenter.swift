import Foundation

// MARK: - ARZonePresentationLogic

@MainActor
protocol ARZonePresentationLogic: AnyObject {
    func presentFetch(_ response: ARZoneModels.Fetch.Response)
    func presentUpdate(_ response: ARZoneModels.Update.Response)
}

// MARK: - ARZonePresenter

@MainActor
final class ARZonePresenter: ARZonePresentationLogic {

    weak var viewModel: (any ARZoneDisplayLogic)?

    func presentFetch(_ response: ARZoneModels.Fetch.Response) {
        let vm = ARZoneModels.Fetch.ViewModel()
        viewModel?.displayFetch(vm)
    }

    func presentUpdate(_ response: ARZoneModels.Update.Response) {
        let vm = ARZoneModels.Update.ViewModel()
        viewModel?.displayUpdate(vm)
    }
}
