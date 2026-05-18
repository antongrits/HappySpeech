@testable import HappySpeech
import XCTest

// MARK: - LiveAuthServiceTests
//
// Phase 6 plan v29 — покрытие LiveAuthService (ранее без выделенных тестов).
//
// LiveAuthService — тонкий делегат FirebaseAuth SDK: каждый сетевой метод это
// `try await Auth.auth().<call>` + маппинг ошибки. Реальные сетевые вызовы
// требуют FirebaseApp.configure() + сети и поэтому НЕ покрываются unit-тестами
// (honest residual — см. AuthServiceContractTests).
//
// Здесь покрыто то, что детерминированно выполнимо в unit-окружении:
//  - LiveAuthService инстанцируется как AuthService без краша;
//  - currentUser возвращает nil при отсутствии аутентификации;
//  - add/removeAuthStateListener работают с непрозрачным handle без краша;
//  - контракт AuthUser-маппинга (значимый value type, который mapUser строит).

final class LiveAuthServiceTests: XCTestCase {

    // MARK: - Instantiation

    func test_liveAuthService_conformsToAuthService() {
        let sut: AuthService = LiveAuthService()
        XCTAssertNotNil(sut, "LiveAuthService должен инстанцироваться как AuthService")
    }

    func test_currentUser_isNilWithoutAuthentication() {
        let sut = LiveAuthService()
        // В unit-окружении без логина currentUser должен быть nil
        // (Auth.auth().currentUser == nil → mapUser(nil) == nil).
        XCTAssertNil(sut.currentUser, "Без аутентификации currentUser должен быть nil")
    }

    // MARK: - Auth state listener lifecycle

    func test_addAndRemoveAuthStateListener_doesNotCrash() {
        let sut = LiveAuthService()
        let handle = sut.addAuthStateListener { _ in }
        XCTAssertNotNil(handle, "addAuthStateListener должен вернуть непрозрачный handle")
        sut.removeAuthStateListener(handle)
        // removeAuthStateListener с невалидным handle — безопасный no-op.
        sut.removeAuthStateListener("not-a-real-handle")
    }

    // MARK: - signOut (locally safe — no network)

    func test_signOut_doesNotThrowWhenNoUser() {
        let sut = LiveAuthService()
        // signOut при отсутствии пользователя — Auth.auth().signOut() безопасен,
        // GIDSignIn.signOut() — локальный no-op. Не должен бросать.
        XCTAssertNoThrow(try sut.signOut())
    }

    // MARK: - AuthUser value type (что строит LiveAuthService.mapUser)

    func test_authUser_defaultInit() {
        let user = AuthUser(uid: "uid-1")
        XCTAssertEqual(user.uid, "uid-1")
        XCTAssertNil(user.email)
        XCTAssertFalse(user.isAnonymous)
        XCTAssertFalse(user.isEmailVerified)
    }

    func test_authUser_fullInitAndEquatable() {
        let a = AuthUser(
            uid: "u", email: "p@h.ru", displayName: "Родитель",
            isAnonymous: false, isEmailVerified: true
        )
        let b = AuthUser(
            uid: "u", email: "p@h.ru", displayName: "Родитель",
            isAnonymous: false, isEmailVerified: true
        )
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, AuthUser(uid: "u", email: "p@h.ru", isEmailVerified: false))
    }

    // MARK: - Mapped Firebase errors (контракт mapFirebaseError)

    func test_authErrors_haveLocalizedDescriptions() {
        // LiveAuthService.mapFirebaseError маппит в эти AppError-кейсы.
        let errors: [AppError] = [
            .authEmailAlreadyInUse,
            .authWeakPassword,
            .authNetworkError,
            .authUserNotFound,
            .authInvalidCredential,
            .authTokenExpired
        ]
        for error in errors {
            XCTAssertFalse(
                (error.errorDescription ?? "").isEmpty,
                "AppError \(error) должен иметь непустое описание"
            )
        }
    }
}
