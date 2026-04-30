import Foundation
import OSLog

// MARK: - ProfileEditorPresenter

@MainActor
final class ProfileEditorPresenter {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "ProfileEditorPresenter")
    weak var viewModel: ProfileEditorViewModel?

    func presentLoaded(_ response: ProfileEditor.LoadResponse) {
        guard let vm = viewModel else { return }
        vm.childId = response.childId
        vm.name = response.name
        vm.age = response.age
        vm.selectedAvatarId = response.avatarStyle
        vm.selectedThemeId = response.colorTheme
        vm.targetSounds = response.targetSounds
        vm.isLoading = false
        vm.errorMessage = nil
        logger.debug("ProfileEditorPresenter: loaded child \(response.childId, privacy: .private)")
    }

    func presentLoading() {
        viewModel?.isLoading = true
        viewModel?.errorMessage = nil
    }

    func presentSaving() {
        viewModel?.isSaving = true
        viewModel?.errorMessage = nil
    }

    func presentSaved(_ response: ProfileEditor.SaveResponse) {
        guard let vm = viewModel else { return }
        vm.isSaving = false
        if response.success {
            vm.isSaved = true
            vm.errorMessage = nil
            logger.debug("ProfileEditorPresenter: saved successfully")
        } else {
            vm.errorMessage = response.errorMessage ?? String(localized: "error.generic")
            logger.error("ProfileEditorPresenter: save failed \(response.errorMessage ?? "unknown")")
        }
    }

    func presentError(_ error: Error) {
        viewModel?.isLoading = false
        viewModel?.isSaving = false
        viewModel?.errorMessage = error.localizedDescription
        logger.error("ProfileEditorPresenter: error \(error.localizedDescription)")
    }
}
