import Foundation
import OSLog
import RealmSwift

// MARK: - ScreeningOutcomeRepository Protocol

/// Репозиторий для `ScreeningOutcomeObject` — хранит результаты скрининга.
/// В ParentHome читается последний outcome по childId (latestOutcome).
/// В AdaptivePlannerService используется как ключевой сигнал для дневного маршрута.
public protocol ScreeningOutcomeRepository: Sendable {
    /// Сохранить/обновить outcome скрининга.
    func save(_ outcome: ScreeningOutcomeDTO) async throws
    /// Получить последний outcome для ребёнка. nil — скрининг ещё не пройден.
    func fetchLatest(childId: String) async throws -> ScreeningOutcomeDTO?
    /// Получить все outcomes ребёнка (история скрининга).
    func fetchAll(childId: String) async throws -> [ScreeningOutcomeDTO]
    /// Удалить outcome по id.
    func delete(id: String) async throws
}

// MARK: - ScreeningOutcomeDTO

/// Realm-независимый доменный объект. Создаётся из `ScreeningOutcomeObject`
/// и не содержит Realm-типов — безопасен для передачи между контекстами.
public struct ScreeningOutcomeDTO: Sendable, Identifiable, Equatable {
    public let id: String
    public let childId: String
    public let completedAt: Date
    public let overallSeverity: String          // "mild" | "moderate" | "severe"
    public let problematicSounds: [String]      // sorted по убыванию приоритета
    public let recommendedPacks: [String]
    public let notes: String
    public let screeningVersion: Int

    public init(
        id: String = UUID().uuidString,
        childId: String,
        completedAt: Date = Date(),
        overallSeverity: String = "mild",
        problematicSounds: [String] = [],
        recommendedPacks: [String] = [],
        notes: String = "",
        screeningVersion: Int = 1
    ) {
        self.id = id
        self.childId = childId
        self.completedAt = completedAt
        self.overallSeverity = overallSeverity
        self.problematicSounds = problematicSounds
        self.recommendedPacks = recommendedPacks
        self.notes = notes
        self.screeningVersion = screeningVersion
    }

    /// Human-readable severity label для ParentHome.
    public var severityDisplayText: String {
        switch overallSeverity {
        case "mild":     return String(localized: "screening.severity.mild")
        case "moderate": return String(localized: "screening.severity.moderate")
        case "severe":   return String(localized: "screening.severity.severe")
        default:         return overallSeverity
        }
    }
}

// MARK: - LiveScreeningOutcomeRepository

public final class LiveScreeningOutcomeRepository: ScreeningOutcomeRepository, @unchecked Sendable {

    private let realmActor: RealmActor
    private let logger = Logger(subsystem: "ru.happyspeech", category: "ScreeningOutcomeRepo")

    public init(realmActor: RealmActor) {
        self.realmActor = realmActor
    }

    public func save(_ outcome: ScreeningOutcomeDTO) async throws {
        try await realmActor.writeVoid { realm in
            let obj = ScreeningOutcomeObject()
            obj.id = outcome.id
            obj.childId = outcome.childId
            obj.completedAt = outcome.completedAt
            obj.overallSeverity = outcome.overallSeverity
            obj.problematicSounds.removeAll()
            obj.problematicSounds.append(objectsIn: outcome.problematicSounds)
            obj.recommendedPacks.removeAll()
            obj.recommendedPacks.append(objectsIn: outcome.recommendedPacks)
            obj.notes = outcome.notes
            obj.screeningVersion = outcome.screeningVersion
            realm.add(obj, update: .modified)
        }
        let oid = outcome.id
        let osev = outcome.overallSeverity
        logger.info(
            "ScreeningOutcome saved id=\(oid, privacy: .public) severity=\(osev, privacy: .public)"
        )
    }

    public func fetchLatest(childId: String) async throws -> ScreeningOutcomeDTO? {
        let all = try await fetchAllAsync(childId: childId)
        return all.max(by: { $0.completedAt < $1.completedAt })
    }

    public func fetchAll(childId: String) async throws -> [ScreeningOutcomeDTO] {
        try await fetchAllAsync(childId: childId)
    }

    public func delete(id: String) async throws {
        try await realmActor.delete(ScreeningOutcomeObject.self, primaryKey: id)
        logger.info("ScreeningOutcome deleted id=\(id, privacy: .public)")
    }

    // MARK: - Private

    private func fetchAllAsync(childId: String) async throws -> [ScreeningOutcomeDTO] {
        let predicate = NSPredicate(format: "childId == %@", childId)
        return try await realmActor.fetchFilteredMappedAsync(
            ScreeningOutcomeObject.self,
            predicate: predicate,
            map: \.asDTO
        )
    }
}

// MARK: - Realm → DTO Mapping

private extension ScreeningOutcomeObject {
    var asDTO: ScreeningOutcomeDTO {
        ScreeningOutcomeDTO(
            id: id,
            childId: childId,
            completedAt: completedAt,
            overallSeverity: overallSeverity,
            problematicSounds: Array(problematicSounds),
            recommendedPacks: Array(recommendedPacks),
            notes: notes,
            screeningVersion: screeningVersion
        )
    }
}

// MARK: - MockScreeningOutcomeRepository (previews + tests)

public final class MockScreeningOutcomeRepository: ScreeningOutcomeRepository, @unchecked Sendable {
    public var outcomes: [ScreeningOutcomeDTO] = []
    public var shouldFail = false

    public init(outcomes: [ScreeningOutcomeDTO] = []) {
        self.outcomes = outcomes
    }

    public func save(_ outcome: ScreeningOutcomeDTO) async throws {
        if shouldFail { throw AppError.realmWriteFailed("Mock failure") }
        outcomes.removeAll { $0.id == outcome.id }
        outcomes.append(outcome)
    }

    public func fetchLatest(childId: String) async throws -> ScreeningOutcomeDTO? {
        if shouldFail { throw AppError.realmReadFailed("Mock failure") }
        return outcomes
            .filter { $0.childId == childId }
            .max(by: { $0.completedAt < $1.completedAt })
    }

    public func fetchAll(childId: String) async throws -> [ScreeningOutcomeDTO] {
        if shouldFail { throw AppError.realmReadFailed("Mock failure") }
        return outcomes.filter { $0.childId == childId }
    }

    public func delete(id: String) async throws {
        outcomes.removeAll { $0.id == id }
    }
}

// MARK: - Preview Data

public extension ScreeningOutcomeDTO {
    static let previewModerate = ScreeningOutcomeDTO(
        id: "preview-outcome-1",
        childId: "preview-child-1",
        completedAt: Date().addingTimeInterval(-86_400),
        overallSeverity: "moderate",
        problematicSounds: ["Р", "Ш"],
        recommendedPacks: ["sound_r_pack", "sound_sh_pack"],
        notes: "Требуется дополнительная работа над Р и Ш",
        screeningVersion: 1
    )

    static let previewMild = ScreeningOutcomeDTO(
        id: "preview-outcome-2",
        childId: "preview-child-2",
        completedAt: Date().addingTimeInterval(-172_800),
        overallSeverity: "mild",
        problematicSounds: [],
        recommendedPacks: [],
        notes: "",
        screeningVersion: 1
    )
}
