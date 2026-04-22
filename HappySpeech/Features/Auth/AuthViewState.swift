import Foundation
import Observation

// MARK: - AuthViewState

/// Shared @Observable state owned by Auth screens.
/// The `AuthPresenter` writes into this object via `AuthDisplayLogic`; the views observe it.
/// One instance is created per screen flow (sign-in / sign-up / forgot / verify).
@Observable
@MainActor
final class AuthViewState: AuthDisplayLogic {

    // MARK: - UI state
    var isLoading: Bool = false
    var error: AuthModels.ErrorViewModel?

    // MARK: - Flow outputs (nilable → view observes, triggers navigation on non-nil)
    var authStateViewModel: AuthModels.AuthState.ViewModel?
    var signInViewModel: AuthModels.SignIn.ViewModel?
    var signUpViewModel: AuthModels.SignUp.ViewModel?
    var googleSignInViewModel: AuthModels.GoogleSignIn.ViewModel?
    var forgotPasswordViewModel: AuthModels.ForgotPassword.ViewModel?
    var emailVerificationViewModel: AuthModels.EmailVerification.ViewModel?
    var resendVerificationViewModel: AuthModels.ResendVerification.ViewModel?
    var signOutViewModel: AuthModels.SignOut.ViewModel?
    var deleteAccountViewModel: AuthModels.DeleteAccount.ViewModel?

    // MARK: - AuthDisplayLogic

    func displayAuthState(_ viewModel: AuthModels.AuthState.ViewModel) {
        authStateViewModel = viewModel
        isLoading = false
    }

    func displaySignIn(_ viewModel: AuthModels.SignIn.ViewModel) {
        signInViewModel = viewModel
        isLoading = false
    }

    func displaySignUp(_ viewModel: AuthModels.SignUp.ViewModel) {
        signUpViewModel = viewModel
        isLoading = false
    }

    func displayGoogleSignIn(_ viewModel: AuthModels.GoogleSignIn.ViewModel) {
        googleSignInViewModel = viewModel
        isLoading = false
    }

    func displayForgotPassword(_ viewModel: AuthModels.ForgotPassword.ViewModel) {
        forgotPasswordViewModel = viewModel
        isLoading = false
    }

    func displayEmailVerification(_ viewModel: AuthModels.EmailVerification.ViewModel) {
        emailVerificationViewModel = viewModel
        isLoading = false
    }

    func displayResendVerification(_ viewModel: AuthModels.ResendVerification.ViewModel) {
        resendVerificationViewModel = viewModel
        isLoading = false
    }

    func displaySignOut(_ viewModel: AuthModels.SignOut.ViewModel) {
        signOutViewModel = viewModel
        isLoading = false
    }

    func displayDeleteAccount(_ viewModel: AuthModels.DeleteAccount.ViewModel) {
        deleteAccountViewModel = viewModel
        isLoading = false
    }

    func displayError(_ viewModel: AuthModels.ErrorViewModel) {
        error = viewModel
        isLoading = false
    }

    // MARK: - Helpers

    func beginLoading() {
        isLoading = true
        error = nil
    }

    func dismissError() {
        error = nil
    }
}

// MARK: - AuthScene

/// Bundles an Interactor+Presenter+ViewState triple for a single Auth screen.
/// Built by views via the `AppContainer.authService`.
@MainActor
final class AuthScene {
    let interactor: AuthInteractor
    let presenter: AuthPresenter
    let state: AuthViewState

    init(authService: any AuthService) {
        let interactor = AuthInteractor(authService: authService)
        let presenter = AuthPresenter()
        let state = AuthViewState()

        interactor.presenter = presenter
        presenter.viewModel = state

        self.interactor = interactor
        self.presenter = presenter
        self.state = state
    }
}
