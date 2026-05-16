import XCTest
@testable import HappySpeech

// MARK: - AuthPresenterTests
//
// Phase 2.6 batch 3 — покрытие AuthPresenter (0% → цель ≥90%).

@MainActor
final class AuthPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: AuthDisplayLogic {
        var authStateVM: AuthModels.AuthState.ViewModel?
        var signInVM: AuthModels.SignIn.ViewModel?
        var signUpVM: AuthModels.SignUp.ViewModel?
        var googleSignInVM: AuthModels.GoogleSignIn.ViewModel?
        var forgotPasswordVM: AuthModels.ForgotPassword.ViewModel?
        var emailVerificationVM: AuthModels.EmailVerification.ViewModel?
        var resendVerificationVM: AuthModels.ResendVerification.ViewModel?
        var signOutVM: AuthModels.SignOut.ViewModel?
        var deleteAccountVM: AuthModels.DeleteAccount.ViewModel?
        var errorVM: AuthModels.ErrorViewModel?
        var parentalGateVM: AuthModels.ParentalGate.ViewModel?
        var anonymousUpgradeVM: AuthModels.AnonymousUpgrade.ViewModel?
        var tooManyFailedVM: AuthModels.TooManyFailedAttempts.ViewModel?
        var deleteGateRequiredVM: AuthModels.DeleteAccountGateRequired.ViewModel?

