import Foundation
import OSLog

// MARK: - RedeemInvitePresenter

@MainActor
final class RedeemInvitePresenter {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "RedeemInvitePresenter")
    weak var viewModel: RedeemInviteViewModel?

    func presentLoading() {
        viewModel?.isRedeeming = true
        viewModel?.errorMessage = nil
        viewModel?.requiresSignIn = false
    }

    func presentNotAuthenticated() {
        guard let viewModel else { return }
        viewModel.isRedeeming = false
        viewModel.requiresSignIn = true
        viewModel.errorMessage = String(localized: "familyInvite.redeem.error.notAuthenticated")
        logger.info("RedeemInvitePresenter: redeem blocked — not authenticated")
    }

    func presentSuccess(_ response: FamilyInvite.Redeem.Response) {
        guard let viewModel else { return }
        viewModel.isRedeeming = false
        viewModel.redeemedRole = response.role
        viewModel.errorMessage = nil
        viewModel.requiresSignIn = false
        logger.info("RedeemInvitePresenter: joined family role=\(response.role.rawValue, privacy: .public)")
    }

    func presentError(_ error: Error) {
        guard let viewModel else { return }
        viewModel.isRedeeming = false
        viewModel.errorMessage = userFacingMessage(for: error)
        logger.error("RedeemInvitePresenter: error \(error.localizedDescription, privacy: .public)")
    }

    // MARK: - Private

    /// Дружелюбные русские сообщения для каждого исхода применения кода.
    private func userFacingMessage(for error: Error) -> String {
        if let inviteError = error as? FamilyInviteError {
            switch inviteError {
            case .notFound:
                return String(localized: "familyInvite.redeem.error.notFound")
            case .alreadyConsumed:
                return String(localized: "familyInvite.redeem.error.consumed")
            case .expired:
                return String(localized: "familyInvite.redeem.error.expired")
            case .invalidShortCode:
                return String(localized: "familyInvite.redeem.error.invalidCode")
            case .selfRedemption:
                return String(localized: "familyInvite.redeem.error.selfRedemption")
            case .invalidURL, .missingToken, .lookupFailed:
                return String(localized: "familyInvite.redeem.error.generic")
            }
        }
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return String(localized: "familyInvite.redeem.error.generic")
    }
}
