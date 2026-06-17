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
// никаких внешних трекеров (project guide §11).

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

// MARK: - FamilyChallengeObject (v15 — еженедельный семейный челлендж)
//
// Хранит цель/тип недельного семейного челленджа и недели, за которые
// награда уже получена. Вклады участников НЕ хранятся здесь — они считаются
// из реальных сессий детей (ChildProfile + Session) при загрузке экрана.
// Полностью offline / on-device, parent-контур.

final class FamilyChallengeObject: Object, @unchecked Sendable {
    /// Primary key — parentId (один активный челлендж на семью).
    @Persisted(primaryKey: true) var parentId: String = ""
    /// ChallengeType.rawValue — тип цели (минуты / звуки / игры / дневник).
    @Persisted var type: String = "totalMinutes"
    /// Целевое значение в единицах типа челленджа.
    @Persisted var goal: Int = 300
    /// Понедельник 00:00 недели, к которой относится текущий челлендж.
    @Persisted var weekStart: Date = Date()
    /// Понедельники недель, за которые награда уже получена (claim) — для
    /// streakWeeks и идемпотентности claimReward.
    @Persisted var claimedWeekStarts: List<Date>
}

// MARK: - FamilyChallengeData (Sendable DTO)

struct FamilyChallengeData: Sendable, Equatable {
    let parentId: String
    let type: String
    let goal: Int
    let weekStart: Date
    let claimedWeekStarts: [Date]
}

// MARK: - LyalyaLetterObject (v15 — персистентные «письма от Ляли», v16 — soft-delete)
//
// Письма маскота ребёнку (мотивация / поздравление / напоминание). Раньше
// хранились в in-memory singleton и терялись при перезапуске. Теперь —
// локальный Realm-объект. Полностью offline / on-device, kid-контур.
//
// v16: добавлен флаг `isDeleted` (soft-delete). Event-письма (welcome/streak/
// firstSound) с детерминированными id не удаляются физически — иначе
// `insertLyalyaLetterIfAbsent` пересоздаёт их при следующей загрузке.
// Мягкое удаление гарантирует, что объект существует в Realm (вставка
// пропускается), но фильтруется при чтении. НЕ-event письма (.custom kind)
// удаляются физически, как раньше.

final class LyalyaLetterObject: Object, @unchecked Sendable {
    /// Primary key — стабильный id письма (детерминированный по триггеру+childId).
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var childId: String = ""
    @Persisted var kind: String = "welcome"            // LetterKind.rawValue
    @Persisted var title: String = ""
    @Persisted var body: String = ""
    @Persisted var date: Date = Date()
    @Persisted var isRead: Bool = false
    @Persisted var audioFileName: String = ""          // "" = нет аудио
    /// Soft-delete флаг (v16). Для event-писем используется вместо физического
    /// удаления из Realm, чтобы идемпотентный `insertLyalyaLetterIfAbsent`
    /// не пересоздавал письмо повторно. Дефолт = false.
    @Persisted var isDeleted: Bool = false
}

// MARK: - LyalyaLetterData (Sendable DTO)

struct LyalyaLetterData: Sendable, Identifiable, Equatable {
    let id: String
    let childId: String
    let kind: String
    let title: String
    let body: String
    let date: Date
    let isRead: Bool
    let audioFileName: String?
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
// для AdaptivePlannerService на ближайшие 2 недели (project guide §11).

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

// MARK: - VoiceJournalEntryRealm (v13 — VoiceJournal feature)
//
// Дневник голоса ребёнка — список аудио-моментов с подписью.
// Хранится только локально (Documents/VoiceJournal/), не синхронизируется
// в Firestore — COPPA-safe, аналогично ParentVoiceClipObject.

final class VoiceJournalEntryRealm: Object, @unchecked Sendable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var childId: String = ""
    @Persisted var date: Date = Date()
    /// Относительный путь к .m4a от Documents/ (не абсолютный — переживает
    /// переустановку приложения).
    @Persisted var fileURLString: String = ""
    @Persisted var title: String = ""
    @Persisted var durationSeconds: Int = 0
    /// Опциональный транскрипт WhisperKit, заполняется отдельным сервисом.
    @Persisted var transcript: String?
}

