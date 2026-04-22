import Foundation

// MARK: - SpecialistPresentationLogic

@MainActor
protocol SpecialistPresentationLogic: AnyObject {
    func presentFetch(_ response: SpecialistModels.Fetch.Response)
    func presentUpdate(_ response: SpecialistModels.Update.Response)
}

// MARK: - SpecialistPresenter

@MainActor
final class SpecialistPresenter: SpecialistPresentationLogic {

    weak var viewModel: (any SpecialistDisplayLogic)?

    func presentFetch(_ response: SpecialistModels.Fetch.Response) {
        let vm = SpecialistModels.Fetch.ViewModel()
        viewModel?.displayFetch(vm)
    }

    func presentUpdate(_ response: SpecialistModels.Update.Response) {
        let vm = SpecialistModels.Update.ViewModel()
        viewModel?.displayUpdate(vm)
    }
}
