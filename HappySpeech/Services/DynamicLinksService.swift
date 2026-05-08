import FirebaseDynamicLinks
import Foundation
import OSLog

// MARK: - Models

/// Роль родителя в семейном профиле.
public enum ParentRole: String, Sendable, CaseIterable {
    /// Основной родитель — создатель семьи, имеет полный доступ.
    case primary = "primary"
    /// Второй родитель / опекун — доступ к чтению прогресса и просмотру сессий.
    case secondary = "secondary"
    /// Приглашённый наблюдатель — только чтение прогресса (бабушки/дедушки).
    case observer = "observer"
}

/// Payload из входящей Dynamic Link — содержит параметры приглашения.
public struct DynamicLinkPayload: Sendable, Equatable {
    /// Тип ссылки: "family_invite" | "specialist_access" | "content_share".
    public let linkType: String
    /// Идентификатор семейной группы.
    public let familyId: String?
    /// Роль приглашённого участника.
    public let role: ParentRole?
    /// Идентификатор приглашающего пользователя (для валидации на сервере).
    public let inviterUid: String?
    /// Время жизни приглашения (Unix timestamp).
    public let expiresAt: Date?
    /// Произвольные дополнительные параметры из deep link URL.
    public let extraParams: [String: String]

    public init(
        linkType: String,
        familyId: String? = nil,
        role: ParentRole? = nil,
        inviterUid: String? = nil,
        expiresAt: Date? = nil,
        extraParams: [String: String] = [:]
    ) {
        self.linkType = linkType
        self.familyId = familyId
        self.role = role
        self.inviterUid = inviterUid
        self.expiresAt = expiresAt
        self.extraParams = extraParams
    }
}

// MARK: - Errors

public enum DynamicLinksError: LocalizedError, Sendable {
    case invalidConfiguration
    case linkCreationFailed(String)
    case linkResolutionFailed(String)
    case expiredLink
    case invalidPayload(String)

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Настройки Dynamic Links не заданы. Проверьте GoogleService-Info.plist."
        case .linkCreationFailed(let detail):
            return "Не удалось создать ссылку-приглашение: \(detail)"
        case .linkResolutionFailed(let detail):
            return "Не удалось обработать входящую ссылку: \(detail)"
        case .expiredLink:
            return "Срок действия ссылки-приглашения истёк."
        case .invalidPayload(let detail):
            return "Неверный формат ссылки: \(detail)"
        }
    }
}

// MARK: - Protocol

/// Создание и обработка Firebase Dynamic Links для семейных приглашений.
///
/// Родитель может пригласить второго родителя или наблюдателя в семейный профиль
/// через универсальную ссылку. Dynamic Link корректно открывает приложение
/// на устройствах с установленным HappySpeech и ведёт в App Store если нет.
///
/// > Important: Dynamic Links используются **только** в родительском контуре.
/// > Дети не получают и не отправляют ссылки (COPPA).
///
/// ## Пример создания ссылки
/// ```swift
/// let url = try await dynamicLinks.createFamilyInviteLink(
///     familyId: "fam-abc123",
///     role: .secondary
/// )
/// // Отправить url через ShareSheet
/// ```
///
/// ## Пример обработки входящей ссылки (в AppDelegate / SceneDelegate)
/// ```swift
/// func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) {
///     for context in urlContexts {
///         Task {
///             let payload = try await dynamicLinks.handleIncomingLink(context.url)
///             // Роутинг на основе payload.linkType
///         }
///     }
/// }
/// ```
///
/// ## See Also
/// - ``InstallationsService`` — идентификация установки при обработке ссылки
/// - ``AuthService`` — аутентификация нового участника семьи
public protocol DynamicLinksServiceProtocol: AnyObject, Sendable {

    /// Создаёт Dynamic Link для приглашения в семейный профиль.
    ///
    /// Ссылка содержит `familyId` и `role` в query-параметрах.
    /// Срок жизни: 7 дней (настраивается через Remote Config).
    ///
    /// - Parameters:
    ///   - familyId: Идентификатор семейного профиля.
    ///   - role: Роль приглашённого участника.
    /// - Returns: Короткий Dynamic Link URL для передачи через ShareSheet.
    /// - Throws: `DynamicLinksError`.
    func createFamilyInviteLink(familyId: String, role: ParentRole) async throws -> URL

    /// Разбирает входящий Universal Link / Custom URL Scheme.
    ///
    /// Извлекает payload из параметров ссылки и валидирует срок жизни.
    ///
    /// - Parameter url: URL из `UIApplicationDelegate.application(_:open:options:)`.
    /// - Returns: `DynamicLinkPayload` с параметрами приглашения.
    /// - Throws: `DynamicLinksError.expiredLink` если срок истёк,
    ///   `DynamicLinksError.invalidPayload` если формат неверный.
    func handleIncomingLink(_ url: URL) async throws -> DynamicLinkPayload

