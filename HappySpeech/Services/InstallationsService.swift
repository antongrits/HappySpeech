import FirebaseInstallations
import Foundation
import OSLog

// MARK: - Protocol

/// Отслеживает идентичность установки приложения через Firebase Installations.
///
/// Используется для корреляции сессий Anonymous → Email/Google upgrade:
/// когда пользователь переходит с анонимного аккаунта на постоянный,
/// `InstallationsService` сохраняет `installationID` в профиль,
/// что позволяет аналитике связать сессии до и после апгрейда.
///
/// > Important: Installation ID **не содержит** PII и не попадает под COPPA.
/// > Это случайный идентификатор на уровне установки, не привязанный к ребёнку.
/// > Не хранить Installation ID в детских профилях.
///
/// ## Пример
/// ```swift
/// let id = try await installations.currentInstallationID()
/// // id = "fL4RhFMqNFmvnLH5Zi2KeO"
///
/// // После перехода anonymous → email:
/// try await installations.upgradeToAuthUser(uid: newUid)
/// ```
///
/// ## See Also
/// - ``AuthService`` — работа с аутентификацией
/// - ``LiveAuthService`` — реализация Anonymous sign-in и linkAnonymousWithEmail
public protocol InstallationsServiceProtocol: AnyObject, Sendable {

    /// Возвращает текущий Firebase Installation ID.
    ///
    /// ID создаётся при первом запуске и сохраняется в Keychain.
    /// Стабилен между запусками, сбрасывается при удалении приложения.
    ///
    /// - Returns: Строковый идентификатор установки (22 символа, base64url).
    /// - Throws: `InstallationsError` если Firebase не инициализирован.
    func currentInstallationID() async throws -> String

    /// Получает актуальный Firebase Installation Auth Token.
    ///
    /// Токен используется при вызовах Cloud Functions для верификации
    /// что запрос исходит от легитимной установки приложения.
    ///
    /// - Parameter forceRefresh: Если `true`, принудительно обновляет токен.
    /// - Returns: JWT-строка токена.
    /// - Throws: `InstallationsError`.
    func authToken(forceRefresh: Bool) async throws -> String

    /// Вызывается при апгрейде Anonymous → Email/Google.
    ///
    /// Записывает Installation ID в Firestore `/users/{uid}/installationId`
    /// для аналитики преемственности сессий (только родительский контур).
    ///
    /// - Parameter uid: Идентификатор нового аутентифицированного пользователя.
    /// - Throws: `InstallationsError` или Firestore ошибка.
    func upgradeToAuthUser(uid: String) async throws

    /// Удаляет текущую установку из Firebase.
    ///
    /// После вызова при следующем запуске будет создан новый Installation ID.
    /// Вызывать при удалении аккаунта (`AuthService.deleteAccount()`).
    func deleteInstallation() async throws
}

// MARK: - Errors

public enum InstallationsError: LocalizedError, Sendable {
    case notInitialized
    case tokenUnavailable
    case syncFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Firebase не инициализирован. Убедитесь что FirebaseApp.configure() вызван."
        case .tokenUnavailable:
            return "Токен установки недоступен."
        case .syncFailed(let detail):
            return "Не удалось синхронизировать данные установки: \(detail)"
        }
    }
}

// MARK: - Live Implementation

/// Продакшн-реализация через `Installations.installations()`.
///
/// `@unchecked Sendable` оправдан: `Installations` — Firebase singleton,
/// thread-safe внутри SDK. Логгер создаётся один раз при init.
public final class LiveInstallationsService: InstallationsServiceProtocol, @unchecked Sendable {

    private let logger = Logger(subsystem: "com.happyspeech", category: "Installations")
    private let installations: Installations

    public init() {
        self.installations = Installations.installations()
    }

    // MARK: - InstallationsServiceProtocol

