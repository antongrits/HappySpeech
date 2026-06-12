import Foundation
import OSLog
import RealmSwift

// MARK: - ScreeningPersistedOutcome

/// Sendable snapshot of the most recent persisted screening outcome.
///
/// Returned across the Worker boundary so `ScreeningInteractor` (Features layer)
/// никогда не держит Realm-объект (`ScreeningOutcomeObject`). Используется при
/// проверке re-screening eligibility.
struct ScreeningPersistedOutcome: Sendable, Equatable {
    let childId: String
    let completedAt: Date
    let overallSeverity: String
    let problematicSounds: [String]
    let notes: String
    let screeningVersion: Int
}

// MARK: - ScreeningOutcomeDraft

/// Sendable payload describing an outcome about to be persisted. `perSoundJSON`
/// (when non-empty) is prefixed onto `notes` as `scores:<json>;` by the store —
/// preserving the historical Interactor format.
struct ScreeningOutcomeDraft: Sendable, Equatable {
    let childId: String
    let severity: String
    let problematicSounds: [String]
    let recommendedPacks: [String]
    let notes: String
    let perSoundJSON: String
    let screeningVersion: Int
}

// MARK: - ScreeningOutcomeStoring

/// Persistence contract for screening outcomes used by `ScreeningInteractor`.
///
/// Encapsulates all Realm access for `ScreeningOutcomeObject` behind a Sendable,
/// DTO-only boundary so the Interactor никогда не дёргает Realm напрямую
/// (Clean Swift: Features → Workers/Repositories only). Allows unit tests to
/// substitute a deterministic in-memory store.
protocol ScreeningOutcomeStoring: Sendable {
    /// Persist a screening outcome.
    func saveOutcome(_ draft: ScreeningOutcomeDraft) async
    /// Most recently completed outcome for a child, or nil when none exists.
    func fetchLatest(childId: String) async -> ScreeningPersistedOutcome?
}

// MARK: - ScreeningOutcomeStoreWorker

/// Realm-backed implementation of `ScreeningOutcomeStoring`.
///
/// All persistence runs on `RealmActor`; only Sendable values cross the actor
/// boundary — Realm objects never leave the worker.
final class ScreeningOutcomeStoreWorker: ScreeningOutcomeStoring, @unchecked Sendable {

    private let realmActor: RealmActor
    private let logger = Logger(subsystem: "ru.happyspeech", category: "ScreeningOutcomeStore")

    init(realmActor: RealmActor) {
        self.realmActor = realmActor
    }

    func saveOutcome(_ draft: ScreeningOutcomeDraft) async {
        let notesPrefix = draft.perSoundJSON.isEmpty ? "" : "scores:\(draft.perSoundJSON);"
        let composedNotes = notesPrefix + draft.notes
        await realmActor.asyncWrite { realm in
            let outcome = ScreeningOutcomeObject()
            outcome.childId = draft.childId
            outcome.completedAt = Date()
            outcome.overallSeverity = draft.severity
            outcome.problematicSounds.removeAll()
            outcome.problematicSounds.append(objectsIn: draft.problematicSounds)
            outcome.recommendedPacks.removeAll()
            outcome.recommendedPacks.append(objectsIn: draft.recommendedPacks)
            outcome.notes = composedNotes
            outcome.screeningVersion = draft.screeningVersion
            realm.add(outcome, update: .modified)
        }
        logger.info("ScreeningOutcome saved severity=\(draft.severity, privacy: .public)")
    }

    func fetchLatest(childId: String) async -> ScreeningPersistedOutcome? {
        let predicate = NSPredicate(format: "childId == %@", childId)
        let snapshots: [ScreeningPersistedOutcome] = (try? await realmActor.fetchFilteredMappedAsync(
            ScreeningOutcomeObject.self,
            predicate: predicate
        ) { obj in
            ScreeningPersistedOutcome(
                childId: obj.childId,
                completedAt: obj.completedAt,
                overallSeverity: obj.overallSeverity,
                problematicSounds: Array(obj.problematicSounds),
                notes: obj.notes,
                screeningVersion: obj.screeningVersion
            )
        }) ?? []
        return snapshots.max(by: { $0.completedAt < $1.completedAt })
    }
}
