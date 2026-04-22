import Foundation
import RealmSwift

// MARK: - SessionRepository Protocol

public protocol SessionRepository: Sendable {
    func fetchAll(childId: String) async throws -> [SessionDTO]
    func fetch(id: String) async throws -> SessionDTO
    func save(_ session: SessionDTO) async throws
    func fetchRecent(childId: String, limit: Int) async throws -> [SessionDTO]
}

// MARK: - SessionDTO

public struct SessionDTO: Sendable, Identifiable {
    public let id: String
    public let childId: String
    public let date: Date
    public let templateType: String
    public let targetSound: String
    public let stage: String
    public let durationSeconds: Int
    public let totalAttempts: Int
    public let correctAttempts: Int
    public let fatigueDetected: Bool
    public let isSynced: Bool
    public let attempts: [AttemptDTO]

    public var successRate: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(correctAttempts) / Double(totalAttempts)
    }
}

// MARK: - AttemptDTO

public struct AttemptDTO: Sendable, Identifiable {
    public let id: String
    public let word: String
    public let audioLocalPath: String
    public let audioStoragePath: String
    public let asrTranscript: String
    public let asrScore: Double
    public let pronunciationScore: Double
    public let manualScore: Double
    public let isCorrect: Bool
    public let timestamp: Date
}

// MARK: - Realm → DTO Mapping (file-private — used only inside this file within actor calls)

private extension Session {
    var asDTO: SessionDTO {
        SessionDTO(
            id: id,
            childId: childId,
            date: date,
            templateType: templateType,
            targetSound: targetSound,
            stage: stage,
            durationSeconds: durationSeconds,
            totalAttempts: totalAttempts,
            correctAttempts: correctAttempts,
            fatigueDetected: fatigueDetected,
            isSynced: isSynced,
            attempts: attempts.map(\.asDTO)
        )
    }
}

private extension Attempt {
    var asDTO: AttemptDTO {
        AttemptDTO(
            id: id,
            word: word,
            audioLocalPath: audioLocalPath,
            audioStoragePath: audioStoragePath,
            asrTranscript: asrTranscript,
            asrScore: asrScore,
            pronunciationScore: pronunciationScore,
            manualScore: manualScore,
            isCorrect: isCorrect,
            timestamp: timestamp
        )
    }
}

// MARK: - LiveSessionRepository

public final class LiveSessionRepository: SessionRepository, @unchecked Sendable {
    private let realmActor: RealmActor

    public init(realmActor: RealmActor) {
        self.realmActor = realmActor
    }

    public func fetchAll(childId: String) async throws -> [SessionDTO] {
        let predicate = NSPredicate(format: "childId == %@", childId)
        return try await realmActor.fetchFilteredMapped(Session.self, predicate: predicate, map: \.asDTO)
    }

    public func fetch(id: String) async throws -> SessionDTO {
        guard let dto = try await realmActor.fetchMapped(Session.self, primaryKey: id, map: \.asDTO) else {
            throw AppError.entityNotFound(id)
        }
        return dto
    }

    public func save(_ session: SessionDTO) async throws {
        try await realmActor.writeVoid { realm in
            let obj = Session()
            obj.id = session.id
            obj.childId = session.childId
            obj.date = session.date
            obj.templateType = session.templateType
            obj.targetSound = session.targetSound
            obj.stage = session.stage
            obj.durationSeconds = session.durationSeconds
            obj.totalAttempts = session.totalAttempts
            obj.correctAttempts = session.correctAttempts
            obj.fatigueDetected = session.fatigueDetected
            obj.isSynced = session.isSynced
            for a in session.attempts {
                let attempt = Attempt()
                attempt.id = a.id
                attempt.word = a.word
                attempt.audioLocalPath = a.audioLocalPath
                attempt.asrTranscript = a.asrTranscript
                attempt.asrScore = a.asrScore
                attempt.pronunciationScore = a.pronunciationScore
                attempt.manualScore = a.manualScore
                attempt.isCorrect = a.isCorrect
                attempt.timestamp = a.timestamp
                obj.attempts.append(attempt)
            }
            realm.add(obj, update: .modified)
        }
    }

    public func fetchRecent(childId: String, limit: Int) async throws -> [SessionDTO] {
        let predicate = NSPredicate(format: "childId == %@", childId)
        let all = try await realmActor.fetchFilteredMapped(Session.self, predicate: predicate, map: \.asDTO)
        return Array(all.sorted { $0.date > $1.date }.prefix(limit))
    }
}

// MARK: - MockSessionRepository

public final class MockSessionRepository: SessionRepository, @unchecked Sendable {
    public var sessions: [SessionDTO] = []

    public init(sessions: [SessionDTO] = [.preview]) {
        self.sessions = sessions
    }

    public func fetchAll(childId: String) async throws -> [SessionDTO] {
        sessions.filter { $0.childId == childId }
    }

    public func fetch(id: String) async throws -> SessionDTO {
        guard let s = sessions.first(where: { $0.id == id }) else {
            throw AppError.entityNotFound(id)
        }
        return s
    }

    public func save(_ session: SessionDTO) async throws {
        sessions.removeAll { $0.id == session.id }
        sessions.append(session)
    }

    public func fetchRecent(childId: String, limit: Int) async throws -> [SessionDTO] {
        Array(sessions.filter { $0.childId == childId }
            .sorted { $0.date > $1.date }
            .prefix(limit))
    }
}

// MARK: - Preview Data

public extension SessionDTO {
    static let preview = SessionDTO(
        id: "preview-session-1",
        childId: "preview-child-1",
        date: Date().addingTimeInterval(-3600),
        templateType: TemplateType.listenAndChoose.rawValue,
        targetSound: "Р",
        stage: CorrectionStage.wordInit.rawValue,
        durationSeconds: 480,
        totalAttempts: 12,
        correctAttempts: 9,
        fatigueDetected: false,
        isSynced: false,
        attempts: []
    )
}
