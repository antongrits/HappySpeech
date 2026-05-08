import FirebaseAuth
import FirebaseFirestore
import Foundation
import OSLog

// MARK: - Models

/// Параметры приглашения, разобранные из Universal Link.
public struct FamilyInviteParams: Sendable, Equatable {
    /// Технический токен (32-char hex), primary key Firestore документа.
    public let token: String
    /// Короткий 6-символьный код для ручного ввода.
    public let shortCode: String?

    public init(token: String, shortCode: String? = nil) {
        self.token = token
        self.shortCode = shortCode
    }
}

/// Состояние приглашения после lookup в Firestore.
public enum FamilyInviteStatus: Sendable, Equatable {
    /// Приглашение валидно, можно использовать.
    case active(parentId: String, role: ParentRole, expiresAt: Date)
    /// Приглашение уже использовано.
    case consumed(consumedAt: Date)
    /// Срок действия истёк.
    case expired(expiredAt: Date)
    /// Приглашение не найдено.
    case notFound
}

/// Результат успешного применения приглашения.
public struct FamilyInviteRedemption: Sendable, Equatable {
    /// Идентификатор родителя, выдавшего приглашение.
    public let parentId: String
    /// Назначенная роль приглашённого.
    public let role: ParentRole
    /// Идентификатор пользователя, применившего приглашение.
    public let consumedBy: String
    /// Время применения.
    public let consumedAt: Date

    public init(parentId: String, role: ParentRole, consumedBy: String, consumedAt: Date) {
        self.parentId = parentId
        self.role = role
        self.consumedBy = consumedBy
        self.consumedAt = consumedAt
    }
}

// MARK: - Errors

public enum FamilyInviteError: LocalizedError, Sendable {
    case invalidURL
    case missingToken
    case invalidShortCode
    case lookupFailed(String)
    case alreadyConsumed
    case expired
    case notFound
    case selfRedemption

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Неверный формат ссылки приглашения."
        case .missingToken:
            return "В ссылке отсутствует токен приглашения."
        case .invalidShortCode:
            return "Неверный код приглашения. Проверьте, что введено 6 символов."
        case .lookupFailed(let detail):
            return "Не удалось найти приглашение: \(detail)"
        case .alreadyConsumed:
            return "Это приглашение уже использовано."
        case .expired:
            return "Срок действия приглашения истёк."
        case .notFound:
            return "Приглашение не найдено."
        case .selfRedemption:
            return "Нельзя применить собственное приглашение."
        }
    }
}

// MARK: - Protocol

/// Управление семейными приглашениями через Apple Universal Links + Firestore.
///
/// Заменяет deprecated Firebase Dynamic Links (sunset 2025-08-25).
/// См. ADR-V18-U-DYNAMICLINKS-REPLACE.
///
/// ## Workflow
/// 1. Родитель вызывает `createInvite(role:durationHours:)` — получает
///    `FamilyInviteToken` (token + shortCode + Universal Link URL).
/// 2. Делится URL через ShareSheet **или** диктует shortCode (6 символов).
/// 3. Второй пользователь:
///    - Открывает URL → iOS резолвит Associated Domain → приложение получает
///      `userActivity.webpageURL` → `parseInviteURL(_:)` → `redeemInvite(byToken:)`.
///    - Либо вводит shortCode вручную → `redeemInvite(byShortCode:)`.
/// 4. Firestore транзакция: lookup → проверка TTL → проверка `consumed` →
///    атомарный update `consumed=true`, `consumedBy`, `consumedAt`.
///
/// > Important: Только в **родительском контуре**. Дети не получают и не
/// > отправляют приглашения (COPPA / Kids Category).
///
/// ## See Also
/// - ``CloudFunctionsService/createFamilyInviteToken(parentId:role:durationHours:)``
/// - ``ParentRole``
public protocol FamilyInviteServiceProtocol: AnyObject, Sendable {

