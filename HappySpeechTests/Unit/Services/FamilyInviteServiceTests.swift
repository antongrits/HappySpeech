@testable import HappySpeech
import XCTest

// MARK: - FamilyInviteServiceTests
//
// 2.10 v25 — покрытие FamilyInviteService.
// LiveFamilyInviteService.init создаёт Firestore.firestore() и читает Auth.auth() —
// требует FirebaseApp.configure(), поэтому не инстанцируется в unit-окружении.
// Покрываем контракт протокола через MockFamilyInviteService + чистые модели/ошибки.
// Прямые Firestore-транзакции (runTransaction / getDocuments) документированы
// для ADR-V25-COVERAGE как genuinely SDK-bound.

final class FamilyInviteServiceTests: XCTestCase {

    private func makeSUT() -> MockFamilyInviteService {
        MockFamilyInviteService()
    }

    // MARK: - FamilyInviteParams

    func test_inviteParams_storesTokenAndShortCode() {
        let params = FamilyInviteParams(token: "hex-token", shortCode: "K7M2X9")
        XCTAssertEqual(params.token, "hex-token")
        XCTAssertEqual(params.shortCode, "K7M2X9")
    }

    func test_inviteParams_shortCodeDefaultsToNil() {
        let params = FamilyInviteParams(token: "hex-token")
        XCTAssertNil(params.shortCode)
    }

    func test_inviteParams_equatable() {
        let a = FamilyInviteParams(token: "t", shortCode: "C")
        let b = FamilyInviteParams(token: "t", shortCode: "C")
        XCTAssertEqual(a, b)
    }

    // MARK: - FamilyInviteStatus

    func test_inviteStatus_activeCarriesPayload() {
        let expires = Date().addingTimeInterval(3600)
        let status = FamilyInviteStatus.active(parentId: "p-1", role: .secondary, expiresAt: expires)
        if case let .active(parentId, role, expiresAt) = status {
            XCTAssertEqual(parentId, "p-1")
            XCTAssertEqual(role, .secondary)
            XCTAssertEqual(expiresAt, expires)
        } else {
            XCTFail("Ожидался .active")
        }
    }

    func test_inviteStatus_equatable() {
        XCTAssertEqual(FamilyInviteStatus.notFound, FamilyInviteStatus.notFound)
        let consumedAt = Date()
        XCTAssertEqual(
            FamilyInviteStatus.consumed(consumedAt: consumedAt),
            FamilyInviteStatus.consumed(consumedAt: consumedAt)
        )
        XCTAssertNotEqual(FamilyInviteStatus.notFound, FamilyInviteStatus.expired(expiredAt: Date()))
    }

    // MARK: - FamilyInviteRedemption

    func test_redemption_storesAllFields() {
        let consumedAt = Date()
        let redemption = FamilyInviteRedemption(
            parentId: "p-1", role: .observer, consumedBy: "u-2", consumedAt: consumedAt
        )
        XCTAssertEqual(redemption.parentId, "p-1")
        XCTAssertEqual(redemption.role, .observer)
        XCTAssertEqual(redemption.consumedBy, "u-2")
        XCTAssertEqual(redemption.consumedAt, consumedAt)
    }

    // MARK: - FamilyInviteError — localized descriptions

