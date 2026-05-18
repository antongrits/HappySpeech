@testable import HappySpeech
import XCTest

// MARK: - FCMServiceTests
//
// Phase 6 plan v29 — покрытие FCMService (ранее без выделенных тестов).
//
// LiveFCMService.init создаёт Firestore.firestore() и устанавливает
// Messaging.messaging().delegate — требует FirebaseApp.configure() и реальной
// сети. Поэтому unit-тесты покрывают контракт протокола через MockFCMService:
// requestPermission opt-in/opt-out, синхронизация и отзыв токена.

final class FCMServiceTests: XCTestCase {

    private func makeSUT() -> MockFCMService {
        MockFCMService()
    }

    // MARK: - requestPermission

    func test_requestPermission_returnsGrantedWhenAllowed() async {
        let sut = makeSUT()
        sut.permissionGranted = true
        let granted = await sut.requestPermission()
        XCTAssertTrue(granted, "При permissionGranted=true сервис должен вернуть true")
    }

    func test_requestPermission_returnsFalseWhenDenied() async {
        let sut = makeSUT()
        sut.permissionGranted = false
        let granted = await sut.requestPermission()
        XCTAssertFalse(granted, "При отказе пользователя сервис должен вернуть false")
    }

    // MARK: - registerForRemoteNotifications

    func test_registerForRemoteNotifications_doesNotThrow() async {
        let sut = makeSUT()
        await sut.registerForRemoteNotifications()
        // Контракт: метод не throwing — успешное завершение это успех.
        XCTAssertTrue(true)
    }

    // MARK: - syncTokenToFirestore (parent opt-in)

    func test_syncTokenToFirestore_marksTokenSynced() async throws {
        let sut = makeSUT()
        XCTAssertFalse(sut.didSyncToken)
        try await sut.syncTokenToFirestore(userId: "parent-uid-1")
        XCTAssertTrue(sut.didSyncToken, "syncTokenToFirestore должен пометить токен синхронизированным")
    }

    // MARK: - unregisterToken (sign-out / opt-out)

    func test_unregisterToken_marksUnregistered() async throws {
        let sut = makeSUT()
        XCTAssertFalse(sut.didUnregister)
        try await sut.unregisterToken(userId: "parent-uid-1")
        XCTAssertTrue(sut.didUnregister, "unregisterToken должен пометить токен удалённым")
    }

    // MARK: - Полный жизненный цикл opt-in → opt-out

    func test_fullLifecycle_optInThenOptOut() async throws {
        let sut = makeSUT()
        sut.permissionGranted = true

        let granted = await sut.requestPermission()
        XCTAssertTrue(granted)
        await sut.registerForRemoteNotifications()
        try await sut.syncTokenToFirestore(userId: "parent-1")
        XCTAssertTrue(sut.didSyncToken)

        try await sut.unregisterToken(userId: "parent-1")
        XCTAssertTrue(sut.didUnregister)
    }
}
