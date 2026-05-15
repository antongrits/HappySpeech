@testable import HappySpeech
import XCTest

// MARK: - Spy Presenter

@MainActor
private final class SpyAuthPresenter: AuthPresentationLogic {

    var authStateCount = 0
    var signInCount = 0
    var signUpCount = 0
    var googleSignInCount = 0
    var forgotPasswordCount = 0
    var emailVerificationCount = 0
    var resendVerificationCount = 0
    var signOutCount = 0
    var deleteAccountCount = 0
    var errorCount = 0
    var parentalGateCount = 0
    var anonymousUpgradeCount = 0
    var tooManyAttemptsCount = 0
    var deleteGateRequiredCount = 0

    var lastAuthState: AuthModels.AuthState.Response?
    var lastEmailVerification: AuthModels.EmailVerification.Response?
    var lastParentalGate: AuthModels.ParentalGate.Response?
    var lastError: Error?
    var lastTooManyAttempts: AuthModels.TooManyFailedAttempts.Response?

    func presentAuthState(_ response: AuthModels.AuthState.Response) async {
        authStateCount += 1
        lastAuthState = response
    }
    func presentSignIn(_ response: AuthModels.SignIn.Response) async { signInCount += 1 }
    func presentSignUp(_ response: AuthModels.SignUp.Response) async { signUpCount += 1 }
    func presentGoogleSignIn(_ response: AuthModels.GoogleSignIn.Response) async { googleSignInCount += 1 }
    func presentForgotPassword(_ response: AuthModels.ForgotPassword.Response) async { forgotPasswordCount += 1 }
    func presentEmailVerification(_ response: AuthModels.EmailVerification.Response) async {
        emailVerificationCount += 1
        lastEmailVerification = response
    }
    func presentResendVerification(_ response: AuthModels.ResendVerification.Response) async {
        resendVerificationCount += 1
    }
    func presentSignOut(_ response: AuthModels.SignOut.Response) async { signOutCount += 1 }
    func presentDeleteAccount(_ response: AuthModels.DeleteAccount.Response) async { deleteAccountCount += 1 }
    func presentError(_ error: any Error) async {
        errorCount += 1
        lastError = error
    }
    func presentParentalGate(_ response: AuthModels.ParentalGate.Response) async {
        parentalGateCount += 1
        lastParentalGate = response
    }
    func presentAnonymousUpgrade(_ response: AuthModels.AnonymousUpgrade.Response) async {
        anonymousUpgradeCount += 1
    }
    func presentTooManyFailedAttempts(_ response: AuthModels.TooManyFailedAttempts.Response) async {
        tooManyAttemptsCount += 1
        lastTooManyAttempts = response
    }
    func presentDeleteAccountGateRequired(_ response: AuthModels.DeleteAccountGateRequired.Response) async {
        deleteGateRequiredCount += 1
    }
}

// MARK: - Tests

@MainActor
final class AuthInteractorTests: XCTestCase {

    private func makeSUT(
        initialUser: AuthUser? = nil,
        shouldFail: Bool = false
    ) -> (AuthInteractor, SpyAuthPresenter, MockAuthService) {
        let auth = MockAuthService(initialUser: initialUser)
        auth.shouldFail = shouldFail
        let sut = AuthInteractor(authService: auth)
        let spy = SpyAuthPresenter()
        sut.presenter = spy
        return (sut, spy, auth)
    }

    // MARK: - checkAuthState

    func test_checkAuthState_unauthenticated() async {
        let (sut, spy, _) = makeSUT()
        await sut.checkAuthState(.init())
        XCTAssertEqual(spy.authStateCount, 1)
        XCTAssertEqual(spy.lastAuthState, .unauthenticated)
    }

    func test_checkAuthState_authenticated() async {
        let user = AuthUser(uid: "u1", email: "a@b.com", displayName: "Test",
                            isAnonymous: false, isEmailVerified: true)
        let (sut, spy, _) = makeSUT(initialUser: user)
        await sut.checkAuthState(.init())
        if case .authenticated(let returned) = spy.lastAuthState {
            XCTAssertEqual(returned.uid, "u1")
        } else {
            XCTFail("Expected authenticated state")
        }
    }

    // MARK: - signIn

    func test_signIn_success() async {
        let (sut, spy, _) = makeSUT()
        await sut.signIn(.init(email: "parent@happy.ru", password: "secret123"))
        XCTAssertEqual(spy.signInCount, 1)
        XCTAssertEqual(spy.errorCount, 0)
    }

