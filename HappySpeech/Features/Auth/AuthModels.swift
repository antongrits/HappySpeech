import Foundation
import UIKit

// MARK: - ParentalGateQuestion

/// Математическая задача для COPPA parental gate.
struct ParentalGateQuestion: Sendable, Equatable {
    let displayText: String
    let correctAnswer: Int
}

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
        struct Request {
            /// Пропустить parental gate (используется когда gate уже прошли ранее в этой сессии).
            let skipGate: Bool
            init(skipGate: Bool = false) { self.skipGate = skipGate }
        }
        struct Response {}
        struct ViewModel: Equatable {
            let id: UUID
            init(id: UUID = UUID()) { self.id = id }
        }
    }

    // MARK: - Parental Gate (COPPA)

    enum ParentalGate {
        enum Action {
            case generateQuestion
            case submitAnswer(Int)
        }
        struct Request {
            let action: Action
        }
        enum GateState {
            case waiting, passed, failed
        }
        struct Response {
            let question: ParentalGateQuestion?
            let state: GateState
        }
        struct ViewModel: Equatable {
            let questionText: String
            let state: String  // "waiting" | "passed" | "failed"
        }
    }

    // MARK: - Anonymous Account Upgrade

    enum AnonymousUpgrade {
        struct Request {
            let email: String
            let password: String
            let displayName: String
        }
        struct Response {
            let user: AuthUser
        }
        struct ViewModel: Equatable {
            let successMessage: String
        }
    }

    // MARK: - Too Many Failed Attempts

    enum TooManyFailedAttempts {
        struct Response {
            let count: Int
        }
        struct ViewModel: Equatable {
            let message: String
        }
    }

    // MARK: - Delete Account Gate Required

    enum DeleteAccountGateRequired {
        struct Response {}
        struct ViewModel: Equatable {
            let message: String
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
