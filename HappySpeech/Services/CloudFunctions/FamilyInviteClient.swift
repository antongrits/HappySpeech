import FirebaseFunctions
import Foundation

// MARK: - Models

/// Расширенная роль приглашённого — для email-инвайтов через
/// `sendFamilyInvite` (parent / specialist).
///
/// Отличается от ``ParentRole`` тем, что покрывает приглашение
/// специалиста (логопеда), а не только второго родителя.
public enum FamilyInviteRecipientRole: String, Sendable, CaseIterable {
    case parent
    case specialist
}

/// Результат отправки приглашения через email.
public struct FamilyInviteDispatch: Sendable, Equatable {
    public let inviteId: String
    public let inviteUrl: URL
    public let expiresAt: Date
    public let emailDispatched: Bool

    public init(inviteId: String, inviteUrl: URL, expiresAt: Date, emailDispatched: Bool) {
        self.inviteId = inviteId
        self.inviteUrl = inviteUrl
        self.expiresAt = expiresAt
        self.emailDispatched = emailDispatched
    }
}

// MARK: - Protocol

/// Клиент Cloud Function `sendFamilyInvite` (email-based приглашение).
///
/// > Note: Для ShareSheet/Universal Link приглашения используйте
/// > `LiveCloudFunctionsService.createFamilyInviteToken` — это разные
/// > сценарии (email vs. share link).
public protocol FamilyInviteClientProtocol: CloudFunctionsClient {
    /// Создаёт приглашение и (при настроенном email-провайдере) отправляет email.
    ///
    /// - Parameters:
    ///   - inviteeEmail: Email приглашённого.
    ///   - role: Роль (`.parent` | `.specialist`).
    ///   - childIds: Список идентификаторов детей, к которым выдаётся доступ
    ///     (≤ 10, владельцем должен быть вызывающий родитель).
    /// - Returns: ``FamilyInviteDispatch``.
    /// - Throws: ``CloudFunctionsClientError``.
    func sendInvite(
        inviteeEmail: String,
        role: FamilyInviteRecipientRole,
        childIds: [String]
    ) async throws -> FamilyInviteDispatch
}

// MARK: - Live

public final class LiveFamilyInviteClient: LiveCloudFunctionsClientBase,
                                           FamilyInviteClientProtocol,
                                           @unchecked Sendable {

    public init(region: String = CloudFunctionsRegion.default) {
        super.init(region: region, category: "FamilyInvite")
    }

    public func sendInvite(
        inviteeEmail: String,
        role: FamilyInviteRecipientRole,
        childIds: [String]
    ) async throws -> FamilyInviteDispatch {
        let trimmedEmail = inviteeEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidEmail(trimmedEmail) else {
            throw CloudFunctionsClientError.invalidArgument("inviteeEmail")
        }
        guard !childIds.isEmpty, childIds.count <= 10 else {
            throw CloudFunctionsClientError.invalidArgument("childIds")
        }
        for childId in childIds where childId.isEmpty {
            throw CloudFunctionsClientError.invalidArgument("childIds contains empty string")
        }

        let callable = functions.httpsCallable("sendFamilyInvite")
        let payload: [String: Any] = [
            "inviteeEmail": trimmedEmail,
            "role": role.rawValue,
            "childIds": childIds
        ]

        do {
            let result = try await callable.call(payload)
            return try parse(result.data)
        } catch {
            logger.error("sendFamilyInvite error: \(error.localizedDescription)")
            throw mapError(error)
        }
    }

    private func parse(_ data: Any) throws -> FamilyInviteDispatch {
        let dict = try extractDictionary(from: data)
        guard
            let inviteId = dict["inviteId"] as? String, !inviteId.isEmpty,
            let urlString = dict["inviteUrl"] as? String,
            let url = URL(string: urlString),
            let expiresAtString = dict["expiresAt"] as? String
        else {
            throw CloudFunctionsClientError.invalidResponse(
                "missing inviteId/inviteUrl/expiresAt"
            )
        }
        let emailDispatched = (dict["emailDispatched"] as? Bool)
            ?? (dict["emailDispatched"] as? NSNumber)?.boolValue
            ?? false

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expiresAt = formatter.date(from: expiresAtString)
            ?? ISO8601DateFormatter().date(from: expiresAtString)
            ?? Date().addingTimeInterval(72 * 3600)

        return FamilyInviteDispatch(
            inviteId: inviteId,
            inviteUrl: url,
            expiresAt: expiresAt,
            emailDispatched: emailDispatched
        )
    }

    private func isValidEmail(_ value: String) -> Bool {
        guard value.count >= 3, value.count <= 254 else { return false }
        let parts = value.split(separator: "@")
        guard parts.count == 2 else { return false }
        let domain = parts[1]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
    }
}

// MARK: - Mock

public final class MockFamilyInviteClient: FamilyInviteClientProtocol,
                                           @unchecked Sendable {

    public let region: String = CloudFunctionsRegion.default
    public var stubbedDispatch: FamilyInviteDispatch
    public var shouldThrowError: Bool = false

    public init() {
        // swiftlint:disable:next force_unwrapping
        let url = URL(string: "https://happyspeech.page.link/invite?token=mock00000000")!
        self.stubbedDispatch = FamilyInviteDispatch(
            inviteId: "mock00000000",
            inviteUrl: url,
            expiresAt: Date().addingTimeInterval(72 * 3600),
            emailDispatched: false
        )
    }

    public func sendInvite(
        inviteeEmail: String,
        role: FamilyInviteRecipientRole,
        childIds: [String]
    ) async throws -> FamilyInviteDispatch {
        if shouldThrowError {
            throw CloudFunctionsClientError.serverError("Mock error")
        }
        return stubbedDispatch
    }
}