    public func currentInstallationID() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            installations.installationID { [weak self] id, error in
                if let error {
                    self?.logger.error("currentInstallationID failed: \(error.localizedDescription)")
                    continuation.resume(throwing: InstallationsError.notInitialized)
                    return
                }
                guard let id else {
                    continuation.resume(throwing: InstallationsError.tokenUnavailable)
                    return
                }
                self?.logger.info("Installation ID retrieved successfully")
                continuation.resume(returning: id)
            }
        }
    }

    public func authToken(forceRefresh: Bool) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            installations.authTokenForcingRefresh(forceRefresh) { [weak self] tokenResult, error in
                if let error {
                    self?.logger.error("authToken failed: \(error.localizedDescription)")
                    continuation.resume(throwing: InstallationsError.tokenUnavailable)
                    return
                }
                guard let token = tokenResult?.authToken else {
                    continuation.resume(throwing: InstallationsError.tokenUnavailable)
                    return
                }
                self?.logger.info("Installation auth token retrieved (forceRefresh=\(forceRefresh))")
                continuation.resume(returning: token)
            }
        }
    }

    public func upgradeToAuthUser(uid: String) async throws {
        guard !uid.isEmpty else {
            logger.warning("upgradeToAuthUser: empty uid, skipping")
            return
        }
        do {
            let installationID = try await currentInstallationID()
            // Импортируем Firestore только локально чтобы не создавать циклическую зависимость.
            // Записываем installation_id для аналитики преемственности анонимных сессий.
            // Этот вызов безопасен для COPPA — не содержит PII, только технический идентификатор.
            let db = FirestoreProxy.shared
            try await db.setInstallationID(installationID, forUser: uid)
            logger.info("Installation ID synced for upgraded user (uid redacted)")
        } catch {
            logger.error("upgradeToAuthUser failed: \(error.localizedDescription)")
            throw InstallationsError.syncFailed(error.localizedDescription)
        }
    }

    public func deleteInstallation() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            installations.delete { [weak self] error in
                if let error {
                    self?.logger.error("deleteInstallation failed: \(error.localizedDescription)")
                    continuation.resume(throwing: InstallationsError.syncFailed(error.localizedDescription))
                    return
                }
                self?.logger.info("Installation deleted successfully")
                continuation.resume()
            }
        }
    }
}

// MARK: - Firestore bridge

import FirebaseFirestore

// MARK: - FirestoreProxy (internal helper)

/// Изолированный прокси для записи в Firestore из InstallationsService.
///
/// Использует `Firestore` напрямую — без зависимости от SyncService,
/// чтобы не создавать циклическую зависимость в DI-контейнере.
/// Запись производится только в родительский документ (`/users/{uid}`), не в детский профиль.
private final class FirestoreProxy: @unchecked Sendable {
    static let shared = FirestoreProxy()
    private init() {}

    func setInstallationID(_ installationID: String, forUser uid: String) async throws {
        let db = Firestore.firestore()
        try await db
            .collection("users")
            .document(uid)
            .setData(
                [
                    "installationId": installationID,
                    "installationIdUpdatedAt": FieldValue.serverTimestamp()
                ],
                merge: true
            )
    }
}

// MARK: - Mock

/// Preview / test реализация с детерминированными ответами.
public final class MockInstallationsService: InstallationsServiceProtocol, @unchecked Sendable {
    public var stubbedInstallationID: String = "mock-installation-id-12345"
    public var stubbedAuthToken: String = "mock-auth-token-abcde"
    public var shouldThrowError: Bool = false
    public var didUpgrade: Bool = false
    public var didDelete: Bool = false

    public init() {}

    public func currentInstallationID() async throws -> String {
        if shouldThrowError { throw InstallationsError.notInitialized }
        return stubbedInstallationID
    }

    public func authToken(forceRefresh: Bool) async throws -> String {
        if shouldThrowError { throw InstallationsError.tokenUnavailable }
        return stubbedAuthToken
    }

    public func upgradeToAuthUser(uid: String) async throws {
        if shouldThrowError { throw InstallationsError.syncFailed("Mock error") }
        didUpgrade = true
    }

    public func deleteInstallation() async throws {
        if shouldThrowError { throw InstallationsError.syncFailed("Mock delete error") }
        didDelete = true
    }
}
