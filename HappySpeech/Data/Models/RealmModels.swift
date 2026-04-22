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
    @Persisted var lastSessionAt: Date? = nil
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
    @Persisted var lastSyncAt: Date? = nil
}

// MARK: - AdaptivePlan

final class AdaptivePlan: Object, @unchecked Sendable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var childId: String = ""
    @Persisted var date: Date = Date()
    @Persisted var plannedRoute: List<RouteStep>
    @Persisted var actualRoute: List<RouteStep>
    @Persisted var fatigueLevel: Int = 0                   // 0=fresh, 1=normal, 2=tired
    @Persisted var llmSummary: String? = nil
    @Persisted var homeTask: String? = nil
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
    @Persisted var syncedAt: Date? = nil
    @Persisted var retryCount: Int = 0
    @Persisted var lastErrorMessage: String? = nil
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
    @Persisted var sessionId: String? = nil
}

// MARK: - SchemaVersion

/// Current Realm schema version. Increment with each migration.
enum RealmSchemaVersion {
    static let current: UInt64 = 2   // v2: added LLMDecisionLog
}
