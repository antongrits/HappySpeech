import Foundation
import OSLog
import RealmSwift

// MARK: - FamilyRecordingStoring

/// Persistence contract for family voice recordings used by `FamilyVoiceInteractor`.
///
/// Encapsulates all Realm access for `FamilyRecordingObject` behind a Sendable,
/// DTO-only boundary so the Interactor (Features layer) never touches Realm directly
/// (Clean Swift: Features → Workers/Repositories only). Allows unit tests to substitute
/// a deterministic in-memory store. Production behaviour is unchanged.
protocol FamilyRecordingStoring: Sendable {
    /// All recordings for a parent profile, ordered as stored.
    func fetchAll(parentId: String) async -> [RecordingDTO]
    /// Persist a recording. When `replacingId` is set, the prior record is removed first.
    func save(_ dto: RecordingDTO, replacingId: String?) async
    /// Delete a recording by id. Missing ids are ignored.
    func delete(id: String) async
}

// MARK: - FamilyRecordingStoreWorker

/// Realm-backed implementation of `FamilyRecordingStoring`.
///
/// All persistence runs on `RealmActor`; only Sendable `RecordingDTO` values cross
/// the actor boundary — Realm objects never leave the worker.
final class FamilyRecordingStoreWorker: FamilyRecordingStoring, @unchecked Sendable {

    private let realmActor: RealmActor
    private let logger = Logger(subsystem: "com.happyspeech", category: "FamilyRecordingStore")

    init(realmActor: RealmActor) {
        self.realmActor = realmActor
    }

    func fetchAll(parentId: String) async -> [RecordingDTO] {
        let predicate = NSPredicate(format: "parentProfileId == %@", parentId)
        let dtos = (try? await realmActor.fetchFilteredMappedAsync(
            FamilyRecordingObject.self,
            predicate: predicate,
            map: { obj in
                RecordingDTO(
                    id: obj.id,
                    word: obj.word,
                    audioFilePath: obj.audioFilePath,
                    recordedAt: obj.recordedAt,
                    durationSeconds: obj.durationSeconds,
                    parentProfileId: obj.parentProfileId
                )
            }
        )) ?? []
        return dtos
    }

    func save(_ dto: RecordingDTO, replacingId: String?) async {
        await realmActor.asyncWrite { realm in
            if let oldId = replacingId,
               let old = realm.object(ofType: FamilyRecordingObject.self, forPrimaryKey: oldId) {
                realm.delete(old)
            }
            let obj = FamilyRecordingObject()
            obj.id = dto.id
            obj.word = dto.word
            obj.audioFilePath = dto.audioFilePath
            obj.recordedAt = dto.recordedAt
            obj.durationSeconds = dto.durationSeconds
            obj.parentProfileId = dto.parentProfileId
            realm.add(obj, update: .modified)
        }
        logger.info("FamilyRecording saved id=\(dto.id, privacy: .private)")
    }

    func delete(id: String) async {
        await realmActor.asyncWrite { realm in
            if let obj = realm.object(ofType: FamilyRecordingObject.self, forPrimaryKey: id) {
                realm.delete(obj)
            }
        }
        logger.info("FamilyRecording deleted id=\(id, privacy: .private)")
    }
}
