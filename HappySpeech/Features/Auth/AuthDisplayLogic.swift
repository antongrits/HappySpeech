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
}
