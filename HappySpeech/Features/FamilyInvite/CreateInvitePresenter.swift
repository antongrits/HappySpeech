import Foundation
import OSLog

// MARK: - CreateInvitePresenter

@MainActor
final class CreateInvitePresenter {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "CreateInvitePresenter")
    weak var viewModel: CreateInviteViewModel?

    func presentLoading() {
        viewModel?.isCreating = true
        viewModel?.errorMessage = nil
    }

    func presentCreated(_ response: FamilyInvite.Create.Response) {
        guard let viewModel else { return }
        viewModel.isCreating = false
        viewModel.shortCode = response.shortCode
        viewModel.expiresAt = response.expiresAt
        viewModel.shareURL = response.shareURL
        viewModel.issuedRole = response.role
        viewModel.errorMessage = nil
        logger.info("CreateInvitePresenter: presented code for role=\(response.role.rawValue, privacy: .public)")
    }

    func presentError(_ error: Error) {
        guard let viewModel else { return }
        viewModel.isCreating = false
        viewModel.errorMessage = userFacingMessage(for: error)
        logger.error("CreateInvitePresenter: error \(error.localizedDescription, privacy: .public)")
    }

    // MARK: - Private

    /// Преобразует ошибку в дружелюбное русское сообщение без debug-деталей.
    private func userFacingMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return String(localized: "familyInvite.create.error.generic")
    }
}
