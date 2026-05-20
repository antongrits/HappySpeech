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
        if oldSchemaVersion < 9 {
            // v9: v31 Волна B — added ParentVoiceClipObject
            // (ParentVoiceNote: «Мамин голос» в LessonPlayer hero-зоне).
            // Realm создаёт схему автоматически, дефолты заданы в модели.
        }
        if oldSchemaVersion < 10 {
            // v10: v31 Волна C — added StickerInventoryObject (Ф.1 RewardShop)
            // + CustomWordListObject (Ф.4 CustomWordList специалиста).
            // Оба объекта новые — Realm создаёт схему автоматически, дефолты
            // заданы в моделях.
        }
        if oldSchemaVersion < 11 {
            // v11: v31 Волна D —
            //  • LexicalItemReviewObject (Ф.2 FSRS-6 spaced repetition для
            //    LexicalThemes — open-spaced-repetition порт);
            //  • AssessmentResultObject (Ф.3 SpecialistAssessment —
            //    10-вопросная первичная оценка по фреймворку Левиной/Архиповой).
            // Оба объекта новые — Realm создаёт схему автоматически,
            // дефолты заданы в моделях. Никаких ручных enumerateObjects.
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

    // MARK: - v9 v31 Волна B: ParentVoiceClip helpers

    /// Fetches parent voice clips for a child, sorted by recordedAt desc.
    internal func fetchParentVoiceClips(childId: String) async -> [ParentVoiceClipData] {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return [] }
        return Array(
            realmInstance.objects(ParentVoiceClipObject.self)
                .filter("childId == %@", childId)
                .sorted(byKeyPath: "recordedAt", ascending: false)
        ).map { obj in
            ParentVoiceClipData(
                id: obj.id,
                childId: obj.childId,
                lessonTemplate: obj.lessonTemplate,
                fileURL: obj.fileURL,
                durationSec: obj.durationSec,
                recordedAt: obj.recordedAt,
                isEnabled: obj.isEnabled
            )
        }
    }

    /// Fetches the active enabled parent voice clip for a (childId, lessonTemplate),
    /// если есть. Берёт самую свежую.
    internal func fetchActiveParentVoiceClip(
        childId: String,
        lessonTemplate: String
    ) async -> ParentVoiceClipData? {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return nil }
        let result = realmInstance.objects(ParentVoiceClipObject.self)
            .filter(
                "childId == %@ AND lessonTemplate == %@ AND isEnabled == true",
                childId, lessonTemplate
            )
            .sorted(byKeyPath: "recordedAt", ascending: false)
            .first
        guard let obj = result else { return nil }
        return ParentVoiceClipData(
            id: obj.id,
            childId: obj.childId,
            lessonTemplate: obj.lessonTemplate,
            fileURL: obj.fileURL,
            durationSec: obj.durationSec,
            recordedAt: obj.recordedAt,
            isEnabled: obj.isEnabled
        )
    }

    /// Upserts a parent voice clip by id.
    internal func persistParentVoiceClip(_ data: ParentVoiceClipData) async {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return }
        let obj = ParentVoiceClipObject()
        obj.id = data.id
        obj.childId = data.childId
        obj.lessonTemplate = data.lessonTemplate
        obj.fileURL = data.fileURL
        obj.durationSec = data.durationSec
        obj.recordedAt = data.recordedAt
        obj.isEnabled = data.isEnabled
        try? realmInstance.write { realmInstance.add(obj, update: .modified) }
    }

    /// Deletes a parent voice clip by id (returns true if existed).
    @discardableResult
    internal func deleteParentVoiceClip(id: String) async -> Bool {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance,
              let obj = realmInstance.object(ofType: ParentVoiceClipObject.self, forPrimaryKey: id) else {
            return false
        }
        try? realmInstance.write { realmInstance.delete(obj) }
        return true
    }

    /// Toggles isEnabled for all clips of a child (used by Settings opt-in).
    internal func setParentVoiceClipsEnabled(
        childId: String,
        isEnabled: Bool
    ) async {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return }
        let clips = realmInstance.objects(ParentVoiceClipObject.self)
            .filter("childId == %@", childId)
        try? realmInstance.write {
            for clip in clips {
                clip.isEnabled = isEnabled
            }
        }
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

    // MARK: - v10 v31 Волна C Ф.1: Sticker inventory

    /// Fetches owned stickers for a child as Sendable DTOs.
    internal func fetchStickerInventory(childId: String) async -> [StickerInventoryData] {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return [] }
        return Array(
            realmInstance.objects(StickerInventoryObject.self)
                .filter("childId == %@", childId)
                .sorted(byKeyPath: "purchasedAt", ascending: false)
        ).map { obj in
            StickerInventoryData(
                id: obj.id,
                childId: obj.childId,
                stickerId: obj.stickerId,
                purchasedAt: obj.purchasedAt,
                priceSpent: obj.priceSpent
            )
        }
    }

    /// Persists a sticker purchase. Idempotent: noop if same (childId, stickerId) уже куплен.
    @discardableResult
    internal func persistStickerPurchase(
        childId: String,
        stickerId: String,
        price: Int
    ) async -> Bool {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return false }
        let existing = realmInstance.objects(StickerInventoryObject.self)
            .filter("childId == %@ AND stickerId == %@", childId, stickerId)
        guard existing.isEmpty else { return false }
        let obj = StickerInventoryObject()
        obj.childId = childId
        obj.stickerId = stickerId
        obj.purchasedAt = Date()
        obj.priceSpent = price
        try? realmInstance.write { realmInstance.add(obj) }
        return true
    }

    /// Total coins spent by a child on stickers — sum of `priceSpent`.
    internal func sumStickerSpending(childId: String) async -> Int {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return 0 }
        return realmInstance.objects(StickerInventoryObject.self)
            .filter("childId == %@", childId)
            .reduce(0) { $0 + $1.priceSpent }
    }

    /// Count of RewardRecord entries for a child — used to derive earned coins.
    /// 1 reward record ≈ 1 coin. RewardShop is local-only / no real-money IAP.
    internal func countRewardRecords(childId: String) async -> Int {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return 0 }
        return realmInstance.objects(RewardRecord.self)
            .filter("childId == %@", childId)
            .count
    }

    // MARK: - v10 v31 Волна C Ф.4: Custom word lists (специалист)

    /// Fetches custom word lists authored by a specialist, sorted by updatedAt desc.
    internal func fetchCustomWordLists(specialistId: String) async -> [CustomWordListData] {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return [] }
        return Array(
            realmInstance.objects(CustomWordListObject.self)
                .filter("specialistId == %@", specialistId)
                .sorted(byKeyPath: "updatedAt", ascending: false)
        ).map { obj in
            CustomWordListData(
                id: obj.id,
                specialistId: obj.specialistId,
                name: obj.name,
                targetSound: obj.targetSound,
                words: Array(obj.words),
                createdAt: obj.createdAt,
                updatedAt: obj.updatedAt
            )
        }
    }

    /// Upserts a custom word list by id (idempotent).
    internal func persistCustomWordList(_ data: CustomWordListData) async {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return }
        try? realmInstance.write {
            let obj = realmInstance.object(
                ofType: CustomWordListObject.self,
                forPrimaryKey: data.id
            ) ?? CustomWordListObject()
            obj.id = data.id
            obj.specialistId = data.specialistId
            obj.name = data.name
            obj.targetSound = data.targetSound
            obj.words.removeAll()
            obj.words.append(objectsIn: data.words)
            if obj.realm == nil {
                obj.createdAt = data.createdAt
                realmInstance.add(obj)
            }
            obj.updatedAt = data.updatedAt
        }
    }

    /// Deletes a custom word list by id (returns true if existed).
    @discardableResult
    internal func deleteCustomWordList(id: String) async -> Bool {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance,
              let obj = realmInstance.object(ofType: CustomWordListObject.self, forPrimaryKey: id) else {
            return false
        }
        try? realmInstance.write { realmInstance.delete(obj) }
        return true
    }

    // MARK: - v11 v31 Волна D Ф.2: FSRS-6 review state

    /// Fetches all review records for a child as Sendable DTOs.
    internal func fetchLexicalReviews(childId: String) async -> [LexicalItemReviewData] {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return [] }
        return Array(
            realmInstance.objects(LexicalItemReviewObject.self)
                .filter("childId == %@", childId)
        ).map { obj in
            LexicalItemReviewData(
                id: obj.id,
                childId: obj.childId,
                wordId: obj.wordId,
                stability: obj.stability,
                difficulty: obj.difficulty,
                lastReview: obj.lastReview,
                nextReview: obj.nextReview,
                reps: obj.reps,
                lapses: obj.lapses
            )
        }
    }

    /// Fetches one review record for (childId, wordId).
    internal func fetchLexicalReview(
        childId: String,
        wordId: String
    ) async -> LexicalItemReviewData? {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return nil }
        let obj = realmInstance.objects(LexicalItemReviewObject.self)
            .filter("childId == %@ AND wordId == %@", childId, wordId)
            .first
        guard let obj else { return nil }
        return LexicalItemReviewData(
            id: obj.id,
            childId: obj.childId,
            wordId: obj.wordId,
            stability: obj.stability,
            difficulty: obj.difficulty,
            lastReview: obj.lastReview,
            nextReview: obj.nextReview,
            reps: obj.reps,
            lapses: obj.lapses
        )
    }

    /// Upserts a review record by (childId, wordId). Создаёт новый объект,
    /// если ещё нет.
    internal func upsertLexicalReview(_ data: LexicalItemReviewData) async {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return }
        try? realmInstance.write {
            let existing = realmInstance.objects(LexicalItemReviewObject.self)
                .filter("childId == %@ AND wordId == %@", data.childId, data.wordId)
                .first
            let target = existing ?? LexicalItemReviewObject()
            target.id = data.id
            target.childId = data.childId
            target.wordId = data.wordId
            target.stability = data.stability
            target.difficulty = data.difficulty
            target.lastReview = data.lastReview
            target.nextReview = data.nextReview
            target.reps = data.reps
            target.lapses = data.lapses
            if existing == nil {
                realmInstance.add(target)
            }
        }
    }

    // MARK: - v11 v31 Волна D Ф.3: SpecialistAssessment

    /// Fetches the most recent assessment result for a child (or nil).
    internal func fetchLatestAssessment(childId: String) async -> AssessmentResultData? {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return nil }
        let obj = realmInstance.objects(AssessmentResultObject.self)
            .filter("childId == %@", childId)
            .sorted(byKeyPath: "completedAt", ascending: false)
            .first
        guard let obj else { return nil }
        return AssessmentResultData(
            id: obj.id,
            childId: obj.childId,
            specialistId: obj.specialistId,
            completedAt: obj.completedAt,
            answers: Array(obj.answers),
            recommendedFocus: Array(obj.recommendedFocus),
            validUntil: obj.validUntil
        )
    }

    /// Persists a new assessment result.
    internal func persistAssessment(_ data: AssessmentResultData) async {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return }
        let obj = AssessmentResultObject()
        obj.id = data.id
        obj.childId = data.childId
        obj.specialistId = data.specialistId
        obj.completedAt = data.completedAt
        obj.answers.append(objectsIn: data.answers)
        obj.recommendedFocus.append(objectsIn: data.recommendedFocus)
        obj.validUntil = data.validUntil
        try? realmInstance.write { realmInstance.add(obj, update: .modified) }
    }
}
