import Foundation
import RealmSwift

// MARK: - ChildProfile

final class ChildProfile: Object, @unchecked Sendable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var name: String = ""
    @Persisted var age: Int = 6                           // 5–8
    @Persisted var targetSounds: List<String>              // ["С", "Ш", "Р"]
    @Persisted var createdAt: Date = Date()
    @Persisted var parentId: String = ""
    @Persisted var progressSummary: Map<String, Double>   // soundTarget -> overallRate 0.0–1.0
    @Persisted var avatarStyle: String = "butterfly"
    @Persisted var colorTheme: String = "coral"
    @Persisted var sensitivityLevel: Int = 1              // 0=gentle, 1=normal, 2=challenging
    @Persisted var isArchived: Bool = false
    @Persisted var totalSessionMinutes: Int = 0
    @Persisted var currentStreak: Int = 0
    @Persisted var lastSessionAt: Date?
}

// MARK: - Session

final class Session: Object, @unchecked Sendable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var childId: String = ""
    @Persisted var date: Date = Date()
    @Persisted var templateType: String = ""               // TemplateType.rawValue
    @Persisted var targetSound: String = ""                // "Р"
    @Persisted var stage: String = ""                      // CorrectionStage.rawValue
    @Persisted var durationSeconds: Int = 0
    @Persisted var totalAttempts: Int = 0
    @Persisted var correctAttempts: Int = 0
    @Persisted var fatigueDetected: Bool = false
    @Persisted var isSynced: Bool = false
    @Persisted var attempts: List<Attempt>

    var successRate: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(correctAttempts) / Double(totalAttempts)
    }
}

// MARK: - Attempt (EmbeddedObject)

final class Attempt: EmbeddedObject, @unchecked Sendable {
    @Persisted var id: String = UUID().uuidString
    @Persisted var word: String = ""
    @Persisted var audioLocalPath: String = ""             // local file path on device
    @Persisted var audioStoragePath: String = ""           // Firebase Storage path (set after sync)
    @Persisted var asrTranscript: String = ""
    @Persisted var asrScore: Double = 0.0
    @Persisted var pronunciationScore: Double = -1.0       // -1 = not yet scored
    @Persisted var manualScore: Double = -1.0              // -1 = not set
    @Persisted var isCorrect: Bool = false
    @Persisted var timestamp: Date = Date()
}

// MARK: - ContentPackMeta

final class ContentPackMetaRealm: Object, @unchecked Sendable {
    @Persisted(primaryKey: true) var id: String = ""       // "С-stage0-v1"
    @Persisted var soundTarget: String = ""
    @Persisted var stage: String = ""
    @Persisted var templateType: String = ""
    @Persisted var version: String = "1.0"
    @Persisted var isDownloaded: Bool = false
    @Persisted var isBundled: Bool = false
    @Persisted var storageUrl: String = ""
    @Persisted var sizeBytes: Int = 0
    @Persisted var lastSyncAt: Date?
}

// MARK: - AdaptivePlan

final class AdaptivePlan: Object, @unchecked Sendable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var childId: String = ""
    @Persisted var date: Date = Date()
    @Persisted var plannedRoute: List<RouteStep>
    @Persisted var actualRoute: List<RouteStep>
    @Persisted var fatigueLevel: Int = 0                   // 0=fresh, 1=normal, 2=tired
    @Persisted var llmSummary: String?
    @Persisted var homeTask: String?
    @Persisted var isCompleted: Bool = false
}

// MARK: - RouteStep (EmbeddedObject)

final class RouteStep: EmbeddedObject, @unchecked Sendable {
    @Persisted var templateType: String = ""
    @Persisted var targetSound: String = ""
    @Persisted var stage: String = ""
    @Persisted var difficulty: Int = 1
    @Persisted var wordCount: Int = 8
    @Persisted var durationTargetSec: Int = 180
    @Persisted var completed: Bool = false
}

// MARK: - SyncQueueItem

final class SyncQueueItem: Object, @unchecked Sendable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var entityType: String = ""                 // "session" | "attempt" | "childProfile"
    @Persisted var entityId: String = ""
    @Persisted var operation: String = ""                  // "upsert" | "delete"
    @Persisted var payload: String = ""                    // JSON string
    @Persisted var createdAt: Date = Date()
    @Persisted var syncedAt: Date?
    @Persisted var retryCount: Int = 0
    @Persisted var lastErrorMessage: String?
}

// MARK: - ProgressEntry

final class ProgressEntry: Object, @unchecked Sendable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var childId: String = ""
    @Persisted var soundTarget: String = ""
    @Persisted var stage: String = ""
    @Persisted var date: Date = Date()
    @Persisted var sessionCount: Int = 0
    @Persisted var successRate: Double = 0.0
    @Persisted var isStageCompleted: Bool = false
}

