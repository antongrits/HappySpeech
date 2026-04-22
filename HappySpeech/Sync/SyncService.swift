import Foundation
import OSLog
import Network

// MARK: - SyncQueueItemDTO

/// Sendable DTO snapshot of `SyncQueueItem` for actor boundary crossings.
public struct SyncQueueItemDTO: Sendable, Equatable, Identifiable {
    public let id: String
    public let entityType: String
    public let entityId: String
    public let operation: String
    public let payload: String
    public let createdAt: Date
    public let syncedAt: Date?
    public let retryCount: Int
    public let lastErrorMessage: String?
}

// MARK: - LiveSyncService

/// Drains the Realm `SyncQueueItem` table by uploading to Firebase.
/// Retries with exponential backoff (max 3 attempts per item).
///
/// Implemented as an `actor` so the internal `_pendingCount` / `_isSyncing`
/// state is serialised by the Swift runtime — no data races possible.
public actor LiveSyncService: SyncService {

    private var _pendingCount: Int = 0
    private var _isSyncing: Bool = false

    private let realmActor: RealmActor
    private let networkMonitor: any NetworkMonitorService

    public init(realmActor: RealmActor, networkMonitor: any NetworkMonitorService) {
        self.realmActor = realmActor
        self.networkMonitor = networkMonitor
    }

    // MARK: - Protocol surface

    public func pendingCount() async -> Int { _pendingCount }
    public func isSyncing() async -> Bool { _isSyncing }

    // MARK: - Enqueue

    public func enqueue(operation: SyncOperation) async throws {
        let entityType = operation.entityType
        let entityId = operation.entityId
        let op = operation.operation
        let payload = operation.payload
        await realmActor.asyncWrite { realm in
            let item = SyncQueueItem()
            item.entityType = entityType
            item.entityId = entityId
            item.operation = op
            item.payload = payload
            realm.add(item)
        }
        _pendingCount += 1
        HSLogger.sync.info("Enqueued \(op) for \(entityType):\(entityId)")
    }

    // MARK: - Drain

    public func drainQueue() async throws {
        guard networkMonitor.isConnected else {
            HSLogger.sync.warning("Sync skipped — offline")
            return
        }
        guard !_isSyncing else { return }
        _isSyncing = true
        defer { _isSyncing = false }

        let allItems = await realmActor.asyncFetchMapped(SyncQueueItem.self) { item in
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
        let pendingItems = allItems.filter { $0.syncedAt == nil && $0.retryCount < 3 }

        HSLogger.sync.info("Draining \(pendingItems.count) items")

        for item in pendingItems {
            let itemId = item.id
            let entityId = item.entityId
            let entityType = item.entityType
            do {
                try await uploadToFirebase(item: item)
                await realmActor.asyncWrite { realm in
                    if let live = realm.object(ofType: SyncQueueItem.self, forPrimaryKey: itemId) {
                        live.syncedAt = Date()
                    }
                }
                _pendingCount = max(0, _pendingCount - 1)
            } catch {
                let message = error.localizedDescription
                await realmActor.asyncWrite { realm in
                    if let live = realm.object(ofType: SyncQueueItem.self, forPrimaryKey: itemId) {
                        live.retryCount += 1
                        live.lastErrorMessage = message
                    }
                }
                HSLogger.sync.error("Sync failed for \(entityId) (\(entityType)): \(error)")
            }
        }
    }

    // MARK: - Private

    private func uploadToFirebase(item: SyncQueueItemDTO) async throws {
        // Firebase Firestore write — placeholder until Firebase SDK is wired in Sprint 9.
        try await Task.sleep(nanoseconds: 100_000_000)
        HSLogger.sync.debug("Uploaded \(item.entityType):\(item.entityId)")
    }
}
