import Foundation
import RealmSwift

// MARK: - RealmMigrations

/// Centralised Realm migration block. Increment RealmSchemaVersion.current with each schema change.
enum RealmMigrations {

    static let migrationBlock: MigrationBlock = { migration, oldSchemaVersion in
        if oldSchemaVersion < 1 {
            // v1: initial schema — no action needed (Realm handles new properties with defaults)
        }
        if oldSchemaVersion < 2 {
            // v2: added LLMDecisionLog — Realm creates the new object schema automatically,
            // no enumeration needed since the entity didn't exist before.
        }
    }
}

// MARK: - RealmActor Extension

public extension RealmActor {
    /// Fetches all objects of given type and returns as array (for use outside actor).
    func fetch<T: Object>(_ type: T.Type) async -> [T] {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return [] }
        return Array(realmInstance.objects(type))
    }

    /// Writes a block to Realm on the actor.
    func write(_ block: @escaping (Realm) -> Void) async {
        guard let realmInstance = try? await Realm(actor: self) else { return }
        try? realmInstance.write { block(realmInstance) }
    }
}
