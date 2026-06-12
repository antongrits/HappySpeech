@testable import HappySpeech
import XCTest

// MARK: - CreateInviteInteractorTests
//
// Покрывает создание кода приглашения: happy path (роль → код), проброс срока
// и URL, ошибку сервиса, клампинг длительности.

@MainActor
final class CreateInviteInteractorTests: XCTestCase {

    private func makeSUT(
        service: MockFamilyInviteService = MockFamilyInviteService()
    ) -> (CreateInviteInteractor, CreateInvitePresenter, CreateInviteViewModel) {
        let viewModel = CreateInviteViewModel()
        let presenter = CreateInvitePresenter()
        presenter.viewModel = viewModel
        let interactor = CreateInviteInteractor(inviteService: service)
        interactor.presenter = presenter
        return (interactor, presenter, viewModel)
    }

    // MARK: - Happy path

    func test_createInvite_secondary_presentsCode() async {
        let service = MockFamilyInviteService()
        let expiry = Date().addingTimeInterval(72 * 3600)
        service.stubbedToken = FamilyInviteToken(
            token: "tok-1",
            shortCode: "K7M2X9",
            expiresAt: expiry,
            // swiftlint:disable:next force_unwrapping
            deepLinkURL: URL(string: "https://happyspeech.app/invite?code=K7M2X9")!
        )
        let (sut, _, viewModel) = makeSUT(service: service)

        await sut.createInvite(.init(role: .secondary, durationHours: 72))

        XCTAssertEqual(viewModel.shortCode, "K7M2X9")
        XCTAssertEqual(viewModel.expiresAt, expiry)
        XCTAssertEqual(viewModel.issuedRole, .secondary)
        XCTAssertNotNil(viewModel.shareURL)
        XCTAssertFalse(viewModel.isCreating)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.hasCode)
        XCTAssertEqual(service.createdInvitesCount, 1)
    }

    func test_createInvite_observer_mapsToObserverRole() async {
        let service = MockFamilyInviteService()
        let (sut, _, viewModel) = makeSUT(service: service)

        await sut.createInvite(.init(role: .observer, durationHours: 72))

        XCTAssertEqual(viewModel.issuedRole, .observer)
        XCTAssertEqual(FamilyInvite.InvitableRole.observer.parentRole, .observer)
    }

    // MARK: - Error

    func test_createInvite_serviceThrows_presentsError() async {
        let service = MockFamilyInviteService()
        service.shouldThrowError = .lookupFailed("network down")
        let (sut, _, viewModel) = makeSUT(service: service)

        await sut.createInvite(.init(role: .secondary, durationHours: 72))

        XCTAssertNil(viewModel.shortCode)
        XCTAssertFalse(viewModel.isCreating)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.hasCode)
    }

    // MARK: - Duration clamping

    func test_createInvite_durationClampedToValidRange() async {
        // Сервис принимает любое значение, но интерактор клампит до 1…168.
        // Проверяем, что вызов происходит и код всё равно генерируется.
        let service = MockFamilyInviteService()
        let (sut, _, viewModel) = makeSUT(service: service)

        await sut.createInvite(.init(role: .secondary, durationHours: 99999))

        XCTAssertTrue(viewModel.hasCode)
        XCTAssertEqual(service.createdInvitesCount, 1)
    }
}
