import Foundation
import RealmSwift

// MARK: - RealmMigrations

/// Centralised Realm migration block. Increment RealmSchemaVersion.current with each schema change.
enum RealmMigrations {

    static let migrationBlock: MigrationBlock = { _, oldSchemaVersion in
        if oldSchemaVersion < 1 {
            // v1: initial schema — no action needed (Realm handles new properties with defaults)
        }
        if oldSchemaVersion < 2 {
            // v2: added LLMDecisionLog — Realm creates the new object schema automatically,
            // no enumeration needed since the entity didn't exist before.
        }
        if oldSchemaVersion < 3 {
            // v3: added ScreeningOutcomeObject — same as above, новый объект не требует
            // миграционных действий, Realm создаёт схему автоматически.
        }
        if oldSchemaVersion < 4 {
            // v4: added CustomizationObject (skin/colorVariant/voice/updatedAt).
            // Realm создаёт схему автоматически, дефолты заданы в модели.
        }
        if oldSchemaVersion < 5 {
            // v5: added FamilyRecordingObject (word/audioFilePath/recordedAt/durationSeconds/parentProfileId).
            // Realm создаёт схему автоматически, дефолты заданы в модели.
        }
        if oldSchemaVersion < 6 {
            // v6: added FluencySessionObject (StutteringModule Fluency Diary).
            // Realm создаёт схему автоматически, дефолты заданы в модели.
        }
        if oldSchemaVersion < 7 {
            // v7: added UnlockedAchievementObject (L6 Achievements + offline leaderboard).
            // Realm создаёт схему автоматически, дефолты заданы в модели.
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

    /// Fetches FluencySessionObject as value-type DTOs — Sendable-safe.
    internal func fetchFluencySessions() async -> [FluencySessionData] {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return [] }
        return Array(realmInstance.objects(FluencySessionObject.self)).map { obj in
            FluencySessionData(
                id: obj.id,
                date: obj.date,
                dysfluencyCount: obj.dysfluencyCount,
                totalSyllables: obj.totalSyllables,
                rate: obj.rate,
                transcript: obj.transcript
            )
        }
    }

    /// Fetches UnlockedAchievementObject as value-type DTOs for a given child — Sendable-safe.
    internal func fetchUnlockedAchievements(childId: String) async -> [UnlockedAchievementData] {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return [] }
        return Array(
            realmInstance.objects(UnlockedAchievementObject.self)
                .filter("childId == %@", childId)
        ).map { obj in
            UnlockedAchievementData(
                id: obj.id,
                childId: obj.childId,
                achievementKey: obj.achievementKey,
                unlockedAt: obj.unlockedAt
            )
        }
    }

    /// Fetches sibling ChildProfile objects for family leaderboard — Sendable-safe.
    /// Returns objects with parentId == given parentId, excluding the current child.
    internal func fetchSiblingProfiles(parentId: String, excludeId: String) async -> [ChildProfileData] {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return [] }
        return Array(
            realmInstance.objects(ChildProfile.self)
                .filter("parentId == %@ AND id != %@ AND isArchived == false", parentId, excludeId)
        ).map { obj in
            ChildProfileData(id: obj.id, name: obj.name, parentId: obj.parentId)
        }
    }

    /// Persists a newly unlocked achievement for a child — idempotent (noop if already exists).
    internal func persistAchievementUnlock(childId: String, achievementKey: String) async {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return }
        let existing = realmInstance.objects(UnlockedAchievementObject.self)
            .filter("childId == %@ AND achievementKey == %@", childId, achievementKey)
        guard existing.isEmpty else { return }
        let obj = UnlockedAchievementObject()
        obj.childId = childId
        obj.achievementKey = achievementKey
        obj.unlockedAt = Date()
        try? realmInstance.write { realmInstance.add(obj) }
    }

    /// Persists a sticker RewardRecord for a session — idempotent by sessionId.
    internal func persistStickerReward(
        childId: String,
        sessionId: String,
        stickerId: String
    ) async {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return }
        let existing = realmInstance.objects(RewardRecord.self)
            .filter("sessionId == %@", sessionId)
        guard existing.isEmpty else { return }
        let record = RewardRecord()
        record.childId = childId
        record.type = "sticker"
        record.rewardId = stickerId
        record.earnedAt = Date()
        record.sessionId = sessionId
        try? realmInstance.write { realmInstance.add(record, update: .modified) }
    }
}
