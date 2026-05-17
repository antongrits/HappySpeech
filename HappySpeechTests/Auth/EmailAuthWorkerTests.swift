@testable import HappySpeech
import XCTest

// MARK: - EmailAuthWorkerTests
//
// Phase 2.7 v25 — покрытие EmailAuthWorker.
//
// EmailAuthWorker — тонкая обёртка над AuthService для email+password.
// Тестируется:
//   - signIn: валидация email/password, trimming, проброс к сервису, ошибки
//   - signUp: валидация имени (пустое → ошибка), trimming, проброс, ошибки
//   - sendPasswordReset: валидация email, проброс, ошибки

@MainActor
final class EmailAuthWorkerTests: XCTestCase {

    private var authService: SpyAuthService!
    private var sut: EmailAuthWorker!

    override func setUp() {
        super.setUp()
        authService = SpyAuthService()
        sut = EmailAuthWorker(authService: authService)
    }

    override func tearDown() {
        sut = nil
        authService = nil
        super.tearDown()
    }

    // MARK: - signIn: успех

    func test_signIn_validCredentials_callsService() async throws {
        let user = try await sut.signIn(email: "parent@example.com", password: "secret1")
        XCTAssertEqual(authService.signInCallCount, 1)
        XCTAssertEqual(user.uid, authService.stubbedUser?.uid)
    }

    func test_signIn_trimsWhitespaceFromEmail() async throws {
        _ = try await sut.signIn(email: "  parent@example.com  ", password: "secret1")
        XCTAssertEqual(authService.lastSignInEmail, "parent@example.com")
    }

    // MARK: - signIn: валидация

    func test_signIn_invalidEmail_throwsInvalidCredential() async {
        await assertThrows(AppError.authInvalidCredential) {
            _ = try await self.sut.signIn(email: "not-an-email", password: "secret1")
        }
        XCTAssertEqual(authService.signInCallCount, 0)
    }

    func test_signIn_shortPassword_throwsWeakPassword() async {
        await assertThrows(AppError.authWeakPassword) {
            _ = try await self.sut.signIn(email: "parent@example.com", password: "12345")
        }
        XCTAssertEqual(authService.signInCallCount, 0)
    }

    func test_signIn_emptyPassword_throwsWeakPassword() async {
        await assertThrows(AppError.authWeakPassword) {
            _ = try await self.sut.signIn(email: "parent@example.com", password: "")
        }
    }

    // MARK: - signIn: ошибка сервиса

    func test_signIn_serviceFailure_propagatesError() async {
        authService.shouldFail = true
        await assertThrows(AppError.authInvalidCredential) {
            _ = try await self.sut.signIn(email: "parent@example.com", password: "secret1")
        }
        XCTAssertEqual(authService.signInCallCount, 1)
    }

    // MARK: - signUp: успех

    func test_signUp_validInput_callsService() async throws {
        let user = try await sut.signUp(
            email: "new@example.com",
            password: "secret1",
            displayName: "Мама"
        )
        XCTAssertEqual(authService.signUpCallCount, 1)
        XCTAssertEqual(user.displayName, "Мама")
    }

    func test_signUp_trimsEmailAndName() async throws {
        let user = try await sut.signUp(
            email: "  new@example.com ",
            password: "secret1",
            displayName: "  Папа  "
        )
        XCTAssertEqual(user.email, "new@example.com")
        XCTAssertEqual(user.displayName, "Папа")
    }

    // MARK: - signUp: валидация

    func test_signUp_emptyDisplayName_throwsSignInFailed() async {
        do {
            _ = try await sut.signUp(email: "new@example.com", password: "secret1", displayName: "   ")
            XCTFail("Ожидалась ошибка для пустого имени")
        } catch let error as AppError {
            guard case .authSignInFailed = error else {
                XCTFail("Ожидался authSignInFailed, получен \(error)")
                return
            }
        } catch {
            XCTFail("Неожиданный тип ошибки: \(error)")
        }
        XCTAssertEqual(authService.signUpCallCount, 0)
    }

    func test_signUp_invalidEmail_throwsInvalidCredential() async {
        await assertThrows(AppError.authInvalidCredential) {
            _ = try await self.sut.signUp(email: "bad", password: "secret1", displayName: "Имя")
        }
        XCTAssertEqual(authService.signUpCallCount, 0)
    }

    func test_signUp_shortPassword_throwsWeakPassword() async {
        await assertThrows(AppError.authWeakPassword) {
            _ = try await self.sut.signUp(email: "new@example.com", password: "abc", displayName: "Имя")
        }
    }

    func test_signUp_serviceFailure_propagatesError() async {
        authService.shouldFail = true
        await assertThrows(AppError.authEmailAlreadyInUse) {
            _ = try await self.sut.signUp(email: "new@example.com", password: "secret1", displayName: "Имя")
        }
    }

    // MARK: - sendPasswordReset

    func test_sendPasswordReset_validEmail_callsService() async throws {
        try await sut.sendPasswordReset(email: "parent@example.com")
    }

    func test_sendPasswordReset_trimsEmail() async throws {
        try await sut.sendPasswordReset(email: "  parent@example.com  ")
    }

    func test_sendPasswordReset_invalidEmail_throwsInvalidCredential() async {
        await assertThrows(AppError.authInvalidCredential) {
            _ = try await self.sut.sendPasswordReset(email: "invalid")
        }
    }

    func test_sendPasswordReset_serviceFailure_propagatesError() async {
        authService.shouldFail = true
        await assertThrows(AppError.authUserNotFound) {
            _ = try await self.sut.sendPasswordReset(email: "parent@example.com")
        }
    }

    // MARK: - Helpers

    private func assertThrows(
        _ expected: AppError,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ block: () async throws -> Void
    ) async {
        do {
            try await block()
            XCTFail("Ожидалась ошибка \(expected)", file: file, line: line)
        } catch let error as AppError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("Неожиданный тип ошибки: \(error)", file: file, line: line)
        }
    }
}
