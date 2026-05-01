import Foundation
import OSLog
import RealmSwift

// MARK: - RealmActor

/// Thread-safe обёртка над Realm через Swift actor — единственный путь к локальной БД.
///
/// `RealmActor` обеспечивает изоляцию конкурентного доступа к Realm через actor-модель Swift 6.
/// Все операции с Realm **обязаны** проходить через этот актор. Realm-объекты никогда
/// не пересекают границу актора — только Sendable DTO, полученные через маппинг внутри актора.
///
/// ### Правила использования
/// - Вызывай через `await realmActor.fetchAllMapped(...)` из сервисов
/// - Никогда не передавай `RealmSwift.Object` напрямую — только Sendable DTOs
/// - Открой Realm через `open(configuration:)` перед первым использованием
///
/// ### Основные операции
/// - `fetchAllMapped(_:map:)` — все объекты типа T, смаппированные в DTO
/// - `fetchMapped(_:primaryKey:map:)` — один объект по PK
/// - `fetchFilteredMapped(_:predicate:map:)` — с фильтрацией
/// - `writeVoid(_:)` — транзакция записи
/// - `updateField(_:primaryKey:block:)` — обновление конкретного объекта
///
/// ## Пример
/// ```swift
/// let actor = RealmActor()
/// try await actor.open()
///
/// // Чтение — маппинг внутри актора гарантирует Sendable
/// let sessions: [SessionDTO] = try await actor.fetchAllMapped(
///     SessionObject.self
/// ) { obj in
///     SessionDTO(id: obj.id, score: obj.score, date: obj.date)
/// }
///
/// // Запись
/// try await actor.writeVoid { realm in
///     realm.add(newObject, update: .modified)
/// }
/// ```
///
/// ## See Also
/// - ``AppError``
/// - ``HSLogger``
public actor RealmActor {

    private var realm: Realm?

    public init() {}

    // MARK: - Open

    /// Открывает Realm через `Realm(actor: self)` — actor-safe async инициализация.
    /// Гарантирует, что Realm привязан к executor этого actor, исключая thread mismatch.
    public func open(configuration: Realm.Configuration? = nil) async throws {
        let config = configuration ?? defaultConfiguration
        let opened = try await Realm(configuration: config, actor: self)
        self.realm = opened
        HSLogger.realm.info("Realm opened at: \(opened.configuration.fileURL?.path ?? "memory")")
    }

    // MARK: - Read (maps to Sendable inside actor)

    /// Fetch all objects mapped to a Sendable DTO — safe to cross actor boundary.
    public func fetchAllMapped<T: Object, DTO: Sendable>(_ type: T.Type, map: (T) -> DTO) throws -> [DTO] {
        guard let realm else { throw AppError.realmReadFailed("Realm not opened") }
        return Array(realm.objects(type)).map(map)
    }

    /// Fetch single object mapped to a Sendable DTO — safe to cross actor boundary.
    public func fetchMapped<T: Object, DTO: Sendable>(_ type: T.Type, primaryKey: String, map: (T) -> DTO) throws -> DTO? {
        guard let realm else { throw AppError.realmReadFailed("Realm not opened") }
        return realm.object(ofType: type, forPrimaryKey: primaryKey).map(map)
    }

    /// Fetch filtered objects mapped to Sendable DTOs — safe to cross actor boundary.
    public func fetchFilteredMapped<T: Object, DTO: Sendable>(_ type: T.Type, predicate: NSPredicate, map: (T) -> DTO) throws -> [DTO] {
        guard let realm else { throw AppError.realmReadFailed("Realm not opened") }
        return Array(realm.objects(type).filter(predicate)).map(map)
    }

    // MARK: - Write (void — no Realm objects returned across actor boundary)

    public func writeVoid(_ block: (Realm) throws -> Void) throws {
        guard let realm else { throw AppError.realmWriteFailed("Realm not opened") }
        try realm.write {
            try block(realm)
        }
    }

    public func updateField<T: Object>(_ type: T.Type, primaryKey: String, block: (T) throws -> Void) throws {
        guard let realm else { throw AppError.realmWriteFailed("Realm not opened") }
        guard let obj = realm.object(ofType: type, forPrimaryKey: primaryKey) else {
            throw AppError.entityNotFound(primaryKey)
        }
        try realm.write {
            try block(obj)
        }
    }

    public func delete<T: Object>(_ type: T.Type, primaryKey: String) throws {
        guard let realm else { throw AppError.realmWriteFailed("Realm not opened") }
        guard let obj = realm.object(ofType: type, forPrimaryKey: primaryKey) else { return }
        try realm.write {
            realm.delete(obj)
        }
    }

    public func deleteAll<T: Object>(_ type: T.Type) throws {
        guard let realm else { throw AppError.realmWriteFailed("Realm not opened") }
        try realm.write {
            realm.delete(realm.objects(type))
        }
    }

    // MARK: - Async Realm helpers (for SyncService)
    // Uses async Realm(actor:) — results are mapped to Sendable inside actor

    /// Fetch and map objects using async Realm — result is Sendable.
    public func asyncFetchMapped<T: Object, DTO: Sendable>(_ type: T.Type, map: @escaping (T) -> DTO) async -> [DTO] {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return [] }
        return Array(realmInstance.objects(type)).map(map)
    }

    /// Fetch filtered objects using async Realm — result is Sendable.
    /// M6.16: используется ScreeningOutcomeRepository для безопасного cross-actor доступа.
    public func fetchFilteredMappedAsync<T: Object, DTO: Sendable>(
        _ type: T.Type,
        predicate: NSPredicate,
        map: @escaping (T) -> DTO
    ) async throws -> [DTO] {
        let realmInstance = try await Realm(actor: self)
        return Array(realmInstance.objects(type).filter(predicate)).map(map)
    }

    /// Write a block to Realm using async Realm.
    public func asyncWrite(_ block: @escaping (Realm) -> Void) async {
        guard let realmInstance = try? await Realm(actor: self) else { return }
        try? realmInstance.write { block(realmInstance) }
    }

    // MARK: - Default Configuration

    private var defaultConfiguration: Realm.Configuration {
        var config = Realm.Configuration.defaultConfiguration
        config.schemaVersion = RealmSchemaVersion.current
        config.migrationBlock = RealmMigrations.migrationBlock
        config.deleteRealmIfMigrationNeeded = false
        return config
    }
}
