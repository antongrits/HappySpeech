@testable import HappySpeech
import XCTest

// MARK: - DynamicLinksServiceTests
//
// 2.10 v25 — покрытие DynamicLinksService.
// LiveDynamicLinksService deprecated (Firebase Dynamic Links shutdown 25.08.2025,
// ADR-V18-U-DYNAMICLINKS-REPLACE) и его публичные методы вызывают SDK
// (DynamicLinkComponents.shorten / DynamicLinks.handleUniversalLink) — не тестируем
// напрямую, чтобы не тянуть deprecation-warning в test target.
// Покрываем контракт через MockDynamicLinksService + чистые модели/ошибки.

final class DynamicLinksServiceTests: XCTestCase {

    private func makeSUT() -> MockDynamicLinksService {
        MockDynamicLinksService()
    }

    // MARK: - ParentRole

    func test_parentRole_allCases_containsThreeRoles() {
        XCTAssertEqual(ParentRole.allCases.count, 3)
        XCTAssertTrue(ParentRole.allCases.contains(.primary))
        XCTAssertTrue(ParentRole.allCases.contains(.secondary))
        XCTAssertTrue(ParentRole.allCases.contains(.observer))
    }

    func test_parentRole_rawValueRoundTrip() {
        for role in ParentRole.allCases {
            XCTAssertEqual(ParentRole(rawValue: role.rawValue), role)
        }
    }

    func test_parentRole_invalidRawValue_returnsNil() {
        XCTAssertNil(ParentRole(rawValue: "administrator"))
    }

    // MARK: - DynamicLinkPayload

    func test_payload_storesAllFields() {
        let expires = Date().addingTimeInterval(86400)
        let payload = DynamicLinkPayload(
            linkType: "family_invite",
            familyId: "fam-1",
            role: .secondary,
            inviterUid: "uid-1",
            expiresAt: expires,
            extraParams: ["custom": "value"]
        )
        XCTAssertEqual(payload.linkType, "family_invite")
        XCTAssertEqual(payload.familyId, "fam-1")
        XCTAssertEqual(payload.role, .secondary)
        XCTAssertEqual(payload.inviterUid, "uid-1")
        XCTAssertEqual(payload.expiresAt, expires)
        XCTAssertEqual(payload.extraParams["custom"], "value")
    }

    func test_payload_defaults_areNilAndEmpty() {
        let payload = DynamicLinkPayload(linkType: "content_share")
        XCTAssertNil(payload.familyId)
        XCTAssertNil(payload.role)
        XCTAssertNil(payload.inviterUid)
        XCTAssertNil(payload.expiresAt)
        XCTAssertTrue(payload.extraParams.isEmpty)
    }

    func test_payload_equatable() {
        let a = DynamicLinkPayload(linkType: "family_invite", familyId: "f")
        let b = DynamicLinkPayload(linkType: "family_invite", familyId: "f")
        XCTAssertEqual(a, b)
        let c = DynamicLinkPayload(linkType: "specialist_access", familyId: "f")
        XCTAssertNotEqual(a, c)
    }

    // MARK: - DynamicLinksError — localized descriptions

    func test_error_descriptions_areRussianAndNonEmpty() {
        let errors: [DynamicLinksError] = [
            .invalidConfiguration,
            .linkCreationFailed("деталь"),
            .linkResolutionFailed("деталь"),
            .expiredLink,
            .invalidPayload("деталь")
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }

    func test_error_linkCreationFailed_includesDetail() {
        let description = DynamicLinksError.linkCreationFailed("DNS сбой").errorDescription ?? ""
        XCTAssertTrue(description.contains("DNS сбой"))
    }

    func test_error_invalidPayload_includesDetail() {
        let description = DynamicLinksError.invalidPayload("нет type").errorDescription ?? ""
        XCTAssertTrue(description.contains("нет type"))
    }

    // MARK: - createFamilyInviteLink (mock contract)

    func test_createFamilyInviteLink_returnsURLAndIncrementsCounter() async throws {
        let sut = makeSUT()
        XCTAssertEqual(sut.createdLinkCount, 0)
        let url = try await sut.createFamilyInviteLink(familyId: "fam-1", role: .secondary)
        XCTAssertFalse(url.absoluteString.isEmpty)
        XCTAssertEqual(sut.createdLinkCount, 1)
    }

    func test_createFamilyInviteLink_whenShouldThrow_throws() async {
        let sut = makeSUT()
        sut.shouldThrowError = true
        do {
            _ = try await sut.createFamilyInviteLink(familyId: "fam-1", role: .observer)
            XCTFail("Должна быть выброшена ошибка")
        } catch {
            XCTAssertTrue(error is DynamicLinksError)
        }
    }

    // MARK: - handleIncomingLink (mock contract)

    func test_handleIncomingLink_returnsStubbedPayload() async throws {
        let sut = makeSUT()
        let url = try XCTUnwrap(URL(string: "https://happyspeech.page.link/test"))
        let payload = try await sut.handleIncomingLink(url)
        XCTAssertEqual(payload.linkType, "family_invite")
        XCTAssertEqual(payload.role, .secondary)
    }

    func test_handleIncomingLink_whenShouldThrow_throwsResolutionFailed() async throws {
        let sut = makeSUT()
        sut.shouldThrowError = true
        let url = try XCTUnwrap(URL(string: "https://happyspeech.page.link/test"))
        do {
            _ = try await sut.handleIncomingLink(url)
            XCTFail("Должна быть выброшена ошибка")
        } catch let error as DynamicLinksError {
            if case .linkResolutionFailed = error { } else {
                XCTFail("Ожидалась linkResolutionFailed, получено \(error)")
            }
        } catch {
            XCTFail("Неверный тип ошибки: \(error)")
        }
    }

    // MARK: - createSpecialistAccessLink (mock contract)

    func test_createSpecialistAccessLink_returnsURL() async throws {
        let sut = makeSUT()
        let url = try await sut.createSpecialistAccessLink(
            childId: "child-1", specialistEmail: "logoped@example.com", durationDays: 30
        )
        XCTAssertFalse(url.absoluteString.isEmpty)
        XCTAssertEqual(sut.createdLinkCount, 1)
    }

    func test_createSpecialistAccessLink_whenShouldThrow_throws() async {
        let sut = makeSUT()
        sut.shouldThrowError = true
        do {
            _ = try await sut.createSpecialistAccessLink(
                childId: "child-1", specialistEmail: "logoped@example.com", durationDays: 30
            )
            XCTFail("Должна быть выброшена ошибка")
        } catch {
            XCTAssertTrue(error is DynamicLinksError)
        }
    }
}