// MARK: - VoiceJournalEntry (Sendable DTO)

struct VoiceJournalEntry: Sendable, Identifiable, Equatable {
    let id: String
    let childId: String
    let date: Date
    /// Абсолютный URL для проигрывания. Конвертируется из относительного
    /// пути в Worker'е при загрузке.
    let fileURL: URL
    let title: String
    let durationSeconds: Int
    let transcript: String?
}

// MARK: - PhonemeObservationObject (v17 — «Фонемный паспорт»)
//
// Одно пофонемное наблюдение, полученное из GOP-скоринга попытки ребёнка.
// Хранит ТОЛЬКО относительные числовые метрики и IPA-символ фонемы — НИКАКОГО
// аудио, имени ребёнка или иной PII. Это сознательный COPPA-дизайн: паспорт
// строится из накопленных наблюдений, аудио на диске/в облаке не нужно.
//
// Используется:
//   • PhonemeProfileService — агрегация в матрицу «фонема × позиция» и прогноз
//     динамики (EWMA + Theil-Sen). Это ОЦЕНКА ДИНАМИКИ, не диагноз (project guide §11).
//   • SpecialistExportService — пофонемная часть PDF/CSV отчёта.
//
// Декаплировано от ML-движка: сервис оперирует уже-сохранёнными наблюдениями,
// поэтому слой данных не зависит от того, как именно посчитан `gop`/`posterior`.

final class PhonemeObservationObject: Object, @unchecked Sendable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted(indexed: true) var childId: String = ""
    /// Целевая фонема в IPA (например «r», «ʂ», «s»).
    @Persisted var phoneme: String = ""
    /// Идентификатор слова урока, в котором наблюдалась фонема (для дедупликации
    /// и трассировки). Не содержит самого слова — только id.
    @Persisted var wordId: String = ""
    /// Позиция фонемы в слове: "initial" | "medial" | "final".
    @Persisted var position: String = "initial"
    /// Goodness of Pronunciation — относительная мера «похожести» на эталон.
    /// Абсолютная шкала смещена (модель на синтетике), поэтому используются
    /// только относительные/трендовые выводы и self-baseline перцентили.
    @Persisted var gop: Double = 0
    /// Усреднённая апостериорная вероятность целевой фонемы на её интервале.
    @Persisted var posterior: Double = 0
    /// Классифицированный исход: "ok" | "distortion" | "substitution" |
    /// "age_substitution" | "omission".
    @Persisted var defect: String = "ok"
    /// IPA конкурирующей фонемы (для замен) — nil, если конкурента нет.
    @Persisted var competitor: String?
    @Persisted var date: Date = Date()
}

// MARK: - PhonemeObservationDTO (Sendable DTO)

/// Realm-независимый снимок пофонемного наблюдения. Создаётся из
/// `PhonemeObservationObject` внутри RealmActor и безопасно пересекает границу
/// актора. Содержит только числа/IPA — никакого аудио и PII.
public struct PhonemeObservationDTO: Sendable, Identifiable, Equatable {
    public let id: String
    public let childId: String
    /// Целевая фонема в IPA.
    public let phoneme: String
    public let wordId: String
    /// "initial" | "medial" | "final".
    public let position: String
    public let gop: Double
    public let posterior: Double
    /// "ok" | "distortion" | "substitution" | "age_substitution" | "omission".
    public let defect: String
    /// IPA конкурента (для замен), иначе nil.
    public let competitor: String?
    public let date: Date

    public init(
        id: String = UUID().uuidString,
        childId: String,
        phoneme: String,
        wordId: String,
        position: String,
        gop: Double,
        posterior: Double,
        defect: String,
        competitor: String? = nil,
        date: Date = Date()
    ) {
        self.id = id
        self.childId = childId
        self.phoneme = phoneme
        self.wordId = wordId
        self.position = position
        self.gop = gop
        self.posterior = posterior
        self.defect = defect
        self.competitor = competitor
        self.date = date
    }
}

