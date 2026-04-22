import Foundation
import Observation
import OSLog

// MARK: - OfflineOperation

/// Sendable description of a pending offline mutation.
public struct OfflineOperation: Sendable, Equatable {
    public let entityType: String
    public let entityId: String
    public let operation: String   // "upsert" | "delete"
    public let payload: String     // JSON-encoded body

    public init(entityType: String, entityId: String, operation: String, payload: String) {
        self.entityType = entityType
        self.entityId = entityId
        self.operation = operation
        self.payload = payload
    }
}

// MARK: - OfflineQueueManager

/// @Observable wrapper over `SyncQueueItem` that exposes `enqueue` / `count` / `drain`
/// hooks for `LiveNetworkMonitor` to call when connectivity is restored.
/// Kept intentionally thin — all Realm IO goes through `RealmActor`; actual upload
/// is delegated to the injected `SyncService`.
@Observable
@MainActor
public final class OfflineQueueManager {

    public private(set) var pendingCount: Int = 0
    public private(set) var isDraining: Bool = false
    public private(set) var lastDrainAt: Date?

    private let realmActor: RealmActor
    private let syncService: any SyncService
    private let networkMonitor: any NetworkMonitorService

    public init(
        realmActor: RealmActor,
        syncService: any SyncService,
        networkMonitor: any NetworkMonitorService
    ) {
        self.realmActor = realmActor
        self.syncService = syncService
        self.networkMonitor = networkMonitor
    }

    // MARK: - Enqueue

    public func enqueue(_ op: OfflineOperation) async {
        let wrapped = SyncOperation(
            entityType: op.entityType,
            entityId: op.entityId,
            operation: op.operation,
            payload: op.payload
        )
        do {
            try await syncService.enqueue(operation: wrapped)
            await refreshCount()
            HSLogger.sync.info("Offline queue enqueued \(op.operation) \(op.entityType):\(op.entityId) (pending=\(self.pendingCount))")
        } catch {
            HSLogger.sync.error("Offline enqueue failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Count

    public func refreshCount() async {
        let all = await realmActor.asyncFetchMapped(SyncQueueItem.self, map: Self.mapSyncQueueItem)
        pendingCount = all.filter { $0.syncedAt == nil && $0.retryCount < 3 }.count
    }

    @Sendable
    nonisolated private static func mapSyncQueueItem(_ item: SyncQueueItem) -> SyncQueueItemDTO {
        SyncQueueItemDTO(
            id: item.id,
            entityType: item.entityType,
            entityId: item.entityId,
            operation: item.operation,
            payload: item.payload,
            createdAt: item.createdAt,
            syncedAt: item.syncedAt,
            retryCount: item.retryCount,
            lastErrorMessage: item.lastErrorMessage
        )
    }

    // MARK: - Drain

    /// Drains the queue when the network is available. Safe to call from
    /// `NetworkMonitor` whenever connectivity flips to `.wifi` / `.cellular`.
    public func drainIfOnline() async {
        guard networkMonitor.isConnected else {
            HSLogger.sync.info("Offline queue drain skipped — offline (pending=\(self.pendingCount))")
            return
        }
        await drain()
    }

    public func drain() async {
        guard !isDraining else { return }
        isDraining = true
        defer { isDraining = false }
        do {
            try await syncService.drainQueue()
            lastDrainAt = Date()
            await refreshCount()
            HSLogger.sync.info("Offline queue drained — pending=\(self.pendingCount)")
        } catch {
            HSLogger.sync.error("Offline drain failed: \(error.localizedDescription)")
        }
    }
}
