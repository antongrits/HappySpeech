import FirebaseFunctions
import Foundation
import OSLog

// MARK: - Result Models

/// Токен семейного приглашения, заменяющий deprecated Firebase Dynamic Links.
///
/// Создаётся через Cloud Function `createFamilyInviteToken`. Документ хранится
/// в Firestore (`/family_invites/{token}`), а ссылка резолвится через Apple
/// Universal Links (Associated Domains).
///
/// См. `FamilyInviteService` и ADR-V18-U-DYNAMICLINKS-REPLACE.
public struct FamilyInviteToken: Sendable, Equatable {
    /// Технический токен (32 символа hex) — primary key документа в Firestore.
    public let token: String
    /// Короткий 6-символьный код для ручного ввода (например "K7M2X9").
    public let shortCode: String
    /// Время истечения (Unix timestamp в секундах).
    public let expiresAt: Date
    /// Universal Link URL для ShareSheet.
    public let deepLinkURL: URL

    public init(token: String, shortCode: String, expiresAt: Date, deepLinkURL: URL) {
        self.token = token
        self.shortCode = shortCode
        self.expiresAt = expiresAt
        self.deepLinkURL = deepLinkURL
    }
}

// MARK: - Protocol

/// Вызов облачных функций Firebase для операций, требующих серверной стороны.
///
/// Все функции задеплоены в регион `europe-west3` (ближайший к RU-аудитории).
/// Каждый вызов защищён App Check — запросы без валидной аттестации отклоняются.
///
/// > Important: Оценка произношения выполняется **исключительно on-device**
/// > через `PronunciationScorerService` (Core ML, COPPA-compliant).
/// > Аудио ребёнка не передаётся на сервер.
///
/// ## See Also
/// - ``FamilyInviteService`` — использует `createFamilyInviteToken`
/// - ``PronunciationScorerService`` — on-device оценка произношения
public protocol CloudFunctionsServiceProtocol: AnyObject, Sendable {

    /// Создаёт токен семейного приглашения через Firestore.
    ///
    /// Заменяет deprecated Firebase Dynamic Links (sunset 2025-08-25).
    /// Создаёт single-use Firestore document (`/family_invites/{token}`)
    /// и возвращает Universal Link для ShareSheet.
    ///
    /// - Parameters:
    ///   - parentId: Идентификатор родителя (должен совпадать с auth uid).
    ///   - role: Роль приглашённого: `.secondary` | `.observer`.
    ///   - durationHours: Срок жизни в часах (1-168, дефолт 24).
    /// - Returns: `FamilyInviteToken` с токеном, коротким кодом и URL.
    /// - Throws: `CloudFunctionsError`.
    func createFamilyInviteToken(
        parentId: String,
        role: ParentRole,
        durationHours: Int
    ) async throws -> FamilyInviteToken
}

// MARK: - Errors

public enum CloudFunctionsError: LocalizedError, Sendable {
    case appCheckFailed
    case invalidResponse(String)
    case serverError(String)
    case networkUnavailable

    public var errorDescription: String? {
        switch self {
        case .appCheckFailed:
            return "Проверка устройства не прошла. Попробуйте позже."
        case .invalidResponse(let detail):
            return "Неверный ответ сервера: \(detail)"
        case .serverError(let message):
            return "Ошибка сервера: \(message)"
        case .networkUnavailable:
            return "Нет соединения с интернетом."
        }
    }
}

// MARK: - Live Implementation

/// Продакшн-реализация `CloudFunctionsServiceProtocol`.
///
/// Использует `Functions.functions(region:)` с регионом `europe-west3`.
/// App Check enforcement активируется автоматически если в `FirebaseApp.configure()`
/// настроен `AppCheck` провайдер (`DeviceCheckProvider` / `AppAttestProvider`).
public final class LiveCloudFunctionsService: CloudFunctionsServiceProtocol, @unchecked Sendable {