    /// Создаёт ссылку доступа для логопеда-специалиста.
    ///
    /// Специалист получает временный read-only доступ к прогрессу ребёнка
    /// на период `durationDays` (по умолчанию 30 дней).
    ///
    /// - Parameters:
    ///   - childId: Идентификатор профиля ребёнка.
    ///   - specialistEmail: Email адрес логопеда для верификации.
    ///   - durationDays: Длительность доступа в днях.
    /// - Returns: Dynamic Link URL для передачи специалисту.
    /// - Throws: `DynamicLinksError`.
    func createSpecialistAccessLink(
        childId: String,
        specialistEmail: String,
        durationDays: Int
    ) async throws -> URL
}

// MARK: - Configuration

private enum DLConfig {
    /// Домен Dynamic Links из Firebase Console.
    /// Формат: "happyspeech.page.link"
    static let linkDomain = "happyspeech.page.link"

    /// Bundle ID приложения для App Store fallback.
    static let bundleID = "com.happyspeech.app"

    /// App Store ID (заменить на реальный после публикации).
    static let appStoreID = "0000000000"

    /// Базовый URL для deep link параметров.
    static let baseDeepLinkURL = "https://happyspeech.app/invite"

    /// Срок жизни семейного приглашения в секундах (7 дней).
    static let familyInviteTTL: TimeInterval = 7 * 24 * 3600

    /// Срок жизни ссылки специалиста в секундах (30 дней по умолчанию).
    static let defaultSpecialistTTL: TimeInterval = 30 * 24 * 3600
}

// MARK: - Live Implementation

/// Продакшн-реализация `DynamicLinksServiceProtocol`.
///
/// Создаёт `DynamicLinkComponents` с iOS-параметрами (App Store fallback, minimum version).
/// `@unchecked Sendable` оправдан: все методы stateless, `DynamicLinks.dynamicLinks()` thread-safe.
public final class LiveDynamicLinksService: DynamicLinksServiceProtocol, @unchecked Sendable {

    private let logger = Logger(subsystem: "com.happyspeech", category: "DynamicLinks")

    public init() {}

    // MARK: - DynamicLinksServiceProtocol

    public func createFamilyInviteLink(familyId: String, role: ParentRole) async throws -> URL {
        guard !familyId.isEmpty else {
            throw DynamicLinksError.invalidPayload("familyId не может быть пустым")
        }

        let expiresAt = Int(Date().addingTimeInterval(DLConfig.familyInviteTTL).timeIntervalSince1970)

        var components = URLComponents(string: DLConfig.baseDeepLinkURL)
        components?.queryItems = [
            URLQueryItem(name: "type", value: "family_invite"),
            URLQueryItem(name: "familyId", value: familyId),
            URLQueryItem(name: "role", value: role.rawValue),
            URLQueryItem(name: "expiresAt", value: "\(expiresAt)")
        ]

        guard let deepLink = components?.url else {
            throw DynamicLinksError.linkCreationFailed("Не удалось построить deep link URL")
        }

        return try await buildShortLink(deepLink: deepLink)
    }

