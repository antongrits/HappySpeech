import Foundation
import RealmSwift

// MARK: - LLMDecisionLog (Realm)
// ==================================================================================
// Persistent log of every LLM / rule-based decision the app makes.
// Used by QA, diploma evaluation, and offline analytics dashboards.
// ==================================================================================

final class LLMDecisionLog: Object, @unchecked Sendable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var childId: String? = nil
    @Persisted var decisionType: String = ""        // "routePlan" | "parentSummary" | ...
    @Persisted var inputHash: String = ""
    @Persisted var output: String = ""               // short string preview
    @Persisted var modelId: String? = nil            // "Qwen/..." | "Vikhrmodels/..." | nil (rules)
    @Persisted var usedFallback: Bool = true
    @Persisted var latencyMs: Int = 0
    @Persisted var createdAt: Date = Date()
}

// MARK: - DTO

public struct LLMDecisionLogRecord: Sendable, Identifiable {
    public let id: String
    public let childId: String?
    public let decisionType: String
    public let inputHash: String
    public let output: String
    public let modelId: String?
    public let usedFallback: Bool
    public let latencyMs: Int
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        childId: String?,
        decisionType: String,
        inputHash: String,
        output: String,
        modelId: String?,
        usedFallback: Bool,
        latencyMs: Int,
        createdAt: Date
    ) {
        self.id = id
        self.childId = childId
        self.decisionType = decisionType
        self.inputHash = inputHash
        self.output = output
        self.modelId = modelId
        self.usedFallback = usedFallback
        self.latencyMs = latencyMs
        self.createdAt = createdAt
    }
}

// MARK: - Repository

public protocol LLMDecisionLogRepository: Sendable {
    func save(_ record: LLMDecisionLogRecord) async throws
    func fetchRecent(limit: Int) async throws -> [LLMDecisionLogRecord]
    func fetchByChild(_ childId: String, limit: Int) async throws -> [LLMDecisionLogRecord]
}

public final class LiveLLMDecisionLogRepository: LLMDecisionLogRepository, @unchecked Sendable {
    private let realmActor: RealmActor

    public init(realmActor: RealmActor) {
        self.realmActor = realmActor
    }

    public func save(_ record: LLMDecisionLogRecord) async throws {
        try await realmActor.writeVoid { realm in
            let obj = LLMDecisionLog()
            obj.id = record.id
            obj.childId = record.childId
            obj.decisionType = record.decisionType
            obj.inputHash = record.inputHash
            obj.output = record.output
            obj.modelId = record.modelId
            obj.usedFallback = record.usedFallback
            obj.latencyMs = record.latencyMs
            obj.createdAt = record.createdAt
            realm.add(obj, update: .modified)
        }
    }

    public func fetchRecent(limit: Int) async throws -> [LLMDecisionLogRecord] {
        let all = try await realmActor.fetchAllMapped(LLMDecisionLog.self, map: \.asRecord)
        return Array(all.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
    }

    public func fetchByChild(_ childId: String, limit: Int) async throws -> [LLMDecisionLogRecord] {
        let predicate = NSPredicate(format: "childId == %@", childId)
        let items = try await realmActor.fetchFilteredMapped(LLMDecisionLog.self, predicate: predicate, map: \.asRecord)
        return Array(items.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
    }
}

private extension LLMDecisionLog {
    var asRecord: LLMDecisionLogRecord {
        LLMDecisionLogRecord(
            id: id,
            childId: childId,
            decisionType: decisionType,
            inputHash: inputHash,
            output: output,
            modelId: modelId,
            usedFallback: usedFallback,
            latencyMs: latencyMs,
            createdAt: createdAt
        )
    }
}

// MARK: - In-memory repository (previews + tests)

public final class InMemoryLLMDecisionLogRepository: LLMDecisionLogRepository, @unchecked Sendable {
    private let queue = DispatchQueue(label: "ru.happyspeech.llmlog")
    private var records: [LLMDecisionLogRecord] = []

    public init() {}

    public func save(_ record: LLMDecisionLogRecord) async throws {
        queue.sync { records.append(record) }
    }

    public func fetchRecent(limit: Int) async throws -> [LLMDecisionLogRecord] {
        queue.sync {
            Array(records.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
        }
    }

    public func fetchByChild(_ childId: String, limit: Int) async throws -> [LLMDecisionLogRecord] {
        queue.sync {
            let filtered = records.filter { $0.childId == childId }
            return Array(filtered.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
        }
    }

    public var all: [LLMDecisionLogRecord] {
        queue.sync { records }
    }
}
