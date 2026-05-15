import Foundation
import XCTest
@testable import HappySpeech

// MARK: - AuthServiceContractTests
//
// Тесты контракта AuthService через MockAuthService + SpyAuthService.
//
// LiveAuthService — тонкий делегат FirebaseAuth SDK: каждый его метод состоит из
// `try await Auth.auth().<call>` + маппинг ошибки. Auth.auth() требует
// FirebaseApp.configure() и реальной сети, поэтому LiveAuthService не покрывается
// unit-тестами (residual — см. отчёт). Контракт AuthService — включая все error-пути,
// которые LiveAuthService.mapFirebaseError воспроизводит — проверяется здесь.

final class AuthServiceContractTests: XCTestCase {

    // MARK: - AuthUser value type

    func testAuthUserDefaultInit() {
        let user = AuthUser(uid: "u-1")
        XCTAssertEqual(user.uid, "u-1")
        XCTAssertNil(user.email)
        XCTAssertNil(user.displayName)
        XCTAssertFalse(user.isAnonymous)
        XCTAssertFalse(user.isEmailVerified)
    }

    func testAuthUserFullInit() {
        let user = AuthUser(
            uid: "u-2",
            email: "a@b.ru",
            displayName: "Имя",
            isAnonymous: false,
            isEmailVerified: true
        )
        XCTAssertEqual(user.email, "a@b.ru")
        XCTAssertEqual(user.displayName, "Имя")
        XCTAssertTrue(user.isEmailVerified)
    }

