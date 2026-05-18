import Foundation
import OSLog
import RealmSwift

// MARK: - DiaryStorageWorkerProtocol

protocol DiaryStorageWorkerProtocol: AnyObject, Sendable {
    func saveSession(_ data: FluencySessionData) async
    /// Бросает ошибку при сбое чтения хранилища — вызывающая сторона
    /// отличает реальное отсутствие записей от ошибки загрузки.
    func fetchSessions(limit: Int) async throws -> [FluencySessionData]
}

// MARK: - DiaryStorageWorker

final class DiaryStorageWorker: DiaryStorageWorkerProtocol, @unchecked Sendable {

    private let realmActor: RealmActor
    private let logger = HSLogger.realm

    init(realmActor: RealmActor) {
        self.realmActor = realmActor
    }

    func saveSession(_ data: FluencySessionData) async {
        await realmActor.write { realm in
            let obj = FluencySessionObject()
            obj.id = data.id
            obj.date = data.date
            obj.dysfluencyCount = data.dysfluencyCount
            obj.totalSyllables = data.totalSyllables
            obj.rate = data.rate
            obj.transcript = data.transcript
            realm.add(obj, update: .modified)
        }
        logger.info("DiaryStorage: saved session id=\(data.id, privacy: .private)")
    }

    func fetchSessions(limit: Int) async throws -> [FluencySessionData] {
        let all = try await realmActor.fetchFluencySessions()
        let sorted = all.sorted { $0.date > $1.date }
        return limit > 0 ? Array(sorted.prefix(limit)) : sorted
    }
}