    /// Создаёт новое приглашение через Cloud Function.
    ///
    /// - Parameters:
    ///   - role: `.secondary` (полный доступ) | `.observer` (read-only).
    ///   - durationHours: Срок жизни в часах (1-168, дефолт 24).
    /// - Returns: `FamilyInviteToken` с токеном, кодом и URL.
    /// - Throws: `CloudFunctionsError` при сетевой/серверной ошибке.
    func createInvite(role: ParentRole, durationHours: Int) async throws -> FamilyInviteToken

    /// Разбирает Universal Link URL на параметры приглашения.
    ///
    /// Поддерживаемые форматы URL:
    /// - `https://happyspeech.mmf.bsu.app/invite?token=<hex>&code=<short>`
    ///
    /// - Parameter url: URL из `NSUserActivity.webpageURL`.
    /// - Returns: `FamilyInviteParams`.
    /// - Throws: `FamilyInviteError.invalidURL` или `.missingToken`.
    func parseInviteURL(_ url: URL) throws -> FamilyInviteParams

    /// Применяет приглашение по токену (полученному из URL).
    ///
    /// Атомарная Firestore транзакция: lookup → check TTL → check consumed →
    /// update `{consumed: true, consumedBy: redeemerUid, consumedAt: serverTime}`.
    ///
    /// - Parameters:
    ///   - token: 32-char hex токен из URL.
    ///   - redeemerUid: UID применяющего пользователя (auth.currentUser.uid).
    /// - Returns: `FamilyInviteRedemption` с parentId и role.
    /// - Throws: `FamilyInviteError`.
    func redeemInvite(byToken token: String, redeemerUid: String) async throws -> FamilyInviteRedemption

    /// Применяет приглашение по короткому коду (введённому вручную).
    ///
    /// Сначала производит query `where('shortCode', '==', code)`, затем
    /// делегирует на `redeemInvite(byToken:)`.
    ///
    /// - Parameters:
    ///   - shortCode: 6-символьный код (case-insensitive, нормализуется в uppercase).
    ///   - redeemerUid: UID применяющего пользователя.
    /// - Returns: `FamilyInviteRedemption`.
    /// - Throws: `FamilyInviteError`.
    func redeemInvite(byShortCode shortCode: String, redeemerUid: String) async throws -> FamilyInviteRedemption
}

// MARK: - Configuration

private enum InviteConfig {
    /// Универсальный домен (Associated Domain entitlement).
    static let universalLinkDomain = "happyspeech.mmf.bsu.app"

    /// Path компонент Universal Link.
    static let invitePath = "/invite"

    /// Имя коллекции Firestore.
    static let collection = "family_invites"

    /// Длина короткого кода (6 символов).
    static let shortCodeLength = 6
}

// MARK: - Live Implementation

/// Продакшн-реализация `FamilyInviteServiceProtocol`.
///
/// Использует `CloudFunctionsService.createFamilyInviteToken` для создания
/// и Firestore транзакции для применения. `@unchecked Sendable` оправдан:
/// все методы stateless, Firestore SDK thread-safe.
public final class LiveFamilyInviteService: FamilyInviteServiceProtocol, @unchecked Sendable {

    private let logger = Logger(subsystem: "com.happyspeech", category: "FamilyInvite")
    private let cloudFunctions: any CloudFunctionsServiceProtocol
    private let firestore: Firestore

    public init(cloudFunctions: any CloudFunctionsServiceProtocol) {
        self.cloudFunctions = cloudFunctions
        self.firestore = Firestore.firestore()
    }

    // MARK: - FamilyInviteServiceProtocol

    public func createInvite(role: ParentRole, durationHours: Int) async throws -> FamilyInviteToken {
        // parentId извлекается из Auth.currentUser на сервере (Cloud Function проверяет).
        // Здесь передаём пустую строку, и сервер использует request.auth.uid.
        // Для поддержки кейса "родитель указан явно" — оставляем расширяемость через CloudFunctionsService.
        // В текущей реализации Cloud Function требует parentId == auth.uid (см. functions/index.js U.1).

        // Достаём auth.uid через FirebaseAuth (без жёсткого импорта в protocol).
        guard let parentId = currentAuthUID() else {
            logger.error("createInvite called without authenticated user")
            throw CloudFunctionsError.appCheckFailed
        }

        let token = try await cloudFunctions.createFamilyInviteToken(
            parentId: parentId,
            role: role,
            durationHours: durationHours
        )
        logger.info("Family invite created: shortCode=\(token.shortCode), expires=\(token.expiresAt.description)")
        return token
    }