    func testAuthUserEquatable() {
        let a = AuthUser(uid: "x", email: "e", isEmailVerified: true)
        let b = AuthUser(uid: "x", email: "e", isEmailVerified: true)
        let c = AuthUser(uid: "x", email: "e", isEmailVerified: false)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - signIn

    func testMockSignInSuccess() async throws {
        let auth = MockAuthService()
        let user = try await auth.signIn(email: "parent@happyspeech.ru", password: "pass1234")
        XCTAssertEqual(user.email, "parent@happyspeech.ru")
        XCTAssertFalse(user.isAnonymous)
        XCTAssertEqual(auth.currentUser?.uid, user.uid)
    }

    func testMockSignInFailureThrowsInvalidCredential() async {
        let auth = MockAuthService()
        auth.shouldFail = true
        await assertThrows(try await auth.signIn(email: "x@y.ru", password: "bad")) {
            $0 == .authInvalidCredential
        }
    }

    func testMockSignInUnverifiedEmailFlag() async throws {
        let auth = MockAuthService()
        auth.shouldReturnUnverifiedEmail = true
        let user = try await auth.signIn(email: "x@y.ru", password: "p")
        XCTAssertFalse(user.isEmailVerified)
    }

    // MARK: - signUp

    func testMockSignUpSuccessUnverified() async throws {
        let auth = MockAuthService()
        let user = try await auth.signUp(email: "new@happyspeech.ru", password: "pass1234", displayName: "Родитель")
        XCTAssertEqual(user.displayName, "Родитель")
        XCTAssertFalse(user.isEmailVerified, "Новый аккаунт ещё не верифицирован")
    }

    func testMockSignUpFailureThrowsEmailInUse() async {
        let auth = MockAuthService()
        auth.shouldFail = true
        await assertThrows(try await auth.signUp(email: "dup@y.ru", password: "p", displayName: "X")) {
            $0 == .authEmailAlreadyInUse
        }
    }

    // MARK: - Password reset & email verification

    func testMockPasswordResetSuccess() async throws {
        let auth = MockAuthService()
        try await auth.sendPasswordReset(email: "x@y.ru")
    }

    func testMockPasswordResetFailureThrowsUserNotFound() async {
        let auth = MockAuthService()
        auth.shouldFail = true
        await assertThrows(try await auth.sendPasswordReset(email: "missing@y.ru")) {
            $0 == .authUserNotFound
        }
    }

    func testMockEmailVerificationFailure() async {
        let auth = MockAuthService()
        auth.shouldFail = true
        await assertThrows(try await auth.sendEmailVerification()) { error in
            guard case .authSignInFailed = error else { return false }
            return true
        }
    }

    // MARK: - reloadCurrentUser

    func testMockReloadReturnsCurrentUser() async throws {
        let initial = AuthUser(uid: "u", email: "e@e.ru", isEmailVerified: true)
        let auth = MockAuthService(initialUser: initial)
        let reloaded = try await auth.reloadCurrentUser()
        XCTAssertEqual(reloaded?.uid, "u")
    }

    func testMockReloadNilWhenSignedOut() async throws {
        let auth = MockAuthService()
        let reloaded = try await auth.reloadCurrentUser()
        XCTAssertNil(reloaded)
    }

    // MARK: - Google sign-in

    func testMockGoogleSignInSuccess() async throws {
        let auth = MockAuthService()
        let user = try await auth.signInWithGoogle()
        XCTAssertEqual(user.uid, "mock-google-uid")
        XCTAssertTrue(user.isEmailVerified)
    }

    func testMockGoogleSignInCancellation() async {
        let auth = MockAuthService()
        auth.shouldFail = true
        await assertThrows(try await auth.signInWithGoogle()) { $0 == .authGoogleCancelled }
    }

    // MARK: - Anonymous + linking

    func testMockAnonymousSignIn() async throws {
        let auth = MockAuthService()
        let user = try await auth.signInAnonymously()
        XCTAssertTrue(user.isAnonymous)
        XCTAssertNil(user.email)
    }

    func testMockAnonymousSignInFailure() async {
        let auth = MockAuthService()
        auth.shouldFail = true
        await assertThrows(try await auth.signInAnonymously()) { error in
            guard case .authSignInFailed = error else { return false }
            return true
        }
    }

    func testMockLinkAnonymousWithEmail() async throws {
        let anon = AuthUser(uid: "anon-1", isAnonymous: true)
        let auth = MockAuthService(initialUser: anon)
        let linked = try await auth.linkAnonymousWithEmail(email: "linked@y.ru", password: "p")
        XCTAssertEqual(linked.uid, "anon-1", "Link сохраняет uid анонимного аккаунта")
        XCTAssertEqual(linked.email, "linked@y.ru")
        XCTAssertFalse(linked.isAnonymous)
    }

    func testMockLinkFailureThrowsEmailInUse() async {
        let auth = MockAuthService(initialUser: AuthUser(uid: "anon", isAnonymous: true))
        auth.shouldFail = true
        await assertThrows(try await auth.linkAnonymousWithEmail(email: "dup@y.ru", password: "p")) {
            $0 == .authEmailAlreadyInUse
        }
    }

    // MARK: - signOut & deleteAccount

    func testMockSignOutClearsCurrentUser() throws {
        let auth = MockAuthService(initialUser: AuthUser(uid: "u"))
        try auth.signOut()
        XCTAssertNil(auth.currentUser)
    }

    func testMockSignOutFailure() {
        let auth = MockAuthService()
        auth.shouldFail = true
        XCTAssertThrowsError(try auth.signOut()) { error in
            XCTAssertEqual(error as? AppError, .authSignOutFailed)
        }
    }

    func testMockDeleteAccountClearsUser() async throws {
        let auth = MockAuthService(initialUser: AuthUser(uid: "u"))
        try await auth.deleteAccount()
        XCTAssertNil(auth.currentUser)
    }

    func testMockDeleteAccountFailure() async {
        let auth = MockAuthService(initialUser: AuthUser(uid: "u"))
        auth.shouldFail = true
        await assertThrows(try await auth.deleteAccount()) { error in
            guard case .authSignInFailed = error else { return false }
            return true
        }
    }

    // MARK: - Auth state listener

    func testMockAddListenerFiresImmediatelyWithSnapshot() {
        let auth = MockAuthService(initialUser: AuthUser(uid: "u-init"))
        let received = ListenerBox()
        _ = auth.addAuthStateListener { received.set($0) }
        XCTAssertEqual(received.value?.uid, "u-init")
    }

    func testMockListenerNotifiedOnSignIn() async throws {
        let auth = MockAuthService()
        let received = ListenerBox()
        _ = auth.addAuthStateListener { received.set($0) }
        _ = try await auth.signIn(email: "e@e.ru", password: "p")
        XCTAssertNotNil(received.value)
        XCTAssertEqual(received.value?.email, "e@e.ru")
    }

    func testMockRemoveListenerStopsNotifications() async throws {
        let auth = MockAuthService()
        let received = ListenerBox()
        let handle = auth.addAuthStateListener { received.set($0) }
        auth.removeAuthStateListener(handle)
        received.set(nil)
        _ = try await auth.signIn(email: "e@e.ru", password: "p")
        XCTAssertNil(received.value, "После removeListener уведомления не приходят")
    }

    func testMockRemoveListenerIgnoresInvalidHandle() {
        let auth = MockAuthService()
        auth.removeAuthStateListener("not-a-uuid")
        // Не должно падать.
    }

    // MARK: - SpyAuthService call counting

    func testSpyCountsSignInCalls() async throws {
        let spy = SpyAuthService()
        _ = try await spy.signIn(email: "a@b.ru", password: "p")
        _ = try await spy.signIn(email: "c@d.ru", password: "p")
        XCTAssertEqual(spy.signInCallCount, 2)
        XCTAssertEqual(spy.lastSignInEmail, "c@d.ru")
    }

    func testSpyCountsSignUpCalls() async throws {
        let spy = SpyAuthService()
        _ = try await spy.signUp(email: "a@b.ru", password: "p", displayName: "X")
        XCTAssertEqual(spy.signUpCallCount, 1)
    }

    func testSpyShouldFailPropagatesError() async {
        let spy = SpyAuthService()
        spy.shouldFail = true
        await assertThrows(try await spy.signIn(email: "a@b.ru", password: "p")) {
            $0 == .authInvalidCredential
        }
    }

    // MARK: - Helpers

    private func assertThrows(
        _ expression: @autoclosure () async throws -> AuthUser,
        file: StaticString = #filePath,
        line: UInt = #line,
        matching predicate: (AppError) -> Bool
    ) async {
        do {
            _ = try await expression()
            XCTFail("Ожидалась ошибка AppError", file: file, line: line)
        } catch let error as AppError {
            XCTAssertTrue(predicate(error), "Неожиданный AppError: \(error)", file: file, line: line)
        } catch {
            XCTFail("Ожидался AppError, получено: \(error)", file: file, line: line)
        }
    }

    private func assertThrows(
        _ expression: @autoclosure () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line,
        matching predicate: (AppError) -> Bool
    ) async {
        do {
            try await expression()
            XCTFail("Ожидалась ошибка AppError", file: file, line: line)
        } catch let error as AppError {
            XCTAssertTrue(predicate(error), "Неожиданный AppError: \(error)", file: file, line: line)
        } catch {
            XCTFail("Ожидался AppError, получено: \(error)", file: file, line: line)
        }
    }
}

// MARK: - ListenerBox

/// Потокобезопасный контейнер для значения, полученного в auth-state-листенере.
private final class ListenerBox: @unchecked Sendable {
    private var _value: AuthUser?
    private let lock = NSLock()
    var value: AuthUser? {
        lock.lock(); defer { lock.unlock() }
        return _value
    }
    func set(_ user: AuthUser?) {
        lock.lock(); _value = user; lock.unlock()
    }
}
