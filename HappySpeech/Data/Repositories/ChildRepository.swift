import Foundation
import RealmSwift
import OSLog

// MARK: - ChildRepository Protocol

public protocol ChildRepository: Sendable {
    func fetchAll() async throws -> [ChildProfileDTO]
    func fetch(id: String) async throws -> ChildProfileDTO
    func save(_ profile: ChildProfileDTO) async throws
    func delete(id: String) async throws
    func updateProgress(childId: String, sound: String, rate: Double) async throws
    func updateStreak(childId: String, streak: Int) async throws
}

// MARK: - ChildProfileDTO (DTO — Realm-free domain object)

public struct ChildProfileDTO: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let age: Int
    public let targetSounds: [String]
    public let createdAt: Date
    public let parentId: String
    public let progressSummary: [String: Double]
    public let avatarStyle: String
    public let colorTheme: String
    public let sensitivityLevel: Int
    public let totalSessionMinutes: Int
    public let currentStreak: Int
    public let lastSessionAt: Date?

    public init(
        id: String = UUID().uuidString,
        name: String,
        age: Int,
        targetSounds: [String],
        createdAt: Date = Date(),
        parentId: String,
        progressSummary: [String: Double] = [:],
        avatarStyle: String = "butterfly",
        colorTheme: String = "coral",
        sensitivityLevel: Int = 1,
        totalSessionMinutes: Int = 0,
        currentStreak: Int = 0,
        lastSessionAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.age = age
        self.targetSounds = targetSounds
        self.createdAt = createdAt
        self.parentId = parentId
        self.progressSummary = progressSummary
        self.avatarStyle = avatarStyle
        self.colorTheme = colorTheme
        self.sensitivityLevel = sensitivityLevel
        self.totalSessionMinutes = totalSessionMinutes
        self.currentStreak = currentStreak
        self.lastSessionAt = lastSessionAt
    }
}

// MARK: - LiveChildRepository

public final class LiveChildRepository: ChildRepository, @unchecked Sendable {
    private let realmActor: RealmActor

    public init(realmActor: RealmActor) {
        self.realmActor = realmActor
    }

    public func fetchAll() async throws -> [ChildProfileDTO] {
        try await realmActor.fetchAllMapped(ChildProfile.self, map: \.asDTO)
    }

    public func fetch(id: String) async throws -> ChildProfileDTO {
        guard let dto = try await realmActor.fetchMapped(ChildProfile.self, primaryKey: id, map: \.asDTO) else {
            throw AppError.entityNotFound(id)
        }
        return dto
    }

    public func save(_ profile: ChildProfileDTO) async throws {
        try await realmActor.writeVoid { realm in
            let obj = ChildProfile()
            obj.id = profile.id
            obj.name = profile.name
            obj.age = profile.age
            obj.targetSounds.removeAll()
            obj.targetSounds.append(objectsIn: profile.targetSounds)
            obj.createdAt = profile.createdAt
            obj.parentId = profile.parentId
            obj.avatarStyle = profile.avatarStyle
            obj.colorTheme = profile.colorTheme
            obj.sensitivityLevel = profile.sensitivityLevel
            obj.totalSessionMinutes = profile.totalSessionMinutes
            obj.currentStreak = profile.currentStreak
            obj.lastSessionAt = profile.lastSessionAt
            for (k, v) in profile.progressSummary {
                obj.progressSummary[k] = v
            }
            realm.add(obj, update: .modified)
        }
    }

    public func delete(id: String) async throws {
        try await realmActor.delete(ChildProfile.self, primaryKey: id)
    }

    public func updateProgress(childId: String, sound: String, rate: Double) async throws {
        try await realmActor.updateField(ChildProfile.self, primaryKey: childId) { obj in
            obj.progressSummary[sound] = rate
        }
    }

    public func updateStreak(childId: String, streak: Int) async throws {
        try await realmActor.updateField(ChildProfile.self, primaryKey: childId) { obj in
            obj.currentStreak = streak
        }
    }
}

// MARK: - Realm → DTO Mapping

private extension ChildProfile {
    var asDTO: ChildProfileDTO {
        ChildProfileDTO(
            id: id,
            name: name,
            age: age,
            targetSounds: Array(targetSounds),
            createdAt: createdAt,
            parentId: parentId,
            progressSummary: Dictionary(progressSummary.map { ($0.key, $0.value) }, uniquingKeysWith: { $1 }),
            avatarStyle: avatarStyle,
            colorTheme: colorTheme,
            sensitivityLevel: sensitivityLevel,
            totalSessionMinutes: totalSessionMinutes,
            currentStreak: currentStreak,
            lastSessionAt: lastSessionAt
        )
    }
}

// MARK: - MockChildRepository (for previews and tests)

public final class MockChildRepository: ChildRepository, @unchecked Sendable {
    public var children: [ChildProfileDTO] = []
    public var shouldFail = false

    public init(children: [ChildProfileDTO] = [.preview]) {
        self.children = children
    }

    public func fetchAll() async throws -> [ChildProfileDTO] {
        if shouldFail { throw AppError.realmReadFailed("Mock failure") }
        return children
    }

    public func fetch(id: String) async throws -> ChildProfileDTO {
        guard let c = children.first(where: { $0.id == id }) else {
            throw AppError.entityNotFound(id)
        }
        return c
    }

    public func save(_ profile: ChildProfileDTO) async throws {
        children.removeAll { $0.id == profile.id }
        children.append(profile)
    }

    public func delete(id: String) async throws {
        children.removeAll { $0.id == id }
    }

    public func updateProgress(childId: String, sound: String, rate: Double) async throws {}
    public func updateStreak(childId: String, streak: Int) async throws {}
}

// MARK: - Preview Data

public extension ChildProfileDTO {
    static let preview = ChildProfileDTO(
        id: "preview-child-1",
        name: "Миша",
        age: 6,
        targetSounds: ["Р", "Ш"],
        parentId: "preview-parent-1",
        progressSummary: ["Р": 0.45, "Ш": 0.70],
        currentStreak: 5
    )

    static let previewList: [ChildProfileDTO] = [
        preview,
        ChildProfileDTO(id: "preview-child-2", name: "Соня", age: 5, targetSounds: ["С", "З"],
                        parentId: "preview-parent-1", progressSummary: ["С": 0.80, "З": 0.30],
                        currentStreak: 3)
    ]
}