// MARK: - CarryoverLogObject («Звуковой охотник дня»)

/// Дневной лог переноса звука в спонтанную речь («Звуковой охотник дня», v20).
///
/// Одна запись = одна дата × звук × ребёнок. Хранит «пойманные» в быту слова
/// (детский контур) и родительское подтверждение переноса (3 градации) с
/// опциональной голосовой заметкой. Сигнал переноса питает
/// `AdaptivePlannerService` (через `CorrectionStage`): чистая свободная речь →
/// звук двигается к завершению; иначе возвращаются упражнения автоматизации.
///
/// COPPA: childId без PII; пойманные слова — обычная лексика (не PII); голосовая
/// заметка — локальный .m4a в Documents, путь относительный. Без распознавания
/// окружения и без аудио ребёнка.
final class CarryoverLogObject: Object, @unchecked Sendable {
    /// Стабильный primary key вида `<childId>:<sound>:<yyyy-MM-dd>` — гарантирует
    /// одну запись на день/звук/ребёнка (idempotent upsert «поймал слово»).
    @Persisted(primaryKey: true) var id: String = ""
    @Persisted(indexed: true) var childId: String = ""
    /// Целевой звук дня (кириллица, например «Р»).
    @Persisted var sound: String = ""
    /// Локальный день записи (нормализован к началу дня).
    @Persisted var day: Date = Date()
    /// «Пойманные» в быту слова (детский контур).
    @Persisted var caughtWords: List<String>
    /// Цель сачка (число слотов-звёзд для полного сачка).
    @Persisted var netGoal: Int = 5
    /// Какие задания-охоты отмечены выполненными (id миссии из пака).
    @Persisted var completedTaskIds: List<String>
    /// Родительский чек-ин переноса: "" (не отмечено) | "clean" | "sometimes" | "notyet".
    @Persisted var parentCheckIn: String = ""
    /// Относительный путь к голосовой заметке родителя (.m4a в Documents), если есть.
    @Persisted var parentVoiceNotePath: String?
    /// Длительность голосовой заметки в секундах (0, если заметки нет).
    @Persisted var parentVoiceNoteDurationSec: Double = 0
    @Persisted var createdAt: Date = Date()
    @Persisted var updatedAt: Date = Date()
}

// MARK: - CarryoverLogDTO (Sendable DTO)

/// Realm-независимый снимок дневного лога переноса. Создаётся из
/// `CarryoverLogObject` внутри `RealmActor` и безопасно пересекает границу актора.
public struct CarryoverLogDTO: Sendable, Identifiable, Equatable {
    public let id: String
    public let childId: String
    public let sound: String
    public let day: Date
    public var caughtWords: [String]
    public let netGoal: Int
    public var completedTaskIds: [String]
    /// "" | "clean" | "sometimes" | "notyet".
    public var parentCheckIn: String
    public var parentVoiceNotePath: String?
    public var parentVoiceNoteDurationSec: Double
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: String,
        childId: String,
        sound: String,
        day: Date,
        caughtWords: [String] = [],
        netGoal: Int = 5,
        completedTaskIds: [String] = [],
        parentCheckIn: String = "",
        parentVoiceNotePath: String? = nil,
        parentVoiceNoteDurationSec: Double = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.childId = childId
        self.sound = sound
        self.day = day
        self.caughtWords = caughtWords
        self.netGoal = netGoal
        self.completedTaskIds = completedTaskIds
        self.parentCheckIn = parentCheckIn
        self.parentVoiceNotePath = parentVoiceNotePath
        self.parentVoiceNoteDurationSec = parentVoiceNoteDurationSec
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Канонический primary key для дня/звука/ребёнка.
    public static func makeId(childId: String, sound: String, day: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(childId):\(sound):\(formatter.string(from: day))"
    }
}

// MARK: - SchemaVersion