    public func parseInviteURL(_ url: URL) throws -> FamilyInviteParams {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw FamilyInviteError.invalidURL
        }

        // Принимаем только Universal Link на нашем домене.
        guard components.host == InviteConfig.universalLinkDomain,
              components.path == InviteConfig.invitePath else {
            throw FamilyInviteError.invalidURL
        }

        let queryItems = components.queryItems ?? []
        guard let token = queryItems.first(where: { $0.name == "token" })?.value,
              !token.isEmpty else {
            throw FamilyInviteError.missingToken
        }

        let shortCode = queryItems.first(where: { $0.name == "code" })?.value

        logger.info("Parsed Universal Link: token present, shortCode=\(shortCode ?? "nil")")
        return FamilyInviteParams(token: token, shortCode: shortCode)
    }

    public func redeemInvite(
        byToken token: String,
        redeemerUid: String
    ) async throws -> FamilyInviteRedemption {
        guard !token.isEmpty else { throw FamilyInviteError.missingToken }
        guard !redeemerUid.isEmpty else { throw FamilyInviteError.lookupFailed("redeemerUid пустой") }

        let docRef = firestore.collection(InviteConfig.collection).document(token)

        do {
            let redemption = try await firestore.runTransaction { transaction, errorPointer in
                let snapshot: DocumentSnapshot
                do {
                    snapshot = try transaction.getDocument(docRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }

                guard snapshot.exists, let data = snapshot.data() else {
                    errorPointer?.pointee = NSError(
                        domain: "FamilyInvite",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "notFound"]
                    )
                    return nil
                }

                if let consumed = data["consumed"] as? Bool, consumed {
                    errorPointer?.pointee = NSError(
                        domain: "FamilyInvite",
                        code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "alreadyConsumed"]
                    )
                    return nil
                }

                if let expiresAtTs = data["expiresAt"] as? Timestamp {
                    if expiresAtTs.dateValue() < Date() {
                        errorPointer?.pointee = NSError(
                            domain: "FamilyInvite",
                            code: 410,
                            userInfo: [NSLocalizedDescriptionKey: "expired"]
                        )
                        return nil
                    }
                }

                guard let parentId = data["parentId"] as? String else {
                    errorPointer?.pointee = NSError(
                        domain: "FamilyInvite",
                        code: 422,
                        userInfo: [NSLocalizedDescriptionKey: "missing parentId"]
                    )
                    return nil
                }

                if parentId == redeemerUid {
                    errorPointer?.pointee = NSError(
                        domain: "FamilyInvite",
                        code: 403,
                        userInfo: [NSLocalizedDescriptionKey: "selfRedemption"]
                    )
                    return nil
                }

                let roleRaw = (data["role"] as? String) ?? "observer"
                let role = ParentRole(rawValue: roleRaw) ?? .observer

                transaction.updateData(
                    [
                        "consumed": true,
                        "consumedBy": redeemerUid,
                        "consumedAt": FieldValue.serverTimestamp()
                    ],
                    forDocument: docRef
                )

                return FamilyInviteRedemption(
                    parentId: parentId,
                    role: role,
                    consumedBy: redeemerUid,
                    consumedAt: Date()
                )
            }

            guard let result = redemption as? FamilyInviteRedemption else {
                throw FamilyInviteError.lookupFailed("Транзакция вернула пустой результат")
            }

            logger.info("Invite redeemed successfully: role=\(result.role.rawValue)")
            return result
        } catch let error as NSError {
            logger.error("redeemInvite error: code=\(error.code), domain=\(error.domain), message=\(error.localizedDescription)")
            if error.domain == "FamilyInvite" {
                switch error.localizedDescription {
                case "notFound":
                    throw FamilyInviteError.notFound
                case "alreadyConsumed":
                    throw FamilyInviteError.alreadyConsumed
                case "expired":
                    throw FamilyInviteError.expired
                case "selfRedemption":
                    throw FamilyInviteError.selfRedemption
                default:
                    throw FamilyInviteError.lookupFailed(error.localizedDescription)
                }
            }
            throw FamilyInviteError.lookupFailed(error.localizedDescription)
        }
    }

    public func redeemInvite(
        byShortCode shortCode: String,
        redeemerUid: String
    ) async throws -> FamilyInviteRedemption {
        let normalized = shortCode
            .uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalized.count == InviteConfig.shortCodeLength else {
            throw FamilyInviteError.invalidShortCode
        }

        // Query Firestore по shortCode, фильтруем не-consumed.
        let querySnap: QuerySnapshot
        do {
            querySnap = try await firestore.collection(InviteConfig.collection)
                .whereField("shortCode", isEqualTo: normalized)
                .whereField("consumed", isEqualTo: false)
                .limit(to: 1)
                .getDocuments()
        } catch {
            logger.error("redeemInvite query error: \(error.localizedDescription)")
            throw FamilyInviteError.lookupFailed(error.localizedDescription)
        }

        guard let document = querySnap.documents.first else {
            throw FamilyInviteError.notFound
        }

        return try await redeemInvite(byToken: document.documentID, redeemerUid: redeemerUid)
    }

    // MARK: - Private Helpers

    /// Извлекает текущий auth.uid через FirebaseAuth singleton.
    ///
    /// Использует прямой вызов `Auth.auth().currentUser?.uid` — `FirebaseAuth`
    /// thread-safe и инициализирован после `FirebaseApp.configure()`.
    private func currentAuthUID() -> String? {
        return Auth.auth().currentUser?.uid
    }
}