    func test_signIn_emptyEmailValidationError() async {
        let (sut, spy, _) = makeSUT()
        await sut.signIn(.init(email: "", password: "secret123"))
        XCTAssertEqual(spy.signInCount, 0)
        XCTAssertEqual(spy.errorCount, 1)
    }

    func test_signIn_invalidEmailValidationError() async {
        let (sut, spy, _) = makeSUT()
        await sut.signIn(.init(email: "notanemail", password: "secret123"))
        XCTAssertEqual(spy.errorCount, 1)
    }

    func test_signIn_emptyPasswordValidationError() async {
        let (sut, spy, _) = makeSUT()
        await sut.signIn(.init(email: "parent@happy.ru", password: ""))
        XCTAssertEqual(spy.errorCount, 1)
    }

    func test_signIn_failureEmitsError() async {
        let (sut, spy, _) = makeSUT(shouldFail: true)
        await sut.signIn(.init(email: "parent@happy.ru", password: "secret123"))
        XCTAssertEqual(spy.signInCount, 0)
        XCTAssertEqual(spy.errorCount, 1)
    }

    // MARK: - signUp

    func test_signUp_success() async {
        let (sut, spy, _) = makeSUT()
        await sut.signUp(.init(email: "new@happy.ru", password: "secret123", name: "Анна"))
        XCTAssertEqual(spy.signUpCount, 1)
        XCTAssertEqual(spy.errorCount, 0)
    }

    func test_signUp_shortNameValidationError() async {
        let (sut, spy, _) = makeSUT()
        await sut.signUp(.init(email: "new@happy.ru", password: "secret123", name: "А"))
        XCTAssertEqual(spy.signUpCount, 0)
        XCTAssertEqual(spy.errorCount, 1)
    }

    func test_signUp_longNameValidationError() async {
        let (sut, spy, _) = makeSUT()
        let longName = String(repeating: "я", count: 51)
        await sut.signUp(.init(email: "new@happy.ru", password: "secret123", name: longName))
        XCTAssertEqual(spy.errorCount, 1)
    }

    func test_signUp_shortPasswordValidationError() async {
        let (sut, spy, _) = makeSUT()
        await sut.signUp(.init(email: "new@happy.ru", password: "abc12", name: "Анна"))
        XCTAssertEqual(spy.errorCount, 1)
    }

    func test_signUp_passwordWithoutDigitValidationError() async {
        let (sut, spy, _) = makeSUT()
        await sut.signUp(.init(email: "new@happy.ru", password: "longpassword", name: "Анна"))
        XCTAssertEqual(spy.errorCount, 1)
    }

    func test_signUp_invalidEmailValidationError() async {
        let (sut, spy, _) = makeSUT()
        await sut.signUp(.init(email: "bad", password: "secret123", name: "Анна"))
        XCTAssertEqual(spy.errorCount, 1)
    }

    func test_signUp_failureEmitsError() async {
        let (sut, spy, _) = makeSUT(shouldFail: true)
        await sut.signUp(.init(email: "new@happy.ru", password: "secret123", name: "Анна"))
        XCTAssertEqual(spy.signUpCount, 0)
        XCTAssertEqual(spy.errorCount, 1)
    }

    // MARK: - signInWithGoogle

    func test_signInWithGoogle_success() async {
        let (sut, spy, _) = makeSUT()
        await sut.signInWithGoogle(.init())
        XCTAssertEqual(spy.googleSignInCount, 1)
    }

    func test_signInWithGoogle_failureEmitsError() async {
        let (sut, spy, _) = makeSUT(shouldFail: true)
        await sut.signInWithGoogle(.init())
        XCTAssertEqual(spy.googleSignInCount, 0)
        XCTAssertEqual(spy.errorCount, 1)
    }

    // MARK: - forgotPassword

    func test_forgotPassword_success() async {
        let (sut, spy, _) = makeSUT()
        await sut.forgotPassword(.init(email: "parent@happy.ru"))
        XCTAssertEqual(spy.forgotPasswordCount, 1)
    }

    func test_forgotPassword_invalidEmailEmitsError() async {
        let (sut, spy, _) = makeSUT()
        await sut.forgotPassword(.init(email: "x"))
        XCTAssertEqual(spy.forgotPasswordCount, 0)
        XCTAssertEqual(spy.errorCount, 1)
    }

