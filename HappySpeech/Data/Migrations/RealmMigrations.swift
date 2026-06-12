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
        if oldSchemaVersion < 12 {
            // v12: v31 Wave E —
            //  • ChildOralStoryObject (Ф.3 «Сочини историю») — локальные
            //    транскрипты устных историй ребёнка с TTR-метрикой;
            //  • EncryptedVideoClipObject (Ф.4 «Дневник речевого роста») —
            //    шифрованные локальные видео-метаданные (CryptoKit AES-GCM-256,
            //    ключ в Keychain). Сам клип и thumbnail — отдельные encrypted
            //    blob'ы в Documents/SpeechGrowthDiary/.
            // Оба объекта новые — Realm создаёт схему автоматически.
        }
        if oldSchemaVersion < 13 {
            // v13: VoiceJournal — added VoiceJournalEntryRealm
            // (childId/date/fileURLString/title/durationSeconds/transcript?).
            // Хранит метаданные локальных .m4a записей дневника голоса.
            // Realm создаёт схему автоматически, дефолты заданы в модели.
        }
        if oldSchemaVersion < 14 {
            // v14: CustomizationObject.outfit / .background — новые свойства
            // (выбранный наряд + фоновая сцена). Realm подставляет дефолты из
            // модели (everyday / meadow) для существующих записей —
            // enumerateObjects не требуется.
        }
        if oldSchemaVersion < 15 {
            // v15: FamilyChallengeObject (семейный челлендж: тип/цель/claimed-
            // недели) + LyalyaLetterObject (персистентные «письма от Ляли»).
            // Оба объекта новые — Realm создаёт схему автоматически, дефолты
            // заданы в моделях.
        }
        if oldSchemaVersion < 16 {
            // v16: LyalyaLetterObject.isDeleted (Bool) — новое поле soft-delete.
            // Realm проставит дефолт false для всех существующих записей
            // автоматически (значение объявлено в модели). Никаких enumerateObjects
            // не требуется — нужно только зафиксировать версию.
        }
        if oldSchemaVersion < 17 {
            // v17: PhonemeObservationObject («Фонемный паспорт») — пофонемные
            // GOP-наблюдения (childId/phoneme(IPA)/wordId/position/gop/posterior/
            // defect/competitor?/date). Только числа/IPA, без аудио/PII.
            // Новый объект — Realm создаёт схему автоматически, дефолты заданы
            // в модели. Никаких enumerateObjects не требуется.
        }
        if oldSchemaVersion < 18 {
            // v18: удалены мёртвые Realm-классы AdaptivePlan + RouteStep
            // (EmbeddedObject). Они никогда не инстанцировались, не читались и не
            // писались (0 ссылок в коде), их таблицы всегда были пустыми. Realm
            // автоматически удаляет неиспользуемые object-schema при отсутствии
            // класса — ручной enumerateObjects / deleteData не требуется, потери
            // пользовательских данных нет.
        }
    }
}

// MARK: - RealmActor Extension

