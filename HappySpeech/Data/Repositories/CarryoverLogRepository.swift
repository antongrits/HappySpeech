import Foundation
import OSLog
import RealmSwift

// MARK: - CarryoverLogRepository Protocol

/// Репозиторий дневных логов переноса звука в спонтанную речь
/// (`CarryoverLogObject`, v20 — «Звуковой охотник дня»).
///
/// Одна запись = одна дата × звук × ребёнок. Содержит «пойманные» в быту слова
/// (детский контур) и родительское подтверждение переноса (3 градации) с
/// опциональной голосовой заметкой. Сигнал переноса читает
/// `AdaptivePlannerService` через `CorrectionStage`.
///
/// Доступ DTO-only через `RealmActor`: Realm-объекты никогда не пересекают
/// границу актора — наружу отдаются только Sendable `CarryoverLogDTO`.
public protocol CarryoverLogRepository: Sendable {
    /// Лог конкретного дня/звука/ребёнка (или nil, если за этот день ещё нет записи).
    func fetch(childId: String, sound: String, day: Date) async throws -> CarryoverLogDTO?

    /// Все логи ребёнка, отсортированные по дню (старые → новые). Используется
    /// для серии «дней охоты» (streak) и истории чек-инов родителя.
    func fetchAll(childId: String) async throws -> [CarryoverLogDTO]

    /// Сохранить/обновить лог (idempotent upsert по primary-key id).
    func upsert(_ log: CarryoverLogDTO) async throws
}

// MARK: - Realm → DTO Mapping

private extension CarryoverLogObject {
    var asDTO: CarryoverLogDTO {
        CarryoverLogDTO(
            id: id,
            childId: childId,
            sound: sound,
            day: day,
            caughtWords: Array(caughtWords),
            netGoal: netGoal,
            completedTaskIds: Array(completedTaskIds),
            parentCheckIn: parentCheckIn,
            parentVoiceNotePath: parentVoiceNotePath,
            parentVoiceNoteDurationSec: parentVoiceNoteDurationSec,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - LiveCarryoverLogRepository

public final class LiveCarryoverLogRepository: CarryoverLogRepository, @unchecked Sendable {

    private let realmActor: RealmActor
    private let logger = Logger(subsystem: "ru.happyspeech", category: "CarryoverLogRepo")

    public init(realmActor: RealmActor) {
        self.realmActor = realmActor
    }

    public func fetch(childId: String, sound: String, day: Date) async throws -> CarryoverLogDTO? {
        let id = CarryoverLogDTO.makeId(childId: childId, sound: sound, day: day)
        let predicate = NSPredicate(format: "id == %@", id)
        let matches = try await realmActor.fetchFilteredMappedAsync(
            CarryoverLogObject.self,
            predicate: predicate,
            map: \.asDTO
        )
        return matches.first
    }

    public func fetchAll(childId: String) async throws -> [CarryoverLogDTO] {
        let predicate = NSPredicate(format: "childId == %@", childId)
        let all = try await realmActor.fetchFilteredMappedAsync(
            CarryoverLogObject.self,
            predicate: predicate,
            map: \.asDTO
        )
        return all.sorted { $0.day < $1.day }
    }

    public func upsert(_ log: CarryoverLogDTO) async throws {
        try await realmActor.writeVoid { realm in
            let obj = realm.object(ofType: CarryoverLogObject.self, forPrimaryKey: log.id)
                ?? CarryoverLogObject()
            let isNew = obj.realm == nil
            obj.id = log.id
            obj.childId = log.childId
            obj.sound = log.sound
            obj.day = log.day
            obj.caughtWords.removeAll()
            obj.caughtWords.append(objectsIn: log.caughtWords)
            obj.netGoal = log.netGoal
            obj.completedTaskIds.removeAll()
            obj.completedTaskIds.append(objectsIn: log.completedTaskIds)
            obj.parentCheckIn = log.parentCheckIn
            obj.parentVoiceNotePath = log.parentVoiceNotePath
            obj.parentVoiceNoteDurationSec = log.parentVoiceNoteDurationSec
            if isNew { obj.createdAt = log.createdAt }
            obj.updatedAt = log.updatedAt
            realm.add(obj, update: .modified)
        }
        let lid = log.id
        logger.debug("Carryover log upserted id=\(lid, privacy: .public) caught=\(log.caughtWords.count, privacy: .public)")
    }
}

// MARK: - MockCarryoverLogRepository (preview / tests)

public final class MockCarryoverLogRepository: CarryoverLogRepository, @unchecked Sendable {

    private let lock = NSLock()
    private var storage: [CarryoverLogDTO]
    public var shouldFail = false

    public init(logs: [CarryoverLogDTO] = []) {
        self.storage = logs
    }

    /// Снимок текущего содержимого (для ассертов в тестах).
    public var logs: [CarryoverLogDTO] {
        lock.lock(); defer { lock.unlock() }
        return storage
    }

    public func fetch(childId: String, sound: String, day: Date) async throws -> CarryoverLogDTO? {
        if shouldFail { throw AppError.realmReadFailed("Mock failure") }
        let id = CarryoverLogDTO.makeId(childId: childId, sound: sound, day: day)
        return lock.withLock { storage.first { $0.id == id } }
    }

    public func fetchAll(childId: String) async throws -> [CarryoverLogDTO] {
        if shouldFail { throw AppError.realmReadFailed("Mock failure") }
        return lock.withLock {
            storage
                .filter { $0.childId == childId }
                .sorted { $0.day < $1.day }
        }
    }

    public func upsert(_ log: CarryoverLogDTO) async throws {
        if shouldFail { throw AppError.realmWriteFailed("Mock failure") }
        lock.withLock {
            storage.removeAll { $0.id == log.id }
            storage.append(log)
        }
    }
}

// MARK: - Preview Data

public extension CarryoverLogDTO {
    /// Пример полу-заполненного дневного лога по звуку «Р» (2 из 5 пойманы).
    static let preview = CarryoverLogDTO(
        id: CarryoverLogDTO.makeId(childId: "preview-child-1", sound: "Р", day: Date()),
        childId: "preview-child-1",
        sound: "Р",
        day: Calendar.current.startOfDay(for: Date()),
        caughtWords: ["ковёр", "рыба"],
        netGoal: 5,
        completedTaskIds: ["home-objects"],
        parentCheckIn: "",
        parentVoiceNotePath: nil,
        parentVoiceNoteDurationSec: 0
    )
}