    func test_forgotPassword_failureEmitsError() async {
        let (sut, spy, _) = makeSUT(shouldFail: true)
        await sut.forgotPassword(.init(email: "parent@happy.ru"))
        XCTAssertEqual(spy.errorCount, 1)
    }

    // MARK: - checkEmailVerified

    func test_checkEmailVerified_verifiedUser() async {
        let user = AuthUser(uid: "u1", email: "a@b.com", displayName: "T",
                            isAnonymous: false, isEmailVerified: true)
        let (sut, spy, _) = makeSUT(initialUser: user)
        await sut.checkEmailVerified(.init())
        XCTAssertEqual(spy.lastEmailVerification?.isVerified, true)
    }

    func test_checkEmailVerified_unverifiedUser() async {
        let user = AuthUser(uid: "u1", email: "a@b.com", displayName: "T",
                            isAnonymous: false, isEmailVerified: false)
        let (sut, spy, _) = makeSUT(initialUser: user)
        await sut.checkEmailVerified(.init())
        XCTAssertEqual(spy.lastEmailVerification?.isVerified, false)
    }

    func test_checkEmailVerified_noUserIsUnverified() async {
        let (sut, spy, _) = makeSUT()
        await sut.checkEmailVerified(.init())
        XCTAssertEqual(spy.lastEmailVerification?.isVerified, false)
    }

    // MARK: - resendVerification

    func test_resendVerification_success() async {
        let (sut, spy, _) = makeSUT()
        await sut.resendVerification(.init())
        XCTAssertEqual(spy.resendVerificationCount, 1)
    }

    func test_resendVerification_failureEmitsError() async {
        let (sut, spy, _) = makeSUT(shouldFail: true)
        await sut.resendVerification(.init())
        XCTAssertEqual(spy.errorCount, 1)
    }

    // MARK: - solveParentalGate

    func test_parentalGate_generateQuestion() async {
        let (sut, spy, _) = makeSUT()
        await sut.solveParentalGate(.init(action: .generateQuestion))
        XCTAssertEqual(spy.parentalGateCount, 1)
        XCTAssertEqual(spy.lastParentalGate?.state, .waiting)
        XCTAssertNotNil(spy.lastParentalGate?.question)
    }

    func test_parentalGate_correctAnswerPasses() async {
        let (sut, spy, _) = makeSUT()
        await sut.solveParentalGate(.init(action: .generateQuestion))
        guard let question = spy.lastParentalGate?.question else {
            return XCTFail("No gate question")
        }
        await sut.solveParentalGate(.init(action: .submitAnswer(question.correctAnswer)))
        XCTAssertEqual(spy.lastParentalGate?.state, .passed)
    }

    func test_parentalGate_wrongAnswerFailsAndRegenerates() async {
        let (sut, spy, _) = makeSUT()
        await sut.solveParentalGate(.init(action: .generateQuestion))
        guard let question = spy.lastParentalGate?.question else {
            return XCTFail("No gate question")
        }
        await sut.solveParentalGate(.init(action: .submitAnswer(question.correctAnswer + 1)))
        XCTAssertEqual(spy.lastParentalGate?.state, .failed)
        // Новый вопрос сгенерирован после неверного ответа.
        XCTAssertNotNil(spy.lastParentalGate?.question)
    }

    func test_parentalGate_submitWithoutQuestionFails() async {
        let (sut, spy, _) = makeSUT()
        await sut.solveParentalGate(.init(action: .submitAnswer(42)))
        XCTAssertEqual(spy.lastParentalGate?.state, .failed)
        XCTAssertNil(spy.lastParentalGate?.question)
    }

    // MARK: - upgradeAnonymousAccount

    func test_upgradeAnonymous_success() async {
        let anon = AuthUser(uid: "anon-1", email: nil, displayName: nil,
                            isAnonymous: true, isEmailVerified: false)
        let (sut, spy, _) = makeSUT(initialUser: anon)
        await sut.upgradeAnonymousAccount(.init(
            email: "real@happy.ru", password: "secret123", displayName: "Игорь"
        ))
        XCTAssertEqual(spy.anonymousUpgradeCount, 1)
    }

    func test_upgradeAnonymous_notAuthenticatedEmitsError() async {
        let (sut, spy, _) = makeSUT()
        await sut.upgradeAnonymousAccount(.init(
            email: "real@happy.ru", password: "secret123", displayName: "Игорь"
        ))
        XCTAssertEqual(spy.anonymousUpgradeCount, 0)
        XCTAssertEqual(spy.errorCount, 1)
    }

