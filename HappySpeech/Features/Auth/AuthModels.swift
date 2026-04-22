import Foundation
import UIKit

// MARK: - Auth VIP Models

enum AuthModels {

    // MARK: - Sign In (Email + Password)

    enum SignIn {
        struct Request {
            let email: String
            let password: String
        }
        struct Response {
            let user: AuthUser
        }
        struct ViewModel: Equatable {
            let welcomeMessage: String
            let requiresEmailVerification: Bool
        }
    }

    // MARK: - Sign Up

    enum SignUp {
        struct Request {
            let email: String
            let password: String
            let name: String
        }
        struct Response {
            let user: AuthUser
        }
        struct ViewModel: Equatable {
            let successMessage: String
            let email: String
        }
    }

    // MARK: - Google Sign-In

    enum GoogleSignIn {
        struct Request {}
        struct Response {
            let user: AuthUser
        }
        struct ViewModel: Equatable {
            let welcomeMessage: String
        }
    }

    // MARK: - Forgot Password

    enum ForgotPassword {
        struct Request {
            let email: String
        }
        struct Response {
            let email: String
        }
        struct ViewModel: Equatable {
            let successMessage: String
        }
    }

    // MARK: - Email Verification

    enum EmailVerification {
        struct Request {}
        struct Response {
            /// `true` if the email is now verified after reload.
            let isVerified: Bool
        }
        struct ViewModel: Equatable {
            let message: String
            let isVerified: Bool
        }
    }

    // MARK: - Resend Verification

    enum ResendVerification {
        struct Request {}
        struct Response {}
        struct ViewModel: Equatable {
            let message: String
            let id: UUID
            init(message: String, id: UUID = UUID()) {
                self.message = message
                self.id = id
            }
        }
    }

    // MARK: - Sign Out

    enum SignOut {
        struct Request {}
        struct Response {}
        struct ViewModel: Equatable {
            let id: UUID
            init(id: UUID = UUID()) { self.id = id }
        }
    }

    // MARK: - Delete Account

    enum DeleteAccount {
        struct Request {}
        struct Response {}
        struct ViewModel: Equatable {
            let id: UUID
            init(id: UUID = UUID()) { self.id = id }
        }
    }

    // MARK: - Auth State

    enum AuthState {
        struct Request {}
        enum Response: Sendable, Equatable {
            case authenticated(AuthUser)
            case unauthenticated
        }
        struct ViewModel: Equatable {
            let isAuthenticated: Bool
            let isAnonymous: Bool
            let isEmailVerified: Bool
            let displayName: String?
        }
    }

    // MARK: - Error

    struct ErrorViewModel: Equatable {
        let title: String
        let message: String
    }
}