// MARK: - RewardRecord

final class RewardRecord: Object, @unchecked Sendable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var childId: String = ""
    @Persisted var type: String = ""                       // "sticker" | "badge" | "streak"
    @Persisted var rewardId: String = ""
    @Persisted var earnedAt: Date = Date()
    @Persisted var sessionId: String?
}

// MARK: - FluencySessionObject (v6)
// Stores Fluency Diary session data for StutteringModule.
// Metrics shown only in Parent Dashboard, not in kid UI.

final class FluencySessionObject: Object, @unchecked Sendable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var date: Date = Date()
    @Persisted var dysfluencyCount: Int = 0
    @Persisted var totalSyllables: Int = 0
    @Persisted var rate: Float = 0              // dysfluencyCount * 100 / totalSyllables
    @Persisted var transcript: String = ""
}

// MARK: - UnlockedAchievementObject (v7)
// Stores per-child unlocked achievements. Offline-only, COPPA compliant.

final class UnlockedAchievementObject: Object, @unchecked Sendable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var childId: String = ""
    @Persisted var achievementKey: String = ""    // Achievement.rawValue
    @Persisted var unlockedAt: Date = Date()
}

// MARK: - UnlockedAchievementData (Sendable DTO)

struct UnlockedAchievementData: Sendable {
    let id: String
    let childId: String
    let achievementKey: String
    let unlockedAt: Date
}

// MARK: - ChildProfileData (minimal Sendable DTO for sibling leaderboard)

struct ChildProfileData: Sendable {
    let id: String
    let name: String
    let parentId: String
}

// MARK: - VoiceSampleObject (v8 — Block T v17 / VoiceCloningScreen)
//
// Запись голоса ребёнка для self-comparison ("Послушай себя через неделю").
// COPPA-safe: данные хранятся только локально в Documents/VoiceArchive/.
// audioFilePath — относительный путь от Documents (без абсолютного префикса).

final class VoiceSampleObject: Object, @unchecked Sendable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var childId: String = ""
    @Persisted var word: String = ""                  // Произнесённое слово / фраза
    @Persisted var targetSound: String = ""           // "С", "Ш" и т.д.
    @Persisted var audioFilePath: String = ""         // относительный путь от Documents/
    @Persisted var durationSeconds: Double = 0
    @Persisted var recordedAt: Date = Date()
    @Persisted var note: String = ""                  // комментарий ребёнка (через preset)
}

// MARK: - VoiceSampleData (Sendable DTO)

struct VoiceSampleData: Sendable, Identifiable {
    let id: String
    let childId: String
    let word: String
    let targetSound: String
    let audioFilePath: String
    let durationSeconds: Double
    let recordedAt: Date
    let note: String
}

// MARK: - LeaderboardEntryObject (v8 — Block T v17 / PronunciationLeaderboard)
//
// Снимок недельного результата ребёнка для семейного рейтинга.
// COPPA-safe: ranking только внутри одной семьи (parentId).
// week — ISO week (yearWeek 202618) для агрегации.

final class LeaderboardEntryObject: Object, @unchecked Sendable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var childId: String = ""
    @Persisted var parentId: String = ""
    @Persisted var weekKey: String = ""              // "2026-W18"
    @Persisted var weeklyAccuracy: Double = 0        // 0.0–1.0
    @Persisted var sessionsCount: Int = 0
    @Persisted var totalAttempts: Int = 0
    @Persisted var correctAttempts: Int = 0
    @Persisted var updatedAt: Date = Date()
}

// MARK: - LeaderboardEntryData (Sendable DTO)

struct LeaderboardEntryData: Sendable, Identifiable {
    let id: String
    let childId: String
    let parentId: String
    let weekKey: String
    let weeklyAccuracy: Double
    let sessionsCount: Int
    let totalAttempts: Int
    let correctAttempts: Int
    let updatedAt: Date
}

// MARK: - InsightObject (v8 — Block T v17 / NeurolinguistInsights)
//
// Сохранённый AI-summary прогресса ребёнка (rule-based template, не реальный LLM).
// Генерируется из последних N сессий (Realm). Кэшируется на 24 часа.

final class InsightObject: Object, @unchecked Sendable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var childId: String = ""
    @Persisted var generatedAt: Date = Date()
    @Persisted var summaryText: String = ""           // Russian Markdown summary
    @Persisted var trendLabel: String = ""            // "improving" | "stable" | "declining"
    @Persisted var sessionsAnalyzedCount: Int = 0
    @Persisted var primarySoundFocus: String = ""    // "Р"
    @Persisted var recommendation: String = ""
}

// MARK: - InsightData (Sendable DTO)

struct InsightData: Sendable, Identifiable {
    let id: String
    let childId: String
    let generatedAt: Date
    let summaryText: String
    let trendLabel: String
    let sessionsAnalyzedCount: Int
    let primarySoundFocus: String
    let recommendation: String
}

