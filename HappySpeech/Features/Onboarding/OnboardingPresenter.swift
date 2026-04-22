import Foundation

// MARK: - OnboardingPresentationLogic

@MainActor
protocol OnboardingPresentationLogic: AnyObject {
    func presentFetch(_ response: OnboardingModels.Fetch.Response)
    func presentUpdate(_ response: OnboardingModels.Update.Response)
}

// MARK: - OnboardingPresenter

@MainActor
final class OnboardingPresenter: OnboardingPresentationLogic {

    weak var viewModel: (any OnboardingDisplayLogic)?

    func presentFetch(_ response: OnboardingModels.Fetch.Response) {
        let vm = OnboardingModels.Fetch.ViewModel()
        viewModel?.displayFetch(vm)
    }

    func presentUpdate(_ response: OnboardingModels.Update.Response) {
        let vm = OnboardingModels.Update.ViewModel()
        viewModel?.displayUpdate(vm)
    }
}
