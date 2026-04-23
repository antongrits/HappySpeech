import Foundation

// MARK: - EmailAuthWorker

/// Thin wrapper around `AuthService` for email+password operations.
/// Keeps `AuthInteractor` focused on orchestration, not on service call plumbing.
@MainActor
final class EmailAuthWorker {

    private let authService: any AuthService

    init(authService: any AuthService) {
        self.authService = authService
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        try validate(email: trimmed, password: password)
        return try await authService.signIn(email: trimmed, password: password)
    }

    func signUp(email: String, password: String, displayName: String) async throws -> AuthUser {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        try validate(email: trimmedEmail, password: password)
        guard !trimmedName.isEmpty else { throw AppError.authSignInFailed(String(localized: "Имя не может быть пустым.")) }
        return try await authService.signUp(email: trimmedEmail, password: password, displayName: trimmedName)
    }

    func sendPasswordReset(email: String) async throws {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isValidEmail else { throw AppError.authInvalidCredential }
        try await authService.sendPasswordReset(email: trimmed)
    }

    // MARK: - Validation

    private func validate(email: String, password: String) throws {
        guard email.isValidEmail else { throw AppError.authInvalidCredential }
        guard password.count >= 6 else { throw AppError.authWeakPassword }
    }
}
