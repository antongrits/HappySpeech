@testable import HappySpeech
import XCTest

// MARK: - InstallationsServiceTests
//
// Phase 6 plan v29 — покрытие InstallationsService (ранее без выделенных тестов).
//
// LiveInstallationsService.init вызывает Installations.installations() — требует
// FirebaseApp.configure(). Unit-тесты покрывают контракт протокола через
// MockInstallationsService (success + error пути) и тип InstallationsError.

final class InstallationsServiceTests: XCTestCase {

    private func makeSUT() -> MockInstallationsService {
        MockInstallationsService()
    }

    // MARK: - currentInstallationID

    func test_currentInstallationID_returnsStubbedValue() async throws {
        let sut = makeSUT()
        sut.stubbedInstallationID = "fL4RhFMqNFmvnLH5Zi2KeO"
        let id = try await sut.currentInstallationID()
        XCTAssertEqual(id, "fL4RhFMqNFmvnLH5Zi2KeO")
    }

    func test_currentInstallationID_throwsWhenNotInitialized() async {
        let sut = makeSUT()
        sut.shouldThrowError = true
        do {
            _ = try await sut.currentInstallationID()
            XCTFail("Ожидалась ошибка при shouldThrowError=true")
        } catch let error as InstallationsError {
            guard case .notInitialized = error else {
                return XCTFail("Ожидалась .notInitialized, получено \(error)")
            }
        } catch {
            XCTFail("Ожидался InstallationsError, получено \(error)")
        }
    }

    // MARK: - authToken

    func test_authToken_returnsStubbedToken() async throws {
        let sut = makeSUT()
        sut.stubbedAuthToken = "jwt-token-xyz"
        let token = try await sut.authToken(forceRefresh: false)
        XCTAssertEqual(token, "jwt-token-xyz")
    }

    func test_authToken_forceRefreshReturnsToken() async throws {
        let sut = makeSUT()
        let token = try await sut.authToken(forceRefresh: true)
        XCTAssertFalse(token.isEmpty, "authToken должен вернуть непустой токен")
    }

    func test_authToken_throwsTokenUnavailableOnError() async {
        let sut = makeSUT()
        sut.shouldThrowError = true
        do {
            _ = try await sut.authToken(forceRefresh: false)
            XCTFail("Ожидалась ошибка")
        } catch let error as InstallationsError {
            guard case .tokenUnavailable = error else {
                return XCTFail("Ожидалась .tokenUnavailable, получено \(error)")
            }
        } catch {
            XCTFail("Ожидался InstallationsError")
        }
    }

    // MARK: - upgradeToAuthUser

    func test_upgradeToAuthUser_marksUpgraded() async throws {
        let sut = makeSUT()
        XCTAssertFalse(sut.didUpgrade)
        try await sut.upgradeToAuthUser(uid: "new-parent-uid")
        XCTAssertTrue(sut.didUpgrade, "upgradeToAuthUser должен пометить апгрейд выполненным")
    }

    func test_upgradeToAuthUser_throwsSyncFailedOnError() async {
        let sut = makeSUT()
        sut.shouldThrowError = true
        do {
            try await sut.upgradeToAuthUser(uid: "uid")
            XCTFail("Ожидалась ошибка")
        } catch let error as InstallationsError {
            guard case .syncFailed = error else {
                return XCTFail("Ожидалась .syncFailed, получено \(error)")
            }
        } catch {
            XCTFail("Ожидался InstallationsError")
        }
    }

    // MARK: - deleteInstallation

    func test_deleteInstallation_marksDeleted() async throws {
        let sut = makeSUT()
        XCTAssertFalse(sut.didDelete)
        try await sut.deleteInstallation()
        XCTAssertTrue(sut.didDelete, "deleteInstallation должен пометить установку удалённой")
    }

    func test_deleteInstallation_throwsOnError() async {
        let sut = makeSUT()
        sut.shouldThrowError = true
        do {
            try await sut.deleteInstallation()
            XCTFail("Ожидалась ошибка")
        } catch is InstallationsError {
            // ok
        } catch {
            XCTFail("Ожидался InstallationsError")
        }
    }

    // MARK: - InstallationsError descriptions

    func test_installationsError_hasRussianDescriptions() {
        XCTAssertEqual(
            InstallationsError.notInitialized.errorDescription,
            "Firebase не инициализирован. Убедитесь что FirebaseApp.configure() вызван."
        )
        XCTAssertEqual(
            InstallationsError.tokenUnavailable.errorDescription,
            "Токен установки недоступен."
        )
        XCTAssertEqual(
            InstallationsError.syncFailed("деталь").errorDescription,
            "Не удалось синхронизировать данные установки: деталь"
        )
    }
}
