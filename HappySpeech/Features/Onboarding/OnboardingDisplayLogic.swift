import Foundation

// MARK: - OnboardingDisplayLogic

@MainActor
protocol OnboardingDisplayLogic: AnyObject {
    func displayFetch(_ viewModel: OnboardingModels.Fetch.ViewModel)
    func displayUpdate(_ viewModel: OnboardingModels.Update.ViewModel)
}