    private let logger = Logger(subsystem: "com.happyspeech", category: "CloudFunctions")
    private let functions: Functions

    /// - Parameter region: Регион Cloud Functions. Дефолт: `europe-west3`.
    public init(region: String = "europe-west3") {
        self.functions = Functions.functions(region: region)
    }

    // MARK: - CloudFunctionsServiceProtocol

    public func createFamilyInviteToken(
        parentId: String,
        role: ParentRole,
        durationHours: Int
    ) async throws -> FamilyInviteToken {
        guard !parentId.isEmpty else {
            throw CloudFunctionsError.invalidResponse("parentId не может быть пустым")
        }
        let resolvedDuration = max(1, min(durationHours, 168))

        let callable = functions.httpsCallable("createFamilyInviteToken")
        let payload: [String: Any] = [
            "parentId": parentId,
            "role": role.rawValue,
            "durationHours": resolvedDuration
        ]

        do {
            let result = try await callable.call(payload)
            return try parseInviteToken(result.data)
        } catch {
            logger.error("createFamilyInviteToken error: \(error.localizedDescription)")
            throw mapError(error)
        }
    }

    // MARK: - Private Helpers

    private func parseInviteToken(_ data: Any) throws -> FamilyInviteToken {
        guard let dict = data as? [String: Any] else {
            throw CloudFunctionsError.invalidResponse("ожидался объект, получено: \(type(of: data))")
        }
        guard
            let token = dict["token"] as? String,
            let shortCode = dict["shortCode"] as? String,
            let urlString = dict["deepLinkURL"] as? String,
            let url = URL(string: urlString)
        else {
            throw CloudFunctionsError.invalidResponse("отсутствуют обязательные поля токена")
        }
        let expiresTimestamp: Double
        if let value = dict["expiresAt"] as? Double {
            expiresTimestamp = value
        } else if let value = dict["expiresAt"] as? Int {
            expiresTimestamp = Double(value)
        } else {
            expiresTimestamp = Date().addingTimeInterval(24 * 3600).timeIntervalSince1970
        }
        let expiresAt = Date(timeIntervalSince1970: expiresTimestamp)

        logger.info("createFamilyInviteToken result: shortCode=\(shortCode), expiresAt=\(expiresAt.description)")
        return FamilyInviteToken(
            token: token,
            shortCode: shortCode,
            expiresAt: expiresAt,
            deepLinkURL: url
        )
    }

    private func mapError(_ error: Error) -> CloudFunctionsError {
        let nsError = error as NSError
        guard nsError.domain == FunctionsErrorDomain else {
            return .serverError(error.localizedDescription)
        }
        let code = FunctionsErrorCode(rawValue: nsError.code) ?? .internal
        switch code {
        case .unauthenticated, .permissionDenied:
            return .appCheckFailed
        case .unavailable, .deadlineExceeded:
            return .networkUnavailable
        default:
            return .serverError(nsError.localizedDescription)
        }
    }
}

// MARK: - Mock

/// Preview / test реализация. Детерминированные ответы без сети.
public final class MockCloudFunctionsService: CloudFunctionsServiceProtocol, @unchecked Sendable {

    public var stubbedInviteToken: FamilyInviteToken = FamilyInviteToken(
        token: "mock-token-deadbeef00000000deadbeef00000000",
        shortCode: "ABCD23",
        expiresAt: Date().addingTimeInterval(24 * 3600),
        // swiftlint:disable:next force_unwrapping
        deepLinkURL: URL(string: "https://happyspeech.mmf.bsu.app/invite?token=mock&code=ABCD23")!
    )

    public var shouldThrowError: Bool = false

    public init() {}

    public func createFamilyInviteToken(
        parentId: String,
        role: ParentRole,
        durationHours: Int
    ) async throws -> FamilyInviteToken {
        if shouldThrowError { throw CloudFunctionsError.serverError("Mock error") }
        return stubbedInviteToken
    }
}