    public func handleIncomingLink(_ url: URL) async throws -> DynamicLinkPayload {
        return try await withCheckedThrowingContinuation { continuation in
            DynamicLinks.dynamicLinks().handleUniversalLink(url) { [weak self] dynamicLink, error in
                guard let self else { return }

                if let error {
                    self.logger.error("handleIncomingLink error: \(error.localizedDescription)")
                    continuation.resume(throwing: DynamicLinksError.linkResolutionFailed(error.localizedDescription))
                    return
                }

                guard let dynamicLink, let linkURL = dynamicLink.url else {
                    // Попробуем разобрать как Custom URL Scheme напрямую
                    do {
                        let payload = try self.parseDeepLinkURL(url)
                        continuation.resume(returning: payload)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                    return
                }

                do {
                    let payload = try self.parseDeepLinkURL(linkURL)
                    self.logger.info("Dynamic link resolved: type=\(payload.linkType)")
                    continuation.resume(returning: payload)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func createSpecialistAccessLink(
        childId: String,
        specialistEmail: String,
        durationDays: Int
    ) async throws -> URL {
        guard !childId.isEmpty else {
            throw DynamicLinksError.invalidPayload("childId не может быть пустым")
        }
        guard specialistEmail.contains("@") else {
            throw DynamicLinksError.invalidPayload("Неверный формат email специалиста")
        }

        let resolvedDays = max(1, min(durationDays, 90))
        let expiresAt = Int(Date().addingTimeInterval(Double(resolvedDays) * 24 * 3600).timeIntervalSince1970)

        var components = URLComponents(string: DLConfig.baseDeepLinkURL)
        components?.queryItems = [
            URLQueryItem(name: "type", value: "specialist_access"),
            URLQueryItem(name: "childId", value: childId),
            URLQueryItem(name: "email", value: specialistEmail),
            URLQueryItem(name: "expiresAt", value: "\(expiresAt)")
        ]

        guard let deepLink = components?.url else {
            throw DynamicLinksError.linkCreationFailed("Не удалось построить deep link URL для специалиста")
        }

        return try await buildShortLink(deepLink: deepLink)
    }

    // MARK: - Private Helpers

    private func buildShortLink(deepLink: URL) async throws -> URL {
        guard let domainURIPrefix = URL(string: "https://\(DLConfig.linkDomain)") else {
            throw DynamicLinksError.invalidConfiguration
        }

        guard let components = DynamicLinkComponents(link: deepLink, domainURIPrefix: domainURIPrefix.absoluteString) else {
            throw DynamicLinksError.linkCreationFailed("DynamicLinkComponents init failed")
        }

        let iosParams = DynamicLinkIOSParameters(bundleID: DLConfig.bundleID)
        iosParams.appStoreID = DLConfig.appStoreID
        iosParams.minimumAppVersion = "1.0.0"
        components.iOSParameters = iosParams

        let androidParams = DynamicLinkAndroidParameters(packageName: "com.happyspeech.android")
        components.androidParameters = androidParams

        let socialParams = DynamicLinkSocialMetaTagParameters()
        socialParams.title = "HappySpeech — приглашение"
        socialParams.descriptionText = "Вас пригласили в семейный профиль HappySpeech"
        components.socialMetaTagParameters = socialParams

        components.options = DynamicLinkComponentsOptions()
        components.options?.pathLength = .short

        return try await withCheckedThrowingContinuation { continuation in
            components.shorten { [weak self] url, warnings, error in
                if let error {
                    self?.logger.error("buildShortLink failed: \(error.localizedDescription)")
                    continuation.resume(throwing: DynamicLinksError.linkCreationFailed(error.localizedDescription))
                    return
                }
                if let warnings, !warnings.isEmpty {
                    self?.logger.warning("buildShortLink warnings: \(warnings.joined(separator: ", "))")
                }
                guard let url else {
                    continuation.resume(throwing: DynamicLinksError.linkCreationFailed("URL is nil after shorten"))
                    return
                }
                self?.logger.info("Dynamic link created successfully")
                continuation.resume(returning: url)
            }
        }
    }

    private func parseDeepLinkURL(_ url: URL) throws -> DynamicLinkPayload {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw DynamicLinksError.invalidPayload("Неверный формат URL")
        }

        let queryItems = components.queryItems ?? []
        func param(_ name: String) -> String? {
            queryItems.first(where: { $0.name == name })?.value
        }

        let linkType = param("type") ?? "unknown"

        // Проверяем срок действия
        if let expiresAtStr = param("expiresAt"),
           let expiresAtTimestamp = TimeInterval(expiresAtStr) {
            let expiresAt = Date(timeIntervalSince1970: expiresAtTimestamp)
            if expiresAt < Date() {
                logger.warning("Dynamic link expired at \(expiresAt.description)")
                throw DynamicLinksError.expiredLink
            }
        }

        let roleStr = param("role")
        let role = roleStr.flatMap { ParentRole(rawValue: $0) }

        let expiresAtDate: Date? = param("expiresAt")
            .flatMap { TimeInterval($0) }
            .map { Date(timeIntervalSince1970: $0) }

        // Собираем extra params (все кроме стандартных)
        let standardKeys = Set(["type", "familyId", "role", "inviterUid", "expiresAt", "childId", "email"])
        let extraParams = queryItems
            .filter { !standardKeys.contains($0.name) }
            .reduce(into: [String: String]()) { dict, item in
                if let value = item.value { dict[item.name] = value }
            }

        return DynamicLinkPayload(
            linkType: linkType,
            familyId: param("familyId"),
            role: role,
            inviterUid: param("inviterUid"),
            expiresAt: expiresAtDate,
            extraParams: extraParams
        )
    }
}

// MARK: - Mock

/// Preview / test реализация с детерминированными ответами.
public final class MockDynamicLinksService: DynamicLinksServiceProtocol, @unchecked Sendable {

    public var stubbedInviteURL: URL = URL(string: "https://happyspeech.page.link/mock-invite")!
    public var stubbedSpecialistURL: URL = URL(string: "https://happyspeech.page.link/mock-specialist")!
    public var stubbedPayload: DynamicLinkPayload = DynamicLinkPayload(
        linkType: "family_invite",
        familyId: "mock-family-001",
        role: .secondary,
        inviterUid: "mock-uid-parent",
        expiresAt: Date().addingTimeInterval(7 * 24 * 3600),
        extraParams: [:]
    )
    public var shouldThrowError: Bool = false
    public var createdLinkCount: Int = 0

    public init() {}

    public func createFamilyInviteLink(familyId: String, role: ParentRole) async throws -> URL {
        if shouldThrowError { throw DynamicLinksError.linkCreationFailed("Mock error") }
        createdLinkCount += 1
        return stubbedInviteURL
    }

    public func handleIncomingLink(_ url: URL) async throws -> DynamicLinkPayload {
        if shouldThrowError { throw DynamicLinksError.linkResolutionFailed("Mock error") }
        return stubbedPayload
    }

    public func createSpecialistAccessLink(
        childId: String,
        specialistEmail: String,
        durationDays: Int
    ) async throws -> URL {
        if shouldThrowError { throw DynamicLinksError.linkCreationFailed("Mock specialist error") }
        createdLinkCount += 1
        return stubbedSpecialistURL
    }
}