// MARK: - Mock

/// Preview / test реализация с детерминированными ответами.
public final class MockFamilyInviteService: FamilyInviteServiceProtocol, @unchecked Sendable {

    public var stubbedToken: FamilyInviteToken = FamilyInviteToken(
        token: "mock-token-deadbeef00000000deadbeef00000000",
        shortCode: "ABCD23",
        expiresAt: Date().addingTimeInterval(24 * 3600),
        // swiftlint:disable:next force_unwrapping
        deepLinkURL: URL(string: "https://happyspeech.mmf.bsu.app/invite?token=mock&code=ABCD23")!
    )

    public var stubbedRedemption: FamilyInviteRedemption = FamilyInviteRedemption(
        parentId: "mock-parent-uid",
        role: .secondary,
        consumedBy: "mock-redeemer-uid",
        consumedAt: Date()
    )

    public var shouldThrowError: FamilyInviteError?
    public var createdInvitesCount: Int = 0
    public var redeemCallsCount: Int = 0

    public init() {}

    public func createInvite(role: ParentRole, durationHours: Int) async throws -> FamilyInviteToken {
        if let error = shouldThrowError { throw error }
        createdInvitesCount += 1
        return stubbedToken
    }

    public func parseInviteURL(_ url: URL) throws -> FamilyInviteParams {
        if let error = shouldThrowError { throw error }
        let token = url.absoluteString.contains("token=") ? "mock-parsed-token" : ""
        if token.isEmpty { throw FamilyInviteError.missingToken }
        return FamilyInviteParams(token: token, shortCode: "ABCD23")
    }

    public func redeemInvite(
        byToken token: String,
        redeemerUid: String
    ) async throws -> FamilyInviteRedemption {
        if let error = shouldThrowError { throw error }
        redeemCallsCount += 1
        return stubbedRedemption
    }

    public func redeemInvite(
        byShortCode shortCode: String,
        redeemerUid: String
    ) async throws -> FamilyInviteRedemption {
        if let error = shouldThrowError { throw error }
        redeemCallsCount += 1
        return stubbedRedemption
    }
}