    func test_upgradeAnonymous_validationError() async {
        let anon = AuthUser(uid: "anon-1", email: nil, displayName: nil,
                            isAnonymous: true, isEmailVerified: false)
        let (sut, spy, _) = makeSUT(initialUser: anon)
        await sut.upgradeAnonymousAccount(.init(
            email: "bad", password: "x", displayName: "А"
        ))
        XCTAssertEqual(spy.errorCount, 1)
        XCTAssertEqual(spy.anonymousUpgradeCount, 0)
    }

    func test_upgradeAnonymous_serviceFailureEmitsError() async {
        let anon = AuthUser(uid: "anon-1", email: nil, displayName: nil,
                            isAnonymous: true, isEmailVerified: false)
        let auth = MockAuthService(initialUser: anon)
        auth.shouldFail = true
        let sut = AuthInteractor(authService: auth)
        let spy = SpyAuthPresenter()
        sut.presenter = spy
        await sut.upgradeAnonymousAccount(.init(
            email: "real@happy.ru", password: "secret123", displayName: "Игорь"
        ))
        XCTAssertEqual(spy.errorCount, 1)
    }

    // MARK: - signOut

    func test_signOut_success() async {
        let user = AuthUser(uid: "u1", email: "a@b.com", displayName: "T",
                            isAnonymous: false, isEmailVerified: true)
        let (sut, spy, _) = makeSUT(initialUser: user)
        sut.signOut(.init())
        // signOut эмитит через вложенный Task — даём ему завершиться.
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(spy.signOutCount, 1)
    }

    func test_signOut_failureEmitsError() async {
        let user = AuthUser(uid: "u1", email: "a@b.com", displayName: "T",
                            isAnonymous: false, isEmailVerified: true)
        let (sut, spy, _) = makeSUT(initialUser: user, shouldFail: true)
        sut.signOut(.init())
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(spy.signOutCount, 0)
        XCTAssertEqual(spy.errorCount, 1)
    }

    // MARK: - deleteAccount

    func test_deleteAccount_withoutGateRequiresGate() async {
        let user = AuthUser(uid: "u1", email: "a@b.com", displayName: "T",
                            isAnonymous: false, isEmailVerified: true)
        let (sut, spy, _) = makeSUT(initialUser: user)
        await sut.deleteAccount(.init())
        XCTAssertEqual(spy.deleteGateRequiredCount, 1)
        XCTAssertEqual(spy.deleteAccountCount, 0)
    }

    func test_deleteAccount_skipGateSucceeds() async {
        let user = AuthUser(uid: "u1", email: "a@b.com", displayName: "T",
                            isAnonymous: false, isEmailVerified: true)
        let (sut, spy, _) = makeSUT(initialUser: user)
        await sut.deleteAccount(.init(skipGate: true))
        XCTAssertEqual(spy.deleteAccountCount, 1)
    }

    func test_deleteAccount_afterPassingGateSucceeds() async {
        let user = AuthUser(uid: "u1", email: "a@b.com", displayName: "T",
                            isAnonymous: false, isEmailVerified: true)
        let (sut, spy, _) = makeSUT(initialUser: user)
        // Проходим parental gate.
        await sut.solveParentalGate(.init(action: .generateQuestion))
        guard let question = spy.lastParentalGate?.question else {
            return XCTFail("No gate question")
        }
        await sut.solveParentalGate(.init(action: .submitAnswer(question.correctAnswer)))
        await sut.deleteAccount(.init())
        XCTAssertEqual(spy.deleteAccountCount, 1)
    }

    func test_deleteAccount_failureEmitsError() async {
        let user = AuthUser(uid: "u1", email: "a@b.com", displayName: "T",
                            isAnonymous: false, isEmailVerified: true)
        let (sut, spy, _) = makeSUT(initialUser: user, shouldFail: true)
        await sut.deleteAccount(.init(skipGate: true))
        XCTAssertEqual(spy.errorCount, 1)
    }

    // MARK: - AppAuthError

    func test_appAuthError_localizedDescriptions() {
        XCTAssertEqual(AppAuthError.validation("проблема").errorDescription, "проблема")
        XCTAssertNotNil(AppAuthError.notAuthenticated.errorDescription)
        XCTAssertNotNil(AppAuthError.tooManyAttempts.errorDescription)
    }
}
