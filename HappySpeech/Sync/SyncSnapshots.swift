import Foundation

// MARK: - Firestore payload snapshots
//
// Sendable DTOs ferrying progress data from Realm to Firestore across the actor
// boundary. Intentionally split from `SyncService.swift` to keep file lengths below
// the SwiftLint threshold and to make the batch-write payload shape reviewable
// in isolation from the drain/backoff machinery.

/// Aggregated snapshot of all progress artefacts for one parent/user, collected
/// inside `RealmActor` and then uploaded as a single Firestore batch.
struct ProgressSnapshotBundle: Sendable {
    let children: [ChildProfileSnapshot]
    let sessions: [SessionSnapshot]
    let progress: [ProgressEntrySnapshot]

    var totalItems: Int { children.count + sessions.count + progress.count }
}

/// Sendable snapshot of `ChildProfile` for Firestore batch upload.
/// Numeric fields (`totalSessionMinutes`, `currentStreak`) are merge-by-max
/// candidates — server-side Cloud Function (`functions/src/progress.js`) keeps
/// the larger value.
struct ChildProfileSnapshot: Sendable {
    let id: String
    let parentId: String
    let name: String
    let age: Int
    let totalSessionMinutes: Int
    let currentStreak: Int
    let lastSessionAt: Date?
    /// Момент создания snapshot'а. В будущем, когда `ChildProfile` получит
    /// явное поле `updatedAt`, это значение должно заполняться из Realm —
    /// сейчас используется `Date()` на месте сбора snapshot'а как приближение.
    let updatedAt: Date

    func firestoreDict() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "parentId": parentId,
            "name": name,
            "age": age,
            "totalSessionMinutes": totalSessionMinutes,
            "currentStreak": currentStreak,
            "updatedAt": updatedAt.timeIntervalSince1970
        ]
        if let lastSessionAt {
            dict["lastSessionAt"] = lastSessionAt.timeIntervalSince1970
        }
        return dict
    }
}

/// Sendable snapshot of `Session` for Firestore batch upload.
struct SessionSnapshot: Sendable {
    let id: String
    let childId: String
    let date: Date
    let targetSound: String
    let stage: String
    let durationSeconds: Int
    let totalAttempts: Int
    let correctAttempts: Int
    let isSynced: Bool

    func firestoreDict(parentId: String) -> [String: Any] {
        [
            "id": id,
            "parentId": parentId,
            "childId": childId,
            "date": date.timeIntervalSince1970,
            "targetSound": targetSound,
            "stage": stage,
            "durationSeconds": durationSeconds,
            "totalAttempts": totalAttempts,
            "correctAttempts": correctAttempts
        ]
    }
}

/// Sendable snapshot of `ProgressEntry` for Firestore batch upload.
/// `successRate` is a merge-by-max candidate — server keeps the higher value
/// between local and remote to protect against device clock skew / offline edits.
struct ProgressEntrySnapshot: Sendable {
    let id: String
    let childId: String
    let soundTarget: String
    let stage: String
    let date: Date
    let sessionCount: Int
    let successRate: Double
    let isStageCompleted: Bool

    func firestoreDict(parentId: String) -> [String: Any] {
        [
            "id": id,
            "parentId": parentId,
            "childId": childId,
            "soundTarget": soundTarget,
            "stage": stage,
            "date": date.timeIntervalSince1970,
            "sessionCount": sessionCount,
            "successRate": successRate,
            "isStageCompleted": isStageCompleted
        ]
    }
}
