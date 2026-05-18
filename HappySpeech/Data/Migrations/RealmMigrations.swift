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
        if oldSchemaVersion < 8 {
            // v8: Block T v17 — added VoiceSampleObject (T.1 VoiceCloning),
            // LeaderboardEntryObject (T.3 PronunciationLeaderboard),
            // InsightObject (T.4 NeurolinguistInsights).
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
    /// Бросает ошибку при сбое открытия Realm — вызывающая сторона должна
    /// отличать «нет записей» от «не удалось прочитать хранилище».
    internal func fetchFluencySessions() async throws -> [FluencySessionData] {
        let realmInstance = try await Realm(actor: self)
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

    // MARK: - Block T v17: VoiceSample / Leaderboard / Insight helpers

    /// Fetches voice samples for a given child as Sendable DTOs, sorted by recordedAt desc.
    internal func fetchVoiceSamples(childId: String) async -> [VoiceSampleData] {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return [] }
        return Array(
            realmInstance.objects(VoiceSampleObject.self)
                .filter("childId == %@", childId)
                .sorted(byKeyPath: "recordedAt", ascending: false)
        ).map { obj in
            VoiceSampleData(
                id: obj.id,
                childId: obj.childId,
                word: obj.word,
                targetSound: obj.targetSound,
                audioFilePath: obj.audioFilePath,
                durationSeconds: obj.durationSeconds,
                recordedAt: obj.recordedAt,
                note: obj.note
            )
        }
    }

    /// Persists a new voice sample. Idempotent by primary key id.
    internal func persistVoiceSample(_ data: VoiceSampleData) async {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return }
        let obj = VoiceSampleObject()
        obj.id = data.id
        obj.childId = data.childId
        obj.word = data.word
        obj.targetSound = data.targetSound
        obj.audioFilePath = data.audioFilePath
        obj.durationSeconds = data.durationSeconds
        obj.recordedAt = data.recordedAt
        obj.note = data.note
        try? realmInstance.write { realmInstance.add(obj, update: .modified) }
    }

    /// Deletes a voice sample by id (returns true if existed).
    @discardableResult
    internal func deleteVoiceSample(id: String) async -> Bool {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance,
              let obj = realmInstance.object(ofType: VoiceSampleObject.self, forPrimaryKey: id) else {
            return false
        }
        try? realmInstance.write { realmInstance.delete(obj) }
        return true
    }

    /// Fetches leaderboard entries for a parentId (family scope), sorted by weeklyAccuracy desc.
    internal func fetchLeaderboardEntries(parentId: String) async -> [LeaderboardEntryData] {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return [] }
        return Array(
            realmInstance.objects(LeaderboardEntryObject.self)
                .filter("parentId == %@", parentId)
        ).map { obj in
            LeaderboardEntryData(
                id: obj.id,
                childId: obj.childId,
                parentId: obj.parentId,
                weekKey: obj.weekKey,
                weeklyAccuracy: obj.weeklyAccuracy,
                sessionsCount: obj.sessionsCount,
                totalAttempts: obj.totalAttempts,
                correctAttempts: obj.correctAttempts,
                updatedAt: obj.updatedAt
            )
        }
    }

    /// Upserts a leaderboard entry by (childId, weekKey).
    internal func upsertLeaderboardEntry(_ data: LeaderboardEntryData) async {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return }
        let existing = realmInstance.objects(LeaderboardEntryObject.self)
            .filter("childId == %@ AND weekKey == %@", data.childId, data.weekKey)
            .first

        try? realmInstance.write {
            if let existing {
                existing.weeklyAccuracy = data.weeklyAccuracy
                existing.sessionsCount = data.sessionsCount
                existing.totalAttempts = data.totalAttempts
                existing.correctAttempts = data.correctAttempts
                existing.updatedAt = data.updatedAt
                existing.parentId = data.parentId
            } else {
                let obj = LeaderboardEntryObject()
                obj.id = data.id
                obj.childId = data.childId
                obj.parentId = data.parentId
                obj.weekKey = data.weekKey
                obj.weeklyAccuracy = data.weeklyAccuracy
                obj.sessionsCount = data.sessionsCount
                obj.totalAttempts = data.totalAttempts
                obj.correctAttempts = data.correctAttempts
                obj.updatedAt = data.updatedAt
                realmInstance.add(obj, update: .modified)
            }
        }
    }

    /// Fetches latest InsightObject for a given child (or nil).
    internal func fetchLatestInsight(childId: String) async -> InsightData? {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return nil }
        let obj = realmInstance.objects(InsightObject.self)
            .filter("childId == %@", childId)
            .sorted(byKeyPath: "generatedAt", ascending: false)
            .first
        guard let obj else { return nil }
        return InsightData(
            id: obj.id,
            childId: obj.childId,
            generatedAt: obj.generatedAt,
            summaryText: obj.summaryText,
            trendLabel: obj.trendLabel,
            sessionsAnalyzedCount: obj.sessionsAnalyzedCount,
            primarySoundFocus: obj.primarySoundFocus,
            recommendation: obj.recommendation
        )
    }

    /// Persists a freshly generated InsightObject for a child.
    internal func persistInsight(_ data: InsightData) async {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return }
        let obj = InsightObject()
        obj.id = data.id
        obj.childId = data.childId
        obj.generatedAt = data.generatedAt
        obj.summaryText = data.summaryText
        obj.trendLabel = data.trendLabel
        obj.sessionsAnalyzedCount = data.sessionsAnalyzedCount
        obj.primarySoundFocus = data.primarySoundFocus
        obj.recommendation = data.recommendation
        try? realmInstance.write { realmInstance.add(obj, update: .modified) }
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