public extension RealmActor {
    /// Fetches all objects of given type and returns as array (for use outside actor).
    /// Сбой открытия Realm логируется (не тихий) и возвращает `[]`.
    func fetch<T: Object>(_ type: T.Type) async -> [T] {
        do {
            let realmInstance = try await Realm(actor: self)
            return Array(realmInstance.objects(type))
        } catch {
            HSLogger.realm.error("fetch: Realm open failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// Writes a block to Realm on the actor.
    /// Ошибки открытия И записи логируются через `HSLogger.realm` — раньше `try?`
    /// глотал сбой записи без следа (риск тихой потери данных).
    func write(_ block: @escaping (Realm) -> Void) async {
        let realmInstance: Realm
        do {
            realmInstance = try await Realm(actor: self)
        } catch {
            HSLogger.realm.error("write: Realm open failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        do {
            try realmInstance.write { block(realmInstance) }
        } catch {
            HSLogger.realm.error("write: Realm write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Обёртка вокруг `realmInstance.write` с логированием ошибки (P2-7).
    ///
    /// Заменяет `loggedWrite(realmInstance) { ... }` во вспомогательных методах расширения:
    /// `try?` глотал сбой записи (диск полон, миграционный конфликт и т.д.) без следа.
    /// `loggedWrite` логирует ошибку через `HSLogger.realm` — тихой потери данных нет.
    ///
    /// - Parameters:
    ///   - realm: Уже открытый экземпляр Realm.
    ///   - context: Метка для лога — имя метода-вызывателя.
    ///   - block: Мутирующий блок.
    func loggedWrite(
        _ realm: Realm,
        context: String = #function,
        _ block: () -> Void
    ) {
        do {
            try realm.write(block)
        } catch {
            HSLogger.realm.error("\(context, privacy: .public): write failed — \(error.localizedDescription, privacy: .public)")
        }
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
        loggedWrite(realmInstance) { realmInstance.add(obj) }
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
        loggedWrite(realmInstance) { realmInstance.add(obj, update: .modified) }
    }

    /// Deletes a voice sample by id (returns true if existed).
    @discardableResult
    internal func deleteVoiceSample(id: String) async -> Bool {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance,
              let obj = realmInstance.object(ofType: VoiceSampleObject.self, forPrimaryKey: id) else {
            return false
        }
        loggedWrite(realmInstance) { realmInstance.delete(obj) }
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

        loggedWrite(realmInstance) {
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
        loggedWrite(realmInstance) { realmInstance.add(obj, update: .modified) }
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
        loggedWrite(realmInstance) { realmInstance.add(obj, update: .modified) }
    }

    /// Deletes a parent voice clip by id (returns true if existed).
    @discardableResult
    internal func deleteParentVoiceClip(id: String) async -> Bool {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance,
              let obj = realmInstance.object(ofType: ParentVoiceClipObject.self, forPrimaryKey: id) else {
            return false
        }
        loggedWrite(realmInstance) { realmInstance.delete(obj) }
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
        loggedWrite(realmInstance) {
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
        loggedWrite(realmInstance) { realmInstance.add(record, update: .modified) }
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
        loggedWrite(realmInstance) { realmInstance.add(obj) }
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
        loggedWrite(realmInstance) {
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
        loggedWrite(realmInstance) { realmInstance.delete(obj) }
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
        loggedWrite(realmInstance) {
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
        loggedWrite(realmInstance) { realmInstance.add(obj, update: .modified) }
    }

    // MARK: - v12 Wave E Ф.3: ChildOralStory helpers

    /// Fetches all oral stories of a child, newest first.
    internal func fetchOralStories(childId: String) async -> [ChildOralStoryData] {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return [] }
        return Array(
            realmInstance.objects(ChildOralStoryObject.self)
                .filter("childId == %@", childId)
                .sorted(byKeyPath: "createdAt", ascending: false)
        ).map { obj in
            ChildOralStoryData(
                id: obj.id,
                childId: obj.childId,
                createdAt: obj.createdAt,
                transcript: obj.transcript,
                durationSeconds: obj.durationSeconds,
                stimulusIds: Array(obj.stimulusIds),
                lexicalDiversity: obj.lexicalDiversity,
                totalWords: obj.totalWords,
                uniqueWords: obj.uniqueWords
            )
        }
    }

    /// Persists a new oral story.
    @discardableResult
    internal func persistOralStory(_ data: ChildOralStoryData) async -> Bool {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return false }
        let obj = ChildOralStoryObject()
        obj.id = data.id
        obj.childId = data.childId
        obj.createdAt = data.createdAt
        obj.transcript = data.transcript
        obj.durationSeconds = data.durationSeconds
        obj.stimulusIds.append(objectsIn: data.stimulusIds)
        obj.lexicalDiversity = data.lexicalDiversity
        obj.totalWords = data.totalWords
        obj.uniqueWords = data.uniqueWords
        loggedWrite(realmInstance) { realmInstance.add(obj, update: .modified) }
        return true
    }

    // MARK: - v12 Wave E Ф.4: EncryptedVideoClip helpers

    /// Fetches all encrypted video clips of a child, newest first.
    internal func fetchEncryptedVideoClips(childId: String) async -> [EncryptedVideoClipData] {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return [] }
        return Array(
            realmInstance.objects(EncryptedVideoClipObject.self)
                .filter("childId == %@", childId)
                .sorted(byKeyPath: "recordedAt", ascending: false)
        ).map { obj in
            EncryptedVideoClipData(
                id: obj.id,
                childId: obj.childId,
                recordedAt: obj.recordedAt,
                durationSeconds: obj.durationSeconds,
                encryptedClipPath: obj.encryptedClipPath,
                encryptedThumbnailPath: obj.encryptedThumbnailPath,
                topicTag: obj.topicTag,
                targetSound: obj.targetSound,
                note: obj.note,
                shareToken: obj.shareToken,
                shareTokenExpiresAt: obj.shareTokenExpiresAt
            )
        }
    }

    /// Persists a new encrypted video clip metadata.
    @discardableResult
    internal func persistEncryptedVideoClip(_ data: EncryptedVideoClipData) async -> Bool {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return false }
        let obj = EncryptedVideoClipObject()
        obj.id = data.id
        obj.childId = data.childId
        obj.recordedAt = data.recordedAt
        obj.durationSeconds = data.durationSeconds
        obj.encryptedClipPath = data.encryptedClipPath
        obj.encryptedThumbnailPath = data.encryptedThumbnailPath
        obj.topicTag = data.topicTag
        obj.targetSound = data.targetSound
        obj.note = data.note
        obj.shareToken = data.shareToken
        obj.shareTokenExpiresAt = data.shareTokenExpiresAt
        loggedWrite(realmInstance) { realmInstance.add(obj, update: .modified) }
        return true
    }

    /// Updates share-token metadata for a clip. Returns true if existed.
    @discardableResult
    internal func updateEncryptedClipShareToken(
        id: String,
        token: String?,
        expiresAt: Date?
    ) async -> Bool {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance,
              let obj = realmInstance.object(
                ofType: EncryptedVideoClipObject.self,
                forPrimaryKey: id
              )
        else { return false }
        loggedWrite(realmInstance) {
            obj.shareToken = token
            obj.shareTokenExpiresAt = expiresAt
        }
        return true
    }

    /// Deletes an encrypted clip by id (returns true if existed). Файлы на
    /// диске должна удалять вызывающая сторона отдельно.
    @discardableResult
    internal func deleteEncryptedVideoClip(id: String) async -> Bool {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance,
              let obj = realmInstance.object(
                ofType: EncryptedVideoClipObject.self,
                forPrimaryKey: id
              )
        else { return false }
        loggedWrite(realmInstance) { realmInstance.delete(obj) }
        return true
    }

    // MARK: - v13 VoiceJournal helpers

    /// Возвращает все записи дневника голоса конкретного ребёнка,
    /// отсортированные по дате (newest first). Принимает базовый URL
    /// Documents, чтобы корректно собрать абсолютный путь к файлам.
    internal func fetchVoiceJournalEntries(
        childId: String,
        documentsBaseURL: URL
    ) async -> [VoiceJournalEntry] {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return [] }
        return Array(
            realmInstance.objects(VoiceJournalEntryRealm.self)
                .filter("childId == %@", childId)
                .sorted(byKeyPath: "date", ascending: false)
        ).map { obj in
            VoiceJournalEntry(
                id: obj.id,
                childId: obj.childId,
                date: obj.date,
                fileURL: documentsBaseURL.appendingPathComponent(obj.fileURLString),
                title: obj.title,
                durationSeconds: obj.durationSeconds,
                transcript: obj.transcript
            )
        }
    }

    /// Сохраняет новую запись (idempotent по id). `relativePath` — путь
    /// относительно Documents, без префикса.
    @discardableResult
    // swiftlint:disable:next function_parameter_count
    internal func insertVoiceJournalEntry(
        id: String,
        childId: String,
        date: Date,
        relativePath: String,
        title: String,
        durationSeconds: Int,
        transcript: String?
    ) async -> Bool {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return false }
        let obj = VoiceJournalEntryRealm()
        obj.id = id
        obj.childId = childId
        obj.date = date
        obj.fileURLString = relativePath
        obj.title = title
        obj.durationSeconds = durationSeconds
        obj.transcript = transcript
        loggedWrite(realmInstance) { realmInstance.add(obj, update: .modified) }
        return true
    }

    /// Удаляет запись по id (возвращает true, если она существовала).
    @discardableResult
    internal func deleteVoiceJournalEntry(id: String) async -> Bool {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance,
              let obj = realmInstance.object(
                ofType: VoiceJournalEntryRealm.self,
                forPrimaryKey: id
              )
        else { return false }
        loggedWrite(realmInstance) { realmInstance.delete(obj) }
        return true
    }

    // MARK: - v15: Family challenge (семейный челлендж)

    /// Возвращает сохранённый челлендж семьи как Sendable DTO (nil, если нет).
    internal func fetchFamilyChallenge(parentId: String) async -> FamilyChallengeData? {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance,
              let obj = realmInstance.object(
                ofType: FamilyChallengeObject.self,
                forPrimaryKey: parentId
              )
        else { return nil }
        return FamilyChallengeData(
            parentId: obj.parentId,
            type: obj.type,
            goal: obj.goal,
            weekStart: obj.weekStart,
            claimedWeekStarts: Array(obj.claimedWeekStarts)
        )
    }

    /// Возвращает существующий челлендж или создаёт новый с дефолтами на
    /// текущую неделю. Идемпотентно: повторный вызов не плодит записи.
    internal func fetchOrCreateFamilyChallenge(
        parentId: String,
        defaultType: String,
        defaultGoal: Int,
        weekStart: Date
    ) async -> FamilyChallengeData {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else {
            return FamilyChallengeData(
                parentId: parentId,
                type: defaultType,
                goal: defaultGoal,
                weekStart: weekStart,
                claimedWeekStarts: []
            )
        }
        if let obj = realmInstance.object(ofType: FamilyChallengeObject.self, forPrimaryKey: parentId) {
            return FamilyChallengeData(
                parentId: obj.parentId,
                type: obj.type,
                goal: obj.goal,
                weekStart: obj.weekStart,
                claimedWeekStarts: Array(obj.claimedWeekStarts)
            )
        }
        let obj = FamilyChallengeObject()
        obj.parentId = parentId
        obj.type = defaultType
        obj.goal = defaultGoal
        obj.weekStart = weekStart
        loggedWrite(realmInstance) { realmInstance.add(obj, update: .modified) }
        return FamilyChallengeData(
            parentId: parentId,
            type: defaultType,
            goal: defaultGoal,
            weekStart: weekStart,
            claimedWeekStarts: []
        )
    }

    /// Помечает неделю как «награда получена». Идемпотентно (повтор — noop).
    /// Возвращает обновлённое число закрытых недель подряд.
    @discardableResult
    internal func claimFamilyChallengeWeek(parentId: String, weekStart: Date) async -> Int {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance,
              let obj = realmInstance.object(ofType: FamilyChallengeObject.self, forPrimaryKey: parentId)
        else { return 0 }
        loggedWrite(realmInstance) {
            if !obj.claimedWeekStarts.contains(weekStart) {
                obj.claimedWeekStarts.append(weekStart)
            }
        }
        return obj.claimedWeekStarts.count
    }

    // MARK: - v15/v16: Lyalya letters (письма от Ляли)

    /// Возвращает письма ребёнка как Sendable DTO, отсортированные по дате desc.
    /// Письма с `isDeleted = true` (soft-delete, v16) исключаются из результата.
    internal func fetchLyalyaLetters(childId: String) async -> [LyalyaLetterData] {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return [] }
        return Array(
            realmInstance.objects(LyalyaLetterObject.self)
                .filter("childId == %@ AND isDeleted == false", childId)
                .sorted(byKeyPath: "date", ascending: false)
        ).map { obj in
            LyalyaLetterData(
                id: obj.id,
                childId: obj.childId,
                kind: obj.kind,
                title: obj.title,
                body: obj.body,
                date: obj.date,
                isRead: obj.isRead,
                audioFileName: obj.audioFileName.isEmpty ? nil : obj.audioFileName
            )
        }
    }

    /// Вставляет письмо, если письма с таким id ещё нет (идемпотентно по id).
    internal func insertLyalyaLetterIfAbsent(_ data: LyalyaLetterData) async {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance else { return }
        guard realmInstance.object(ofType: LyalyaLetterObject.self, forPrimaryKey: data.id) == nil else {
            return
        }
        let obj = LyalyaLetterObject()
        obj.id = data.id
        obj.childId = data.childId
        obj.kind = data.kind
        obj.title = data.title
        obj.body = data.body
        obj.date = data.date
        obj.isRead = data.isRead
        obj.audioFileName = data.audioFileName ?? ""
        loggedWrite(realmInstance) { realmInstance.add(obj, update: .modified) }
    }

    /// Отмечает письмо прочитанным. Возвращает обновлённое письмо (nil, если нет).
    internal func markLyalyaLetterRead(letterId: String) async -> LyalyaLetterData? {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance,
              let obj = realmInstance.object(ofType: LyalyaLetterObject.self, forPrimaryKey: letterId)
        else { return nil }
        loggedWrite(realmInstance) { obj.isRead = true }
        return LyalyaLetterData(
            id: obj.id,
            childId: obj.childId,
            kind: obj.kind,
            title: obj.title,
            body: obj.body,
            date: obj.date,
            isRead: obj.isRead,
            audioFileName: obj.audioFileName.isEmpty ? nil : obj.audioFileName
        )
    }

    /// Удаляет письмо по id.
    ///
    /// Все письма используют soft-delete (`isDeleted = true`) — физическое
    /// удаление из Realm не применяется. Это гарантирует, что
    /// `insertLyalyaLetterIfAbsent` не воскресит письмо при следующем
    /// вызове `loadMail`: объект с данным id уже существует → вставка
    /// пропускается. `fetchLyalyaLetters` фильтрует `isDeleted = true`.
    ///
    /// Возвращает `true`, если объект существовал и был помечен удалённым.
    @discardableResult
    internal func deleteLyalyaLetter(letterId: String) async -> Bool {
        let realmInstance = try? await Realm(actor: self)
        guard let realmInstance,
              let obj = realmInstance.object(ofType: LyalyaLetterObject.self, forPrimaryKey: letterId),
              !obj.isDeleted
        else { return false }
        loggedWrite(realmInstance) { obj.isDeleted = true }
        return true
    }
}
