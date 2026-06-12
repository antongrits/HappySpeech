import Foundation
import SwiftUI

// MARK: - FamilyInvite VIP Models
//
// Со-родительство: родитель-primary приглашает близкого (второго родителя /
// бабушку / дедушку) разделить доступ к профилю ребёнка. Две поверхности:
//   1. Создание приглашения (CreateInvite) — выбор роли + генерация кода.
//   2. Принятие приглашения (RedeemInvite) — ручной ввод 6-символьного кода.
//
// COPPA: только родительский контур. Дети не создают и не принимают приглашения.

enum FamilyInvite {

    // MARK: - Приглашаемая роль

    /// Роль, доступная для выбора при создании приглашения. Подмножество
    /// ``ParentRole`` без `.primary` — основной родитель не приглашается.
    enum InvitableRole: String, CaseIterable, Identifiable, Sendable {
        case secondary
        case observer

        var id: String { rawValue }

        /// Соответствующая доменная роль ``ParentRole``.
        var parentRole: ParentRole {
            switch self {
            case .secondary: return .secondary
            case .observer:  return .observer
            }
        }

        var title: String {
            switch self {
            case .secondary: return String(localized: "familyInvite.role.secondary.title")
            case .observer:  return String(localized: "familyInvite.role.observer.title")
            }
        }

        var subtitle: String {
            switch self {
            case .secondary: return String(localized: "familyInvite.role.secondary.subtitle")
            case .observer:  return String(localized: "familyInvite.role.observer.subtitle")
            }
        }

        var iconName: String {
            switch self {
            case .secondary: return "person.2.fill"
            case .observer:  return "eye.fill"
            }
        }
    }

    // MARK: - Create Invite

    enum Create {

        struct Request {
            let role: InvitableRole
            let durationHours: Int
        }

        struct Response {
            let shortCode: String
            let expiresAt: Date
            let shareURL: URL
            let role: InvitableRole
        }
    }

    // MARK: - Redeem Invite

    enum Redeem {

        struct Request {
            let shortCode: String
        }

        struct Response {
            let role: ParentRole
            let inviterParentId: String
        }
    }

    // MARK: - Локализованное представление роли результата

    /// Человеко-читаемое имя любой ``ParentRole`` для экрана-результата redeem.
    static func localizedRoleName(_ role: ParentRole) -> String {
        switch role {
        case .primary:   return String(localized: "familyInvite.role.primary.title")
        case .secondary: return String(localized: "familyInvite.role.secondary.title")
        case .observer:  return String(localized: "familyInvite.role.observer.title")
        }
    }
}

// MARK: - CreateInviteViewModel

@Observable
@MainActor
final class CreateInviteViewModel {

    /// Выбранная роль приглашаемого. По умолчанию — со-родитель (полный доступ).
    var selectedRole: FamilyInvite.InvitableRole = .secondary

    /// Состояние генерации кода.
    var isCreating: Bool = false

    /// Сгенерированный код (после успешного создания).
    var shortCode: String?

    /// Срок действия сгенерированного кода.
    var expiresAt: Date?

    /// Ссылка-приглашение для ShareLink.
    var shareURL: URL?

    /// Роль, под которую был выпущен текущий код.
    var issuedRole: FamilyInvite.InvitableRole?

    /// Сообщение об ошибке (локализованное, без debug-строк).
    var errorMessage: String?

    /// Сгенерирован ли активный код.
    var hasCode: Bool { shortCode != nil }

    /// Срок действия в человеко-читаемом виде, например «до 14 июня, 18:30».
    var expiryText: String {
        guard let expiresAt else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = String(localized: "familyInvite.create.expiry.dateFormat")
        return String(
            format: String(localized: "familyInvite.create.expiry.format"),
            formatter.string(from: expiresAt)
        )
    }

    /// Текст-инструкция для ShareLink с уже подставленным кодом.
    func shareMessage(code: String) -> String {
        String(format: String(localized: "familyInvite.create.shareMessage"), code)
    }
}

// MARK: - RedeemInviteViewModel

@Observable
@MainActor
final class RedeemInviteViewModel {

    /// Введённый код (нормализуется в uppercase).
    var enteredCode: String = "" {
        didSet {
            let normalized = enteredCode
                .uppercased()
                .filter { $0.isLetter || $0.isNumber }
            let clamped = String(normalized.prefix(FamilyInvite.codeLength))
            if clamped != enteredCode {
                enteredCode = clamped
            }
        }
    }

    /// Состояние применения приглашения.
    var isRedeeming: Bool = false

    /// Успешно применённая роль (после redeem).
    var redeemedRole: ParentRole?

    /// Сообщение об ошибке (локализованное).
    var errorMessage: String?

    /// Не аутентифицирован: нужно сначала войти.
    var requiresSignIn: Bool = false

    /// Достаточно ли символов введено для активации кнопки.
    var isCodeComplete: Bool { enteredCode.count == FamilyInvite.codeLength }

    /// Применено ли приглашение успешно.
    var didSucceed: Bool { redeemedRole != nil }

    /// Текст успеха с подставленной ролью.
    var successText: String {
        guard let role = redeemedRole else { return "" }
        return String(
            format: String(localized: "familyInvite.redeem.success.message"),
            FamilyInvite.localizedRoleName(role)
        )
    }
}

// MARK: - Shared constants

extension FamilyInvite {
    /// Длина короткого кода (синхронизировано с сервером — 6 символов).
    static let codeLength = 6

    /// Срок жизни приглашения по умолчанию — 72 часа (3 суток).
    static let defaultDurationHours = 72
}
