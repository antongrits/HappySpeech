@testable import HappySpeech
import XCTest

// MARK: - In-memory membership store spy

private final class SpyMembershipStore: FamilyMembershipStoring, @unchecked Sendable {
    var saved: [FamilyMembershipRecord] = []
    func save(_ record: FamilyMembershipRecord) { saved.append(record) }
    func all() -> [FamilyMembershipRecord] { saved }
}

// MARK: - RedeemInviteInteractorTests
//
// Покрывает применение кода: success (+ запись членства), не-аутентифицирован,
// невалидная длина, и каждую дружелюбную ошибку (consumed / expired / notFound).

@MainActor
final class RedeemInviteInteractorTests: XCTestCase {

    private func makeSUT(
        service: MockFamilyInviteService = MockFamilyInviteService(),
        user: AuthUser? = AuthUser(uid: "redeemer-uid")
    ) -> (RedeemInviteInteractor, RedeemInviteViewModel, SpyMembershipStore) {
        let viewModel = RedeemInviteViewModel()
        let presenter = RedeemInvitePresenter()
        presenter.viewModel = viewModel
        let store = SpyMembershipStore()
        let interactor = RedeemInviteInteractor(
            inviteService: service,
            authService: MockAuthService(initialUser: user),
            membershipStore: store
        )
        interactor.presenter = presenter
        return (interactor, viewModel, store)
    }

    // MARK: - Success

    func test_redeem_success_presentsRoleAndSavesMembership() async {
        let service = MockFamilyInviteService()
        service.stubbedRedemption = FamilyInviteRedemption(
            parentId: "inviter-uid",
            role: .secondary,
            consumedBy: "redeemer-uid",
            consumedAt: Date()
        )
        let (sut, viewModel, store) = makeSUT(service: service)

        await sut.redeem(.init(shortCode: "K7M2X9"))

        XCTAssertEqual(viewModel.redeemedRole, .secondary)
        XCTAssertTrue(viewModel.didSucceed)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isRedeeming)
        XCTAssertEqual(store.saved.count, 1)
        XCTAssertEqual(store.saved.first?.inviterParentId, "inviter-uid")
        XCTAssertEqual(store.saved.first?.role, ParentRole.secondary.rawValue)
        XCTAssertEqual(service.redeemCallsCount, 1)
    }

    func test_redeem_normalizesLowercaseCode() async {
        let (sut, viewModel, _) = makeSUT()

        await sut.redeem(.init(shortCode: "k7m2x9"))

        XCTAssertTrue(viewModel.didSucceed)
    }

    // MARK: - Not authenticated

    func test_redeem_notAuthenticated_showsSignInCTA() async {
        let (sut, viewModel, store) = makeSUT(user: nil)

        await sut.redeem(.init(shortCode: "K7M2X9"))

        XCTAssertTrue(viewModel.requiresSignIn)
        XCTAssertFalse(viewModel.didSucceed)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(store.saved.isEmpty)
    }

    func test_redeem_emptyUid_showsSignInCTA() async {
        let (sut, viewModel, _) = makeSUT(user: AuthUser(uid: ""))

        await sut.redeem(.init(shortCode: "K7M2X9"))

        XCTAssertTrue(viewModel.requiresSignIn)
        XCTAssertFalse(viewModel.didSucceed)
    }

    // MARK: - Invalid length

    func test_redeem_shortCode_presentsInvalidCodeError() async {
        let service = MockFamilyInviteService()
        let (sut, viewModel, store) = makeSUT(service: service)

        await sut.redeem(.init(shortCode: "AB1"))

        XCTAssertFalse(viewModel.didSucceed)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(service.redeemCallsCount, 0)
        XCTAssertTrue(store.saved.isEmpty)
    }

    // MARK: - Service errors → friendly messages

    func test_redeem_notFound_presentsFriendlyError() async {
        let service = MockFamilyInviteService()
        service.shouldThrowError = .notFound
        let (sut, viewModel, store) = makeSUT(service: service)

        await sut.redeem(.init(shortCode: "K7M2X9"))

        XCTAssertFalse(viewModel.didSucceed)
        XCTAssertEqual(viewModel.errorMessage, String(localized: "familyInvite.redeem.error.notFound"))
        XCTAssertTrue(store.saved.isEmpty)
    }

    func test_redeem_alreadyConsumed_presentsFriendlyError() async {
        let service = MockFamilyInviteService()
        service.shouldThrowError = .alreadyConsumed
        let (sut, viewModel, _) = makeSUT(service: service)

        await sut.redeem(.init(shortCode: "K7M2X9"))

        XCTAssertEqual(viewModel.errorMessage, String(localized: "familyInvite.redeem.error.consumed"))
    }

    func test_redeem_expired_presentsFriendlyError() async {
        let service = MockFamilyInviteService()
        service.shouldThrowError = .expired
        let (sut, viewModel, _) = makeSUT(service: service)

        await sut.redeem(.init(shortCode: "K7M2X9"))

        XCTAssertEqual(viewModel.errorMessage, String(localized: "familyInvite.redeem.error.expired"))
    }

    func test_redeem_selfRedemption_presentsFriendlyError() async {
        let service = MockFamilyInviteService()
        service.shouldThrowError = .selfRedemption
        let (sut, viewModel, _) = makeSUT(service: service)

        await sut.redeem(.init(shortCode: "K7M2X9"))

        XCTAssertEqual(viewModel.errorMessage, String(localized: "familyInvite.redeem.error.selfRedemption"))
    }
}