// MARK: - ParentVoiceClipObject (v9 — v31 Волна B / ParentVoiceNote)
//
// Голосовая записка родителя (до 30 сек), привязанная к шаблону урока.
// Ребёнок может нажать «Мамин голос» в hero-зоне LessonPlayer и услышать
// записанное родителем подбадривание. Хранится только локально в
// Documents/ParentVoiceNotes/ — COPPA-safe, не синхронизируется в Firestore.

final class ParentVoiceClipObject: Object, @unchecked Sendable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var childId: String = ""
    @Persisted var lessonTemplate: String = ""        // GameType.rawValue / templateType
    @Persisted var fileURL: String = ""               // относительный путь от Documents/
    @Persisted var durationSec: Double = 0
    @Persisted var recordedAt: Date = Date()
    /// Глобальный per-child opt-in flag должен быть включён в Settings,
    /// чтобы кнопка появлялась в LessonPlayer hero-зоне. Здесь дублируется
    /// для удобства фильтрации в Realm.
    @Persisted var isEnabled: Bool = true
}

// MARK: - ParentVoiceClipData (Sendable DTO)

struct ParentVoiceClipData: Sendable, Identifiable, Equatable {
    let id: String
    let childId: String
    let lessonTemplate: String
    let fileURL: String
    let durationSec: Double
    let recordedAt: Date
    let isEnabled: Bool
}

// MARK: - StickerInventoryObject (v10 — v31 Волна C Ф.1 «Магазин наград»)
//
// Хранит купленные стикеры ребёнка. Монеты заработаны через RewardRecord
// (1 завершённая сессия ≈ 1 монета). Полностью offline / on-device.

final class StickerInventoryObject: Object, @unchecked Sendable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var childId: String = ""
    @Persisted var stickerId: String = ""
    @Persisted var purchasedAt: Date = Date()
    @Persisted var priceSpent: Int = 0
}

// MARK: - StickerInventoryData (Sendable DTO)

struct StickerInventoryData: Sendable, Identifiable {
    let id: String
    let childId: String
    let stickerId: String
    let purchasedAt: Date
    let priceSpent: Int
}

// MARK: - CustomWordListObject (v10 — v31 Волна C Ф.4 «Списки слов специалиста»)
//
// Логопед-составленный список слов, который ContentEngine превращает
// в упражнения (repeat-after-model / bingo / memory). Хранится локально,
// никаких внешних трекеров (CLAUDE.md §11).

final class CustomWordListObject: Object, @unchecked Sendable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var specialistId: String = ""
    @Persisted var name: String = ""                  // «Список Р-1»
    @Persisted var targetSound: String = ""           // «Р» / «Ш» / …
    @Persisted var words: List<String>                // плоский список слов
    @Persisted var createdAt: Date = Date()
    @Persisted var updatedAt: Date = Date()
}

// MARK: - CustomWordListData (Sendable DTO)

struct CustomWordListData: Sendable, Identifiable, Equatable {
    let id: String
    let specialistId: String
    let name: String
    let targetSound: String
    let words: [String]
    let createdAt: Date
    let updatedAt: Date
}

// MARK: - LexicalItemReviewObject (v11 — v31 Волна D Ф.2 «FSRS-6 spaced repetition»)
//
// Per-word review state по алгоритму FSRS-6 (open-spaced-repetition, MIT).
// Хранит интервалы для конкретного слова в LexicalThemes — следующее
// повторение выбирается из числа `due` слов раньше случайных новых.
// Полностью offline / on-device. Никаких внешних трекеров.

final class LexicalItemReviewObject: Object, @unchecked Sendable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var childId: String = ""
    @Persisted var wordId: String = ""
    /// FSRS «Stability» — характеризует, как долго слово помнится.
    @Persisted var stability: Double = 0
    /// FSRS «Difficulty» — сложность слова 1.0…10.0.
    @Persisted var difficulty: Double = 5.0
    @Persisted var lastReview: Date = Date()
    @Persisted var nextReview: Date = Date()
    /// Общее количество ревью.
    @Persisted var reps: Int = 0
    /// Сколько раз ребёнок «забыл» (Again rating).
    @Persisted var lapses: Int = 0
}

// MARK: - LexicalItemReviewData (Sendable DTO)

struct LexicalItemReviewData: Sendable, Identifiable, Equatable {
    let id: String
    let childId: String
    let wordId: String
    let stability: Double
    let difficulty: Double
    let lastReview: Date
    let nextReview: Date
    let reps: Int
    let lapses: Int
}

