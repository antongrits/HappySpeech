import Foundation

// MARK: - SpecialistDisplayLogic

@MainActor
protocol SpecialistDisplayLogic: AnyObject {
    func displayFetch(_ viewModel: SpecialistModels.Fetch.ViewModel)
    func displayUpdate(_ viewModel: SpecialistModels.Update.ViewModel)
}
