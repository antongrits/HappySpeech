import Foundation
import OSLog

// MARK: - FamilyMembershipRecord

/// Запись о принятом семейном приглашении на этом устройстве.
///
/// Хранит факт «я присоединился к семье <inviterParentId> как <role>». Это
/// единственное, что устройство приглашённого может зафиксировать локально:
/// данные детей приглашающего живут в его Realm и **не** реплицируются
/// кросс-аккаунтно (см. отчёт по co-parent gap). Запись сохраняется, чтобы
/// будущая backend-привязка детей (family-link репозиторий) могла её
/// использовать без повторного ввода кода.
public struct FamilyMembershipRecord: Codable, Sendable, Equatable {
    public let inviterParentId: String
    public let role: String
    public let joinedAt: Date

    public init(inviterParentId: String, role: ParentRole, joinedAt: Date) {
        self.inviterParentId = inviterParentId
        self.role = role.rawValue
        self.joinedAt = joinedAt
    }
}

// MARK: - FamilyMembershipStoring

/// Локальное хранилище принятых семейных приглашений.
public protocol FamilyMembershipStoring: Sendable {
    /// Сохраняет факт принятого приглашения (идемпотентно по `inviterParentId`).
    func save(_ record: FamilyMembershipRecord)
    /// Все принятые приглашения на устройстве.
    func all() -> [FamilyMembershipRecord]
}

// MARK: - UserDefaultsFamilyMembershipStore

/// Реализация поверх `UserDefaults`. Persistence-only — НЕ создаёт фантомных
/// детей и не претендует на кросс-аккаунтный доступ.
public final class UserDefaultsFamilyMembershipStore: FamilyMembershipStoring, @unchecked Sendable {

    private let defaults: UserDefaults
    private let storageKey = "familyInvite.acceptedMemberships"
    private let logger = Logger(subsystem: "ru.happyspeech", category: "FamilyMembershipStore")

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func save(_ record: FamilyMembershipRecord) {
        var records = all()
        records.removeAll { $0.inviterParentId == record.inviterParentId }
        records.append(record)
        guard let encoded = try? JSONEncoder().encode(records) else {
            logger.error("FamilyMembershipStore: encode failed")
            return
        }
        defaults.set(encoded, forKey: storageKey)
        logger.info("FamilyMembershipStore: saved membership role=\(record.role, privacy: .public)")
    }

    public func all() -> [FamilyMembershipRecord] {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([FamilyMembershipRecord].self, from: data) else {
            return []
        }
        return decoded
    }
}