// MARK: - AssessmentResultObject (v11 — v31 Волна D Ф.3 «SpecialistAssessment»)
//
// Результаты 10-вопросной первичной оценки специалиста по фреймворку
// Левиной/Архиповой (артикуляция, фонология, лексика, грамматика,
// связная речь). Не диагностический инструмент — рекомендация фокуса
// для AdaptivePlannerService на ближайшие 2 недели (CLAUDE.md §11).

final class AssessmentResultObject: Object, @unchecked Sendable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var childId: String = ""
    @Persisted var specialistId: String = ""
    @Persisted var completedAt: Date = Date()
    /// Сериализованные ответы (`questionId|answerValue`, по строке на ответ).
    @Persisted var answers: List<String>
    /// Рекомендованный фокус, json-array строк (sound groups / axes).
    @Persisted var recommendedFocus: List<String>
    /// Целевая дата окончания применения рекомендации (~+14 дней).
    @Persisted var validUntil: Date = Date().addingTimeInterval(14 * 24 * 3600)
}

// MARK: - AssessmentResultData (Sendable DTO)

struct AssessmentResultData: Sendable, Identifiable, Equatable {
    let id: String
    let childId: String
    let specialistId: String
    let completedAt: Date
    let answers: [String]
    let recommendedFocus: [String]
    let validUntil: Date
}

// MARK: - ChildOralStoryObject (v12 — v31 Wave E Ф.3 «Сочини историю»)
//
// Локальная запись устной истории ребёнка: транскрипт WhisperKit + TTR +
// идентификаторы выбранных стимулов. Без аудио в Realm — аудиофайл лежит
// в Documents/, ссылка хранится отдельно. Никакой сетевой синхронизации.

final class ChildOralStoryObject: Object, @unchecked Sendable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var childId: String = ""
    @Persisted var createdAt: Date = Date()
    @Persisted var transcript: String = ""
    @Persisted var durationSeconds: Double = 0
    @Persisted var stimulusIds: List<String>
    /// TTR = unique words / total words, 0…1.
    @Persisted var lexicalDiversity: Double = 0
    @Persisted var totalWords: Int = 0
    @Persisted var uniqueWords: Int = 0
}

// MARK: - ChildOralStoryData (Sendable DTO)

struct ChildOralStoryData: Sendable, Identifiable, Equatable {
    let id: String
    let childId: String
    let createdAt: Date
    let transcript: String
    let durationSeconds: Double
    let stimulusIds: [String]
    let lexicalDiversity: Double
    let totalWords: Int
    let uniqueWords: Int
}

// MARK: - EncryptedVideoClipObject (v12 — v31 Wave E Ф.4 «Дневник речевого роста»)
//
// Метаданные шифрованного видеоклипа: ссылка на encrypted blob в
// Documents/SpeechGrowthDiary/, IV (nonce) для AES-GCM-256, имя файла
// thumbnail (тоже шифрованного), теги, длительность.
//
// Сам клип НЕ хранится в Realm. Ключ шифрования НЕ хранится в Realm —
// он живёт в Keychain (per-child, kSecAttrAccessibleWhenUnlockedThisDeviceOnly).
//
// Локально only. Никаких облаков, никакого Firestore, никакого iCloud.

final class EncryptedVideoClipObject: Object, @unchecked Sendable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var childId: String = ""
    @Persisted var recordedAt: Date = Date()
    @Persisted var durationSeconds: Double = 0
    /// Относительный путь от Documents/ к зашифрованному .bin файлу клипа.
    @Persisted var encryptedClipPath: String = ""
    /// Относительный путь от Documents/ к зашифрованному .bin файлу thumbnail.
    @Persisted var encryptedThumbnailPath: String = ""
    /// Тематика: «звук», «слово», «свободная речь».
    @Persisted var topicTag: String = ""
    /// Целевой звук (Р, С, Ш, Ж, Ч, Щ, Л, К, Г, Х) — опциональный.
    @Persisted var targetSound: String = ""
    /// Заметка родителя (опц.).
    @Persisted var note: String = ""
    /// Per-clip share-token (opaque UUID + signature). nil — не shared.
    @Persisted var shareToken: String?
    /// Срок действия share-token'а; nil — не shared.
    @Persisted var shareTokenExpiresAt: Date?
}

// MARK: - EncryptedVideoClipData (Sendable DTO)

struct EncryptedVideoClipData: Sendable, Identifiable, Equatable {
    let id: String
    let childId: String
    let recordedAt: Date
    let durationSeconds: Double
    let encryptedClipPath: String
    let encryptedThumbnailPath: String
    let topicTag: String
    let targetSound: String
    let note: String
    let shareToken: String?
    let shareTokenExpiresAt: Date?
}

// MARK: - SchemaVersion

/// Current Realm schema version. Increment with each migration.
/// v12: ChildOralStoryObject (Wave E Ф.3) + EncryptedVideoClipObject (Wave E Ф.4).
enum RealmSchemaVersion {
    static let current: UInt64 = 12
}
