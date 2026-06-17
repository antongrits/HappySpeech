@testable import HappySpeech
import XCTest

// MARK: - CloudFunctionsServiceTests
//
// 2.10 v25 — покрытие CloudFunctionsService.
// LiveCloudFunctionsService SDK-bound (Functions.functions / App Check / httpsCallable.call) —
// тестируется через MockCloudFunctionsService (контракт протокола) + чистые модели/ошибки.
//
// v28 (ADR-V28-CLEANUP-CLOUD-STUBS): 5 серверных stub-функций удалены, скоринг —
// только on-device. В сервисе остался единственный метод createFamilyInviteToken.

final class CloudFunctionsServiceTests: XCTestCase {

    private func makeSUT() -> MockCloudFunctionsService {
        MockCloudFunctionsService()
    }

    // MARK: - Result models — value semantics

    func test_familyInviteToken_storesShortCodeAndURL() throws {
        let url = try XCTUnwrap(URL(string: "https://happyspeech.app/invite?token=abc"))
        let token = FamilyInviteToken(
            token: "abc", shortCode: "K7M2X9", expiresAt: Date(), deepLinkURL: url
        )
        XCTAssertEqual(token.shortCode, "K7M2X9")
        XCTAssertEqual(token.deepLinkURL, url)
    }

    // MARK: - CloudFunctionsError — localized descriptions

    func test_error_descriptions_areRussianAndNonEmpty() {
        let errors: [CloudFunctionsError] = [
            .appCheckFailed,
            .invalidResponse("деталь"),
            .serverError("сбой"),
            .networkUnavailable
        ]
        for error in errors {
            let description = error.errorDescription
            XCTAssertNotNil(description)
            XCTAssertFalse(description?.isEmpty ?? true, "Описание ошибки не должно быть пустым")
        }
    }

    func test_error_invalidResponse_includesDetail() {
        let error = CloudFunctionsError.invalidResponse("отсутствует поле")
        XCTAssertTrue(error.errorDescription?.contains("отсутствует поле") ?? false)
    }

    // MARK: - createFamilyInviteToken

    func test_createFamilyInviteToken_returnsToken() async throws {
        let sut = makeSUT()
        let token = try await sut.createFamilyInviteToken(
            parentId: "parent-1", role: .secondary, durationHours: 24
        )
        XCTAssertFalse(token.shortCode.isEmpty)
        XCTAssertGreaterThan(token.expiresAt, Date())
    }

    func test_createFamilyInviteToken_whenShouldThrow_throwsServerError() async {
        let sut = makeSUT()
        sut.shouldThrowError = true
        do {
            _ = try await sut.createFamilyInviteToken(
                parentId: "parent-1", role: .observer, durationHours: 12
            )
            XCTFail("Должна быть выброшена ошибка")
        } catch let error as CloudFunctionsError {
            if case .serverError = error { } else {
                XCTFail("Ожидалась serverError, получено \(error)")
            }
        } catch {
            XCTFail("Неверный тип ошибки: \(error)")
        }
    }

    // MARK: - deleteUserData (COPPA / GDPR cascade)

    func test_deleteUserData_recordsRequestedUserId() async throws {
        let sut = makeSUT()
        try await sut.deleteUserData(userId: "uid-42")
        XCTAssertEqual(sut.deletedUserIds, ["uid-42"], "Каскад должен зафиксировать удаляемый uid")
    }

    func test_deleteUserData_whenShouldThrow_propagatesError() async {
        let sut = makeSUT()
        sut.shouldThrowError = true
        do {
            try await sut.deleteUserData(userId: "uid-42")
            XCTFail("Должна быть выброшена ошибка каскада")
        } catch let error as CloudFunctionsError {
            if case .serverError = error { } else {
                XCTFail("Ожидалась serverError, получено \(error)")
            }
        } catch {
            XCTFail("Неверный тип ошибки: \(error)")
        }
        XCTAssertTrue(sut.deletedUserIds.isEmpty, "При ошибке uid не должен записываться")
    }
}
