import Foundation
import OSLog

// MARK: - ComparisonDashboardPresenter

@MainActor
final class ComparisonDashboardPresenter {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "ComparisonDashboardPresenter")
    weak var viewModel: ComparisonDashboardViewModel?

    func presentLoading() {
        viewModel?.isLoading = true
        viewModel?.errorMessage = nil
    }

    func presentLoaded(_ response: ComparisonDashboard.LoadResponse) {
        guard let vm = viewModel else { return }
        vm.children = response.children
        vm.isLoading = false
        vm.errorMessage = nil
        logger.debug("ComparisonDashboardPresenter: loaded \(response.children.count) children")
    }

    func presentError(_ error: Error) {
        viewModel?.isLoading = false
        viewModel?.errorMessage = error.localizedDescription
        logger.error("ComparisonDashboardPresenter: error \(error.localizedDescription)")
    }
}