    func test_error_descriptions_areRussianAndNonEmpty() {
        let errors: [FamilyInviteError] = [
            .invalidURL, .missingToken, .invalidShortCode,
            .lookupFailed("деталь"), .alreadyConsumed, .expired, .notFound, .selfRedemption
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }

    func test_error_invalidShortCode_mentionsSixCharacters() {
        let description = FamilyInviteError.invalidShortCode.errorDescription ?? ""
        XCTAssertTrue(description.contains("6"), "Сообщение должно упоминать длину кода")
    }

    func test_error_lookupFailed_includesDetail() {
        let description = FamilyInviteError.lookupFailed("сетевой сбой").errorDescription ?? ""
        XCTAssertTrue(description.contains("сетевой сбой"))
    }

    // MARK: - createInvite (mock contract)

    func test_createInvite_returnsTokenAndIncrementsCounter() async throws {
        let sut = makeSUT()
        XCTAssertEqual(sut.createdInvitesCount, 0)
        let token = try await sut.createInvite(role: .secondary, durationHours: 24)
        XCTAssertFalse(token.shortCode.isEmpty)
        XCTAssertEqual(sut.createdInvitesCount, 1)
    }

    func test_createInvite_whenErrorSet_throws() async {
        let sut = makeSUT()
        sut.shouldThrowError = .alreadyConsumed
        do {
            _ = try await sut.createInvite(role: .observer, durationHours: 12)
            XCTFail("Должна быть выброшена ошибка")
        } catch let error as FamilyInviteError {
            guard case .alreadyConsumed = error else {
                return XCTFail("Ожидалась alreadyConsumed, получено \(error)")
            }
        } catch {
            XCTFail("Неверный тип ошибки: \(error)")
        }
    }

    // MARK: - parseInviteURL (mock contract)

    func test_parseInviteURL_validURLWithToken_returnsParams() throws {
        let sut = makeSUT()
        let url = try XCTUnwrap(URL(string: "https://happyspeech.mmf.bsu.app/invite?token=abc123"))
        let params = try sut.parseInviteURL(url)
        XCTAssertFalse(params.token.isEmpty)
    }

    func test_parseInviteURL_urlWithoutToken_throwsMissingToken() throws {
        let sut = makeSUT()
        let url = try XCTUnwrap(URL(string: "https://happyspeech.mmf.bsu.app/invite"))
        XCTAssertThrowsError(try sut.parseInviteURL(url)) { error in
            guard case FamilyInviteError.missingToken = error else {
                return XCTFail("Ожидалась missingToken, получено \(error)")
            }
        }
    }

    // MARK: - redeemInvite byToken

    func test_redeemInvite_byToken_returnsRedemptionAndIncrements() async throws {
        let sut = makeSUT()
        XCTAssertEqual(sut.redeemCallsCount, 0)
        let redemption = try await sut.redeemInvite(byToken: "token-1", redeemerUid: "u-2")
        XCTAssertEqual(redemption.role, .secondary)
        XCTAssertEqual(sut.redeemCallsCount, 1)
    }

    func test_redeemInvite_byToken_whenErrorSet_throwsExpired() async {
        let sut = makeSUT()
        sut.shouldThrowError = .expired
        do {
            _ = try await sut.redeemInvite(byToken: "token-1", redeemerUid: "u-2")
            XCTFail("Должна быть выброшена ошибка")
        } catch let error as FamilyInviteError {
            guard case .expired = error else {
                return XCTFail("Ожидалась expired, получено \(error)")
            }
        } catch {
            XCTFail("Неверный тип ошибки: \(error)")
        }
    }

    // MARK: - redeemInvite byShortCode

    func test_redeemInvite_byShortCode_returnsRedemption() async throws {
        let sut = makeSUT()
        let redemption = try await sut.redeemInvite(byShortCode: "K7M2X9", redeemerUid: "u-2")
        XCTAssertEqual(redemption.consumedBy, "mock-redeemer-uid")
        XCTAssertEqual(sut.redeemCallsCount, 1)
    }

    func test_redeemInvite_byShortCode_whenSelfRedemption_throws() async {
        let sut = makeSUT()
        sut.shouldThrowError = .selfRedemption
        do {
            _ = try await sut.redeemInvite(byShortCode: "ABCD23", redeemerUid: "u-1")
            XCTFail("Должна быть выброшена ошибка")
        } catch let error as FamilyInviteError {
            guard case .selfRedemption = error else {
                return XCTFail("Ожидалась selfRedemption, получено \(error)")
            }
        } catch {
            XCTFail("Неверный тип ошибки: \(error)")
        }
    }
}