/// Current Realm schema version. Increment with each migration.
/// v13: VoiceJournalEntryRealm (VoiceJournal — дневник голоса ребёнка).
/// v14: CustomizationObject.outfit / .background — выбор наряда и фоновой
///      сцены теперь персистится (отражается на всех экранах героя).
/// v15: FamilyChallengeObject (тип/цель/claimed-недели семейного челленджа) +
///      LyalyaLetterObject (персистентные «письма от Ляли»). Новые объекты —
///      Realm создаёт схему автоматически, дефолты заданы в моделях.
/// v16: LyalyaLetterObject.isDeleted (Bool, default false) — soft-delete флаг
///      для event-писем, чтобы идемпотентная вставка не воскрешала удалённые.
/// v17: PhonemeObservationObject («Фонемный паспорт») — пофонемные GOP-наблюдения
///      (только числа/IPA, без аудио/PII). Новый объект — Realm создаёт схему
///      автоматически, дефолты заданы в модели. Аддитивная миграция.
/// v18: удалены мёртвые `AdaptivePlan` + `RouteStep` (EmbeddedObject) — никогда не
///      инстанцировались/читались/писались (0 ссылок в коде, таблицы всегда пустые).
///      Realm удаляет неиспользуемые таблицы при отсутствии класса — ручной миграции
///      не требуется, потери данных нет.
/// v19: CustomizationObject.hairColor / .eyeColor / .skinTone / .accessories —
///      персистентность выбора внешности героя. Аддитивная миграция.
/// v20: CarryoverLogObject («Звуковой охотник дня») — дневной лог переноса звука
///      в спонтанную речь (пойманные слова + родительский чек-ин 3 градации +
///      опц. голосовая заметка). Новый объект — Realm создаёт схему автоматически,
///      дефолты заданы в модели. Аддитивная миграция.
enum RealmSchemaVersion {
    static let current: UInt64 = 20
}

// MARK: - RealmConfig

/// Единственный источник правды для `Realm.Configuration` приложения.
///
/// До этого `schemaVersion` + `migrationBlock` собирались только внутри
/// `RealmActor.open()` и применялись лишь к кэшированному `self.realm`.
/// Десятки extension-методов открывали Realm через `Realm(actor: self)` без
/// явного config → RealmSwift подставлял `Realm.Configuration.defaultConfiguration`
/// (schemaVersion 0, migrationBlock nil). На апгрейде существующей БД это давало
/// schema-mismatch, который проглатывался `try?` → пустые данные / «потерянные id».
///
/// Теперь конфигурация собирается ровно в одном месте (``make()``) и применяется
/// как `Realm.Configuration.defaultConfiguration` синхронно на старте приложения
/// (`RealmConfig.installAsDefault()` в `AppContainer.live()`), ДО первого рендера.
/// Любое открытие Realm — кэш `RealmActor`, async `Realm(actor:)` в хелперах,
/// preview-инстансы — наследует одну и ту же версию схемы и migration-блок.
enum RealmConfig {

    /// Собирает каноническую конфигурацию Realm (v17 + migrationBlock).
    ///
    /// Стартует от текущего `defaultConfiguration`, поэтому уважает уже
    /// установленный `fileURL`/`inMemoryIdentifier` (важно для тестов, которые
    /// задают in-memory identifier ДО вызова), и лишь форсит версию схемы,
    /// migration-блок и `deleteRealmIfMigrationNeeded = false` (данные на
    /// апгрейде не теряются молча — миграция выполняется штатно).
    static func make() -> Realm.Configuration {
        var config = Realm.Configuration.defaultConfiguration
        config.schemaVersion = RealmSchemaVersion.current
        config.migrationBlock = RealmMigrations.migrationBlock
        config.deleteRealmIfMigrationNeeded = false
        return config
    }

    /// Устанавливает каноническую конфигурацию как глобальный дефолт.
    ///
    /// Вызывается синхронно на старте (до рендера и до `RealmActor.open()`),
    /// чтобы закрыть гонку: даже если хелпер-метод опередит `open()` и первым
    /// откроет файл через `Realm(actor:)`, он откроет его уже с v16 +
    /// migration-блоком, а не с дефолтной v0.
    static func installAsDefault() {
        Realm.Configuration.defaultConfiguration = make()
    }
}
