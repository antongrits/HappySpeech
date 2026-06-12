import Foundation
import OSLog
import RealmSwift

// MARK: - PhonemeObservationRepository Protocol

/// Репозиторий пофонемных GOP-наблюдений (`PhonemeObservationObject`, v17).
///
/// Хранит только числовые/IPA-метрики — никакого аудио или PII (см. модель).
/// Используется `PhonemeProfileService` для построения «Фонемного паспорта»
/// (матрица «фонема × позиция», оценка динамики). Это оценка динамики, не диагноз.
///
/// Доступ DTO-only через `RealmActor`: Realm-объекты никогда не пересекают
/// границу актора — наружу отдаются только Sendable `PhonemeObservationDTO`.
public protocol PhonemeObservationRepository: Sendable {
    /// Сохранить наблюдение (idempotent по primary-key id).
    func save(_ observation: PhonemeObservationDTO) async throws
    /// Все наблюдения ребёнка, отсортированные по дате (старые → новые).
    func fetch(childId: String) async throws -> [PhonemeObservationDTO]
    /// Наблюдения ребёнка по конкретной фонеме, отсортированные по дате.
    func fetch(childId: String, phoneme: String) async throws -> [PhonemeObservationDTO]
}

// MARK: - Realm → DTO Mapping

private extension PhonemeObservationObject {
    var asDTO: PhonemeObservationDTO {
        PhonemeObservationDTO(
            id: id,
            childId: childId,
            phoneme: phoneme,
            wordId: wordId,
            position: position,
            gop: gop,
            posterior: posterior,
            defect: defect,
            competitor: competitor,
            date: date
        )
    }
}

// MARK: - LivePhonemeObservationRepository

public final class LivePhonemeObservationRepository: PhonemeObservationRepository, @unchecked Sendable {

    private let realmActor: RealmActor
    private let logger = Logger(subsystem: "ru.happyspeech", category: "PhonemeObsRepo")

    public init(realmActor: RealmActor) {
        self.realmActor = realmActor
    }

    public func save(_ observation: PhonemeObservationDTO) async throws {
        try await realmActor.writeVoid { realm in
            let obj = PhonemeObservationObject()
            obj.id = observation.id
            obj.childId = observation.childId
            obj.phoneme = observation.phoneme
            obj.wordId = observation.wordId
            obj.position = observation.position
            obj.gop = observation.gop
            obj.posterior = observation.posterior
            obj.defect = observation.defect
            obj.competitor = observation.competitor
            obj.date = observation.date
            realm.add(obj, update: .modified)
        }
        let pid = observation.id
        let phon = observation.phoneme
        logger.debug(
            "Phoneme observation saved id=\(pid, privacy: .public) phoneme=\(phon, privacy: .public)"
        )
    }

    public func fetch(childId: String) async throws -> [PhonemeObservationDTO] {
        let predicate = NSPredicate(format: "childId == %@", childId)
        let all = try await realmActor.fetchFilteredMappedAsync(
            PhonemeObservationObject.self,
            predicate: predicate,
            map: \.asDTO
        )
        return all.sorted { $0.date < $1.date }
    }

    public func fetch(childId: String, phoneme: String) async throws -> [PhonemeObservationDTO] {
        let predicate = NSPredicate(format: "childId == %@ AND phoneme == %@", childId, phoneme)
        let all = try await realmActor.fetchFilteredMappedAsync(
            PhonemeObservationObject.self,
            predicate: predicate,
            map: \.asDTO
        )
        return all.sorted { $0.date < $1.date }
    }
}

// MARK: - MockPhonemeObservationRepository (preview / tests)

public final class MockPhonemeObservationRepository: PhonemeObservationRepository, @unchecked Sendable {

    private let lock = NSLock()
    private var storage: [PhonemeObservationDTO]
    public var shouldFail = false

    public init(observations: [PhonemeObservationDTO] = []) {
        self.storage = observations
    }

    /// Снимок текущего содержимого (для ассертов в тестах).
    public var observations: [PhonemeObservationDTO] {
        lock.lock(); defer { lock.unlock() }
        return storage
    }

    public func save(_ observation: PhonemeObservationDTO) async throws {
        if shouldFail { throw AppError.realmWriteFailed("Mock failure") }
        lock.withLock {
            storage.removeAll { $0.id == observation.id }
            storage.append(observation)
        }
    }

    public func fetch(childId: String) async throws -> [PhonemeObservationDTO] {
        if shouldFail { throw AppError.realmReadFailed("Mock failure") }
        return lock.withLock {
            storage
                .filter { $0.childId == childId }
                .sorted { $0.date < $1.date }
        }
    }

    public func fetch(childId: String, phoneme: String) async throws -> [PhonemeObservationDTO] {
        if shouldFail { throw AppError.realmReadFailed("Mock failure") }
        return lock.withLock {
            storage
                .filter { $0.childId == childId && $0.phoneme == phoneme }
                .sorted { $0.date < $1.date }
        }
    }
}

// MARK: - Preview Data

public extension PhonemeObservationDTO {
    /// Один пример «чистого» наблюдения по фонеме [r].
    static let preview = PhonemeObservationDTO(
        id: "preview-obs-1",
        childId: "preview-child-1",
        phoneme: "r",
        wordId: "word_ruka",
        position: "initial",
        gop: 0.42,
        posterior: 0.55,
        defect: "distortion",
        competitor: nil,
        date: Date().addingTimeInterval(-86_400)
    )
}