        func displayAuthState(_ vm: AuthModels.AuthState.ViewModel) { authStateVM = vm }
        func displaySignIn(_ vm: AuthModels.SignIn.ViewModel) { signInVM = vm }
        func displaySignUp(_ vm: AuthModels.SignUp.ViewModel) { signUpVM = vm }
        func displayGoogleSignIn(_ vm: AuthModels.GoogleSignIn.ViewModel) { googleSignInVM = vm }
        func displayForgotPassword(_ vm: AuthModels.ForgotPassword.ViewModel) { forgotPasswordVM = vm }
        func displayEmailVerification(_ vm: AuthModels.EmailVerification.ViewModel) { emailVerificationVM = vm }
        func displayResendVerification(_ vm: AuthModels.ResendVerification.ViewModel) { resendVerificationVM = vm }
        func displaySignOut(_ vm: AuthModels.SignOut.ViewModel) { signOutVM = vm }
        func displayDeleteAccount(_ vm: AuthModels.DeleteAccount.ViewModel) { deleteAccountVM = vm }
        func displayError(_ vm: AuthModels.ErrorViewModel) { errorVM = vm }
        func displayParentalGate(_ vm: AuthModels.ParentalGate.ViewModel) { parentalGateVM = vm }
        func displayAnonymousUpgrade(_ vm: AuthModels.AnonymousUpgrade.ViewModel) { anonymousUpgradeVM = vm }
        func displayTooManyFailedAttempts(_ vm: AuthModels.TooManyFailedAttempts.ViewModel) { tooManyFailedVM = vm }
        func displayDeleteAccountGateRequired(_ vm: AuthModels.DeleteAccountGateRequired.ViewModel) { deleteGateRequiredVM = vm }
    }

    private func makeSUT() -> (AuthPresenter, DisplaySpy) {
        let sut = AuthPresenter()
        let spy = DisplaySpy()
        sut.viewModel = spy
        return (sut, spy)
    }

    private func makeUser(
        id: String = "user-1",
        isAnonymous: Bool = false,
        isEmailVerified: Bool = true,
        displayName: String? = "Иван",
        email: String? = "ivan@example.com"
    ) -> AuthUser {
        AuthUser(
            uid: id,
            email: email,
            displayName: displayName,
            isAnonymous: isAnonymous,
            isEmailVerified: isEmailVerified
        )
    }

    // MARK: - presentAuthState

    func test_presentAuthState_authenticated_setsFields() async {
        let (sut, spy) = makeSUT()
        let user = makeUser(isAnonymous: false, isEmailVerified: true, displayName: "Маша")
        await sut.presentAuthState(.authenticated(user))
        XCTAssertTrue(spy.authStateVM?.isAuthenticated == true)
        XCTAssertFalse(spy.authStateVM?.isAnonymous ?? true)
        XCTAssertTrue(spy.authStateVM?.isEmailVerified == true)
        XCTAssertEqual(spy.authStateVM?.displayName, "Маша")
    }

    func test_presentAuthState_unauthenticated_allFalse() async {
        let (sut, spy) = makeSUT()
        await sut.presentAuthState(.unauthenticated)
        XCTAssertFalse(spy.authStateVM?.isAuthenticated ?? true)
        XCTAssertFalse(spy.authStateVM?.isAnonymous ?? true)
        XCTAssertFalse(spy.authStateVM?.isEmailVerified ?? true)
        XCTAssertNil(spy.authStateVM?.displayName)
    }

    func test_presentAuthState_anonymous_flagSet() async {
        let (sut, spy) = makeSUT()
        let user = makeUser(isAnonymous: true, isEmailVerified: false, displayName: nil)
        await sut.presentAuthState(.authenticated(user))
        XCTAssertTrue(spy.authStateVM?.isAnonymous == true)
    }

    // MARK: - presentSignIn

    func test_presentSignIn_withName_welcomeMessageNotEmpty() async {
        let (sut, spy) = makeSUT()
        let user = makeUser(isEmailVerified: true, displayName: "Ваня")
        await sut.presentSignIn(.init(user: user))
        XCTAssertFalse(spy.signInVM?.welcomeMessage.isEmpty ?? true)
        XCTAssertFalse(spy.signInVM?.requiresEmailVerification ?? true)
    }

    func test_presentSignIn_noName_welcomeMessageNotEmpty() async {
        let (sut, spy) = makeSUT()
        let user = makeUser(isEmailVerified: true, displayName: nil)
        await sut.presentSignIn(.init(user: user))
        XCTAssertFalse(spy.signInVM?.welcomeMessage.isEmpty ?? true)
    }

    func test_presentSignIn_unverifiedEmail_requiresVerification() async {
        let (sut, spy) = makeSUT()
        let user = makeUser(isEmailVerified: false, email: "test@test.ru")
        await sut.presentSignIn(.init(user: user))
        XCTAssertTrue(spy.signInVM?.requiresEmailVerification == true)
    }

    // MARK: - presentSignUp

    func test_presentSignUp_successMessageNotEmpty() async {
        let (sut, spy) = makeSUT()
        let user = makeUser(email: "new@test.ru")
        await sut.presentSignUp(.init(user: user))
        XCTAssertFalse(spy.signUpVM?.successMessage.isEmpty ?? true)
        XCTAssertEqual(spy.signUpVM?.email, "new@test.ru")
    }

    func test_presentSignUp_nilEmail_emptyString() async {
        let (sut, spy) = makeSUT()
        let user = makeUser(email: nil)
        await sut.presentSignUp(.init(user: user))
        XCTAssertEqual(spy.signUpVM?.email, "")
    }

    // MARK: - presentGoogleSignIn

    func test_presentGoogleSignIn_withName_welcomeNotEmpty() async {
        let (sut, spy) = makeSUT()
        let user = makeUser(displayName: "Соня")
        await sut.presentGoogleSignIn(.init(user: user))
        XCTAssertFalse(spy.googleSignInVM?.welcomeMessage.isEmpty ?? true)
        XCTAssertTrue(spy.googleSignInVM?.welcomeMessage.contains("Соня") == true)
    }

    func test_presentGoogleSignIn_nilName_usesDefaultName() async {
        let (sut, spy) = makeSUT()
        let user = makeUser(displayName: nil)
        await sut.presentGoogleSignIn(.init(user: user))
        XCTAssertFalse(spy.googleSignInVM?.welcomeMessage.isEmpty ?? true)
    }

    // MARK: - presentForgotPassword

    func test_presentForgotPassword_messageContainsEmail() async {
        let (sut, spy) = makeSUT()
        await sut.presentForgotPassword(.init(email: "recover@test.ru"))
        XCTAssertFalse(spy.forgotPasswordVM?.successMessage.isEmpty ?? true)
        XCTAssertTrue(spy.forgotPasswordVM?.successMessage.contains("recover@test.ru") == true)
    }

    // MARK: - presentEmailVerification

    func test_presentEmailVerification_verified_messageNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentEmailVerification(.init(isVerified: true))
        XCTAssertTrue(spy.emailVerificationVM?.isVerified == true)
        XCTAssertFalse(spy.emailVerificationVM?.message.isEmpty ?? true)
    }

    func test_presentEmailVerification_notVerified_messageNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentEmailVerification(.init(isVerified: false))
        XCTAssertFalse(spy.emailVerificationVM?.isVerified ?? true)
        XCTAssertFalse(spy.emailVerificationVM?.message.isEmpty ?? true)
    }

    // MARK: - presentResendVerification

    func test_presentResendVerification_messageNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentResendVerification(.init())
        XCTAssertFalse(spy.resendVerificationVM?.message.isEmpty ?? true)
    }

    // MARK: - presentSignOut

    func test_presentSignOut_callsDisplay() async {
        let (sut, spy) = makeSUT()
        await sut.presentSignOut(.init())
        XCTAssertNotNil(spy.signOutVM)
    }

    // MARK: - presentDeleteAccount

    func test_presentDeleteAccount_callsDisplay() async {
        let (sut, spy) = makeSUT()
        await sut.presentDeleteAccount(.init())
        XCTAssertNotNil(spy.deleteAccountVM)
    }

    // MARK: - presentError

    func test_presentError_appError_usesDescription() async {
        let (sut, spy) = makeSUT()
        let error = AppError.networkUnavailable
        await sut.presentError(error)
        XCTAssertFalse(spy.errorVM?.title.isEmpty ?? true)
        XCTAssertFalse(spy.errorVM?.message.isEmpty ?? true)
    }

    func test_presentError_genericError_usesLocalizedDescription() async {
        let (sut, spy) = makeSUT()
        let error = NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "Тест ошибка"])
        await sut.presentError(error)
        XCTAssertFalse(spy.errorVM?.message.isEmpty ?? true)
    }

    // MARK: - presentParentalGate

    func test_presentParentalGate_waiting_stateString() async {
        let (sut, spy) = makeSUT()
        let question = ParentalGateQuestion(displayText: "2 + 2 = ?", correctAnswer: 4)
        await sut.presentParentalGate(.init(question: question, state: .waiting))
        XCTAssertEqual(spy.parentalGateVM?.state, "waiting")
        XCTAssertEqual(spy.parentalGateVM?.questionText, "2 + 2 = ?")
    }

    func test_presentParentalGate_passed_stateString() async {
        let (sut, spy) = makeSUT()
        await sut.presentParentalGate(.init(question: nil, state: .passed))
        XCTAssertEqual(spy.parentalGateVM?.state, "passed")
    }

    func test_presentParentalGate_failed_stateString() async {
        let (sut, spy) = makeSUT()
        await sut.presentParentalGate(.init(question: nil, state: .failed))
        XCTAssertEqual(spy.parentalGateVM?.state, "failed")
    }

    func test_presentParentalGate_nilQuestion_usesDefault() async {
        let (sut, spy) = makeSUT()
        await sut.presentParentalGate(.init(question: nil, state: .waiting))
        XCTAssertFalse(spy.parentalGateVM?.questionText.isEmpty ?? true)
    }

    // MARK: - presentAnonymousUpgrade

    func test_presentAnonymousUpgrade_successMessageNotEmpty() async {
        let (sut, spy) = makeSUT()
        let user = makeUser(displayName: "Гость")
        await sut.presentAnonymousUpgrade(.init(user: user))
        XCTAssertFalse(spy.anonymousUpgradeVM?.successMessage.isEmpty ?? true)
    }

    // MARK: - presentTooManyFailedAttempts

    func test_presentTooManyFailedAttempts_messageContainsCount() async {
        let (sut, spy) = makeSUT()
        await sut.presentTooManyFailedAttempts(.init(count: 5))
        XCTAssertFalse(spy.tooManyFailedVM?.message.isEmpty ?? true)
    }

    // MARK: - presentDeleteAccountGateRequired

    func test_presentDeleteAccountGateRequired_messageNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentDeleteAccountGateRequired(.init())
        XCTAssertFalse(spy.deleteGateRequiredVM?.message.isEmpty ?? true)
    }
}
