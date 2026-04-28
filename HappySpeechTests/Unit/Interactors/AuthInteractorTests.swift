@testable import HappySpeech
import XCTest

// MARK: - AuthInteractorTests
//
// M10.1 — 10 тестов для AuthInteractor.
// Покрывает: checkAuthState (auth/unauth), signIn (success/failure),
// signUp, forgotPassword, signOut, deleteAccount, checkEmailVerified.

@MainActor
final class AuthInteractorTests: XCTestCase {

    // MARK: - Spy

    @MainActor
    private final class SpyPresenter: AuthPresentationLogic {
        var authStateCalled = false
        var signInCalled = false
        var signUpCalled = false
        var googleSignInCalled = false
        var forgotPasswordCalled = false
        var emailVerificationCalled = false
        var resendVerificationCalled = false
        var signOutCalled = false
        var deleteAccountCalled = false
        var errorCalled = false

        var lastAuthState: AuthModels.AuthState.Response?
        var lastError: Error?

        func presentAuthState(_ response: AuthModels.AuthState.Response) async {
            authStateCalled = true
            lastAuthState = response
        }
        func presentSignIn(_ response: AuthModels.SignIn.Response) async {
            signInCalled = true
        }
        func presentSignUp(_ response: AuthModels.SignUp.Response) async {
            signUpCalled = true
        }
        func presentGoogleSignIn(_ response: AuthModels.GoogleSignIn.Response) async {
            googleSignInCalled = true
        }
        func presentForgotPassword(_ response: AuthModels.ForgotPassword.Response) async {
            forgotPasswordCalled = true
        }
        func presentEmailVerification(_ response: AuthModels.EmailVerification.Response) async {
            emailVerificationCalled = true
        }
        func presentResendVerification(_ response: AuthModels.ResendVerification.Response) async {
            resendVerificationCalled = true
        }
        func presentSignOut(_ response: AuthModels.SignOut.Response) async {
            signOutCalled = true
        }
        func presentDeleteAccount(_ response: AuthModels.DeleteAccount.Response) async {
            deleteAccountCalled = true
        }
        func presentError(_ error: Error) async {
            errorCalled = true
            lastError = error
        }
    }

    private func makeSUT(
        initialUser: AuthUser? = nil,
        shouldFail: Bool = false
    ) -> (AuthInteractor, SpyPresenter, MockAuthService) {
        let mockService = MockAuthService(initialUser: initialUser)
        mockService.shouldFail = shouldFail
        let sut = AuthInteractor(authService: mockService)
        let spy = SpyPresenter()
        sut.presenter = spy
        return (sut, spy, mockService)
    }

    // MARK: - 1. checkAuthState без пользователя → unauthenticated

    func test_checkAuthState_noUser_unauthenticated() async {
        let (sut, spy, _) = makeSUT(initialUser: nil)
        await sut.checkAuthState(.init())
        XCTAssertTrue(spy.authStateCalled)
        if case .unauthenticated = spy.lastAuthState {
            // OK
        } else {
            XCTFail("Ожидался .unauthenticated, получен \(String(describing: spy.lastAuthState))")
        }
    }

    // MARK: - 2. checkAuthState с пользователем → authenticated

    func test_checkAuthState_withUser_authenticated() async {
        let user = AuthUser(uid: "u1", email: "a@b.com", displayName: "Test",
                            isAnonymous: false, isEmailVerified: true)
        let (sut, spy, _) = makeSUT(initialUser: user)
        await sut.checkAuthState(.init())
        if case .authenticated(let u) = spy.lastAuthState {
            XCTAssertEqual(u.uid, "u1")
        } else {
            XCTFail("Ожидался .authenticated")
        }
    }

    // MARK: - 3. signIn успешный → presentSignIn

    func test_signIn_success_callsPresenter() async {
        let (sut, spy, _) = makeSUT()
        await sut.signIn(.init(email: "test@mail.com", password: "secret"))
        XCTAssertTrue(spy.signInCalled)
        XCTAssertFalse(spy.errorCalled)
    }

    // MARK: - 4. signIn с ошибкой → presentError

    func test_signIn_failure_callsError() async {
        let (sut, spy, _) = makeSUT(shouldFail: true)
        await sut.signIn(.init(email: "bad@mail.com", password: "wrong"))
        XCTAssertFalse(spy.signInCalled)
        XCTAssertTrue(spy.errorCalled)
    }

    // MARK: - 5. signUp успешный → presentSignUp

    func test_signUp_success_callsPresenter() async {
        let (sut, spy, _) = makeSUT()
        // password >= 6 символов (требование EmailAuthWorker.validate)
        await sut.signUp(.init(email: "new@mail.com", password: "pass123", name: "Новый"))
        XCTAssertTrue(spy.signUpCalled)
        XCTAssertFalse(spy.errorCalled)
    }

    // MARK: - 6. signUp с ошибкой → presentError

    func test_signUp_failure_callsError() async {
        let (sut, spy, _) = makeSUT(shouldFail: true)
        await sut.signUp(.init(email: "dup@mail.com", password: "pass", name: "Дубликат"))
        XCTAssertFalse(spy.signUpCalled)
        XCTAssertTrue(spy.errorCalled)
    }

    // MARK: - 7. forgotPassword успешный → presentForgotPassword

    func test_forgotPassword_success_callsPresenter() async {
        let (sut, spy, _) = makeSUT()
        await sut.forgotPassword(.init(email: "forgot@mail.com"))
        XCTAssertTrue(spy.forgotPasswordCalled)
    }

    // MARK: - 8. forgotPassword с ошибкой → presentError

    func test_forgotPassword_failure_callsError() async {
        let (sut, spy, _) = makeSUT(shouldFail: true)
        await sut.forgotPassword(.init(email: "ghost@mail.com"))
        XCTAssertFalse(spy.forgotPasswordCalled)
        XCTAssertTrue(spy.errorCalled)
    }

    // MARK: - 9. signOut успешный → presentSignOut

    func test_signOut_success_callsPresenter() async {
        let user = AuthUser(uid: "u2", email: "a@b.com", displayName: nil,
                            isAnonymous: false, isEmailVerified: true)
        let (sut, spy, _) = makeSUT(initialUser: user)
        sut.signOut(.init())
        // Небольшая задержка для Task
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(spy.signOutCalled)
    }

    // MARK: - 10. deleteAccount успешный → presentDeleteAccount

    func test_deleteAccount_success_callsPresenter() async {
        let user = AuthUser(uid: "u3", email: "del@mail.com", displayName: nil,
                            isAnonymous: false, isEmailVerified: true)
        let (sut, spy, _) = makeSUT(initialUser: user)
        await sut.deleteAccount(.init())
        XCTAssertTrue(spy.deleteAccountCalled)
    }
}
