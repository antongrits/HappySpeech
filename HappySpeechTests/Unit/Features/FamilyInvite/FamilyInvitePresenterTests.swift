@testable import HappySpeech
import XCTest

// MARK: - FamilyInvitePresenterTests
//
// Прямые тесты Presenter'ов: маппинг response → ViewModel, и преобразование
// каждой FamilyInviteError в дружелюбное русское сообщение.

@MainActor
final class FamilyInvitePresenterTests: XCTestCase {

    // MARK: - Create

    func test_createPresenter_loadingThenCreated() {
        let viewModel = CreateInviteViewModel()
        let presenter = CreateInvitePresenter()
        presenter.viewModel = viewModel

        presenter.presentLoading()
        XCTAssertTrue(viewModel.isCreating)

        let expiry = Date().addingTimeInterval(72 * 3600)
        // swiftlint:disable:next force_unwrapping
        let url = URL(string: "https://happyspeech.app/invite?code=ABCDEF")!
        presenter.presentCreated(.init(shortCode: "ABCDEF", expiresAt: expiry, shareURL: url, role: .secondary))

        XCTAssertFalse(viewModel.isCreating)
        XCTAssertEqual(viewModel.shortCode, "ABCDEF")
        XCTAssertEqual(viewModel.issuedRole, .secondary)
        XCTAssertFalse(viewModel.expiryText.isEmpty)
    }

    func test_createPresenter_errorUsesLocalizedDescription() {
        let viewModel = CreateInviteViewModel()
        let presenter = CreateInvitePresenter()
        presenter.viewModel = viewModel

        presenter.presentError(FamilyInviteError.lookupFailed("offline"))

        XCTAssertFalse(viewModel.isCreating)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - Redeem

    func test_redeemPresenter_success() {
        let viewModel = RedeemInviteViewModel()
        let presenter = RedeemInvitePresenter()
        presenter.viewModel = viewModel

        presenter.presentSuccess(.init(role: .observer, inviterParentId: "p1"))

        XCTAssertEqual(viewModel.redeemedRole, .observer)
        XCTAssertTrue(viewModel.didSucceed)
        XCTAssertTrue(viewModel.successText.contains(FamilyInvite.localizedRoleName(.observer)))
    }

    func test_redeemPresenter_notAuthenticated() {
        let viewModel = RedeemInviteViewModel()
        let presenter = RedeemInvitePresenter()
        presenter.viewModel = viewModel

        presenter.presentNotAuthenticated()

        XCTAssertTrue(viewModel.requiresSignIn)
        XCTAssertEqual(
            viewModel.errorMessage,
            String(localized: "familyInvite.redeem.error.notAuthenticated")
        )
    }

    func test_redeemPresenter_mapsEachErrorToFriendlyMessage() {
        let cases: [(FamilyInviteError, String)] = [
            (.notFound, "familyInvite.redeem.error.notFound"),
            (.alreadyConsumed, "familyInvite.redeem.error.consumed"),
            (.expired, "familyInvite.redeem.error.expired"),
            (.invalidShortCode, "familyInvite.redeem.error.invalidCode"),
            (.selfRedemption, "familyInvite.redeem.error.selfRedemption"),
            (.missingToken, "familyInvite.redeem.error.generic")
        ]

        for (error, expectedKey) in cases {
            let viewModel = RedeemInviteViewModel()
            let presenter = RedeemInvitePresenter()
            presenter.viewModel = viewModel
            presenter.presentError(error)
            XCTAssertEqual(
                viewModel.errorMessage,
                String(localized: String.LocalizationValue(expectedKey)),
                "Unexpected message for \(error)"
            )
        }
    }

    // MARK: - ViewModel input normalization

    func test_redeemViewModel_clampsAndUppercasesCode() {
        let viewModel = RedeemInviteViewModel()
        viewModel.enteredCode = "k7m2x9zzzz"
        XCTAssertEqual(viewModel.enteredCode, "K7M2X9")
        XCTAssertTrue(viewModel.isCodeComplete)
    }

    func test_redeemViewModel_filtersNonAlphanumerics() {
        let viewModel = RedeemInviteViewModel()
        viewModel.enteredCode = "k7-m2 x"
        XCTAssertEqual(viewModel.enteredCode, "K7M2X")
        XCTAssertFalse(viewModel.isCodeComplete)
    }
}
