@testable import HappySpeech
import XCTest

// MARK: - AuthFlowTests
//
// Integration-тесты Auth flow через MockAuthService.
// Тесты воспроизводят контракт Firebase Auth (signup/login/logout/reset)
// без подключения к реальному Firebase SDK.
//
// Auth Emulator (localhost:9099) REST API проверяется там, где
// возможно использование HTTP без Firebase iOS SDK.

final class AuthFlowTests: FirebaseEmulatorTestsBase {

    // MARK: - 1. Auth Emulator доступен

    func test_authEmulator_isReachable() async {
        let available = await checkAuthEmulatorAvailable()
        if !available {
            XCTExpectFailure("Auth emulator не запущен — тест пропускается")
            XCTFail("Auth emulator недоступен на localhost:9099")
            return
        }
        XCTAssertTrue(available, "Auth emulator должен отвечать на localhost:9099")
    }

    // MARK: - 2. Email signup → новый пользователь создан

    func test_emailSignUp_createsUser() async throws {
        let user = try await mockAuthService.signUp(
            email: "test@happyspeech.ru",
            password: "Test1234!",
            displayName: "Иван Иванов"
        )
        XCTAssertFalse(user.uid.isEmpty, "UID не должен быть пустым")
        XCTAssertEqual(user.email, "test@happyspeech.ru")
        XCTAssertEqual(user.displayName, "Иван Иванов")
        XCTAssertFalse(user.isAnonymous, "Новый пользователь не должен быть анонимным")
        XCTAssertFalse(user.isEmailVerified, "Email не верифицирован сразу после регистрации")
    }

    // MARK: - 3. Email signup → currentUser обновлён

    func test_emailSignUp_updatesCurrentUser() async throws {
        _ = try await mockAuthService.signUp(
            email: "current@happyspeech.ru",
            password: "Current123!",
            displayName: "Текущий"
        )
        let current = mockAuthService.currentUser
        XCTAssertNotNil(current, "currentUser должен быть установлен после signup")
        XCTAssertEqual(current?.email, "current@happyspeech.ru")
    }

    // MARK: - 4. Email login → успешный вход

    func test_emailSignIn_success_returnsUser() async throws {
        let user = try await mockAuthService.signIn(
            email: "login@happyspeech.ru",
            password: "Login123!"
        )
        XCTAssertFalse(user.uid.isEmpty, "UID не должен быть пустым")
        XCTAssertEqual(user.email, "login@happyspeech.ru")
    }

    // MARK: - 5. Email login с неверным паролем → ошибка

    func test_emailSignIn_wrongCredentials_throws() async {
        mockAuthService.shouldFail = true
        do {
            _ = try await mockAuthService.signIn(email: "bad@test.ru", password: "wrong")
            XCTFail("Должна быть ошибка при неверных кредентиалах")
        } catch {
            XCTAssertTrue(true, "Ошибка аутентификации корректно возбрасывается")
        }
    }

    // MARK: - 6. Logout → currentUser становится nil

    func test_signOut_clearsCurrentUser() async throws {
        _ = try await mockAuthService.signIn(email: "logout@test.ru", password: "Logout123!")
        XCTAssertNotNil(mockAuthService.currentUser, "После signin пользователь должен быть установлен")

        try mockAuthService.signOut()
        XCTAssertNil(mockAuthService.currentUser, "После signOut currentUser должен быть nil")
    }

    // MARK: - 7. Password reset → не бросает для валидного email

    func test_sendPasswordReset_validEmail_noThrow() async {
        do {
            try await mockAuthService.sendPasswordReset(email: "reset@happyspeech.ru")
        } catch {
            XCTFail("sendPasswordReset не должен бросать для валидного email: \(error)")
        }
    }

    // MARK: - 8. Password reset с shouldFail → бросает ошибку

    func test_sendPasswordReset_shouldFail_throws() async {
        mockAuthService.shouldFail = true
        do {
            try await mockAuthService.sendPasswordReset(email: "notfound@test.ru")
            XCTFail("Должна быть ошибка при shouldFail=true")
        } catch {
            XCTAssertTrue(true, "Ошибка корректно возбрасывается")
        }
    }

    // MARK: - 9. Anonymous signIn → isAnonymous = true

    func test_signInAnonymously_isAnonymousTrue() async throws {
        let user = try await mockAuthService.signInAnonymously()
        XCTAssertTrue(user.isAnonymous, "Анонимный пользователь должен иметь isAnonymous=true")
        XCTAssertFalse(user.uid.isEmpty, "UID анонимного пользователя не должен быть пустым")
    }

    // MARK: - 10. Auth state listener → вызывается при смене пользователя

    func test_authStateListener_calledOnUserChange() async throws {
        // Swift 6 concurrency: nonisolated(unsafe) чтобы захватить переменную из Sendable listener
        nonisolated(unsafe) var capturedUser: AuthUser?
        let handle = mockAuthService.addAuthStateListener { user in
            capturedUser = user
        }
        defer { mockAuthService.removeAuthStateListener(handle) }

        _ = try await mockAuthService.signIn(email: "listener@test.ru", password: "Listen123!")

        // Даём listener время сработать
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertNotNil(capturedUser, "Auth state listener должен быть вызван после signIn")
    }

    // MARK: - 11. reloadCurrentUser → возвращает актуального пользователя

    func test_reloadCurrentUser_returnsUpdatedUser() async throws {
        _ = try await mockAuthService.signIn(email: "reload@test.ru", password: "Reload123!")
        let reloaded = try await mockAuthService.reloadCurrentUser()
        XCTAssertNotNil(reloaded, "reloadCurrentUser должен вернуть пользователя")
    }

    // MARK: - 12. Auth Emulator REST — проверить openapi spec

    func test_authEmulator_openApiSpec_available() async throws {
        let available = await checkAuthEmulatorAvailable()
        if !available {
            XCTExpectFailure("Auth emulator не запущен — REST-проверка openapi.json пропускается")
            XCTFail("Auth emulator недоступен на localhost:9099 — запустите: firebase emulators:start --only auth")
            return
        }

        guard let url = URL(string: "\(Self.authEmulatorHost)/emulator/openapi.json") else {
            XCTFail("Невалидный URL")
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        XCTAssertEqual(code, 200, "Auth emulator openapi.json должен вернуть 200")
        XCTAssertFalse(data.isEmpty, "openapi.json не должен быть пустым")
    }

    // MARK: - 13. deleteAccount → currentUser становится nil

    func test_deleteAccount_clearsCurrentUser() async throws {
        _ = try await mockAuthService.signIn(email: "delete@test.ru", password: "Delete123!")
        XCTAssertNotNil(mockAuthService.currentUser)

        try await mockAuthService.deleteAccount()
        XCTAssertNil(mockAuthService.currentUser, "После deleteAccount currentUser должен быть nil")
    }
}
