import Foundation
import OSLog

// MARK: - FamilyHomePresenter

@MainActor
final class FamilyHomePresenter {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "FamilyHomePresenter")
    weak var viewModel: FamilyHomeViewModel?

    func presentLoad(_ response: FamilyHome.LoadResponse) {
        guard let vm = viewModel else { return }
        vm.children = response.children
        vm.parentName = response.parentName
        vm.isLoading = false
        vm.errorMessage = nil
        logger.debug("FamilyHomePresenter: presented \(response.children.count) children")
    }

    func presentLoading() {
        viewModel?.isLoading = true
        viewModel?.errorMessage = nil
    }

    func presentError(_ error: Error) {
        viewModel?.isLoading = false
        viewModel?.errorMessage = error.localizedDescription
        logger.error("FamilyHomePresenter: error \(error.localizedDescription)")
    }
}
