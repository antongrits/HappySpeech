import Foundation

// MARK: - AuthPresentationLogic

@MainActor
protocol AuthPresentationLogic: AnyObject {
    func presentAuthState(_ response: AuthModels.AuthState.Response) async
    func presentSignIn(_ response: AuthModels.SignIn.Response) async
    func presentSignUp(_ response: AuthModels.SignUp.Response) async
    func presentGoogleSignIn(_ response: AuthModels.GoogleSignIn.Response) async
    func presentForgotPassword(_ response: AuthModels.ForgotPassword.Response) async
    func presentEmailVerification(_ response: AuthModels.EmailVerification.Response) async
    func presentResendVerification(_ response: AuthModels.ResendVerification.Response) async
    func presentSignOut(_ response: AuthModels.SignOut.Response) async
    func presentDeleteAccount(_ response: AuthModels.DeleteAccount.Response) async
    func presentError(_ error: any Error) async
    // MARK: D.1 v15 — новые методы
    func presentParentalGate(_ response: AuthModels.ParentalGate.Response) async
    func presentAnonymousUpgrade(_ response: AuthModels.AnonymousUpgrade.Response) async
    func presentTooManyFailedAttempts(_ response: AuthModels.TooManyFailedAttempts.Response) async
    func presentDeleteAccountGateRequired(_ response: AuthModels.DeleteAccountGateRequired.Response) async
}

// MARK: - AuthDisplayLogic

@MainActor
protocol AuthDisplayLogic: AnyObject {
    func displayAuthState(_ viewModel: AuthModels.AuthState.ViewModel)
    func displaySignIn(_ viewModel: AuthModels.SignIn.ViewModel)
    func displaySignUp(_ viewModel: AuthModels.SignUp.ViewModel)
    func displayGoogleSignIn(_ viewModel: AuthModels.GoogleSignIn.ViewModel)
    func displayForgotPassword(_ viewModel: AuthModels.ForgotPassword.ViewModel)
    func displayEmailVerification(_ viewModel: AuthModels.EmailVerification.ViewModel)
    func displayResendVerification(_ viewModel: AuthModels.ResendVerification.ViewModel)
    func displaySignOut(_ viewModel: AuthModels.SignOut.ViewModel)
    func displayDeleteAccount(_ viewModel: AuthModels.DeleteAccount.ViewModel)
    func displayError(_ viewModel: AuthModels.ErrorViewModel)
    // MARK: D.1 v15 — новые методы
    func displayParentalGate(_ viewModel: AuthModels.ParentalGate.ViewModel)
    func displayAnonymousUpgrade(_ viewModel: AuthModels.AnonymousUpgrade.ViewModel)
    func displayTooManyFailedAttempts(_ viewModel: AuthModels.TooManyFailedAttempts.ViewModel)
    func displayDeleteAccountGateRequired(_ viewModel: AuthModels.DeleteAccountGateRequired.ViewModel)
}
