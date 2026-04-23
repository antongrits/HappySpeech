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

// MARK: - SyncPolicy

/// Настройки ретрая + conflict resolution. Вынесены наружу, чтобы тесты могли
/// подменить (например, отключить задержки).
public struct SyncPolicy: Sendable {
    public let baseDelaySec: Double
    public let maxDelaySec: Double
    public let maxRetryCount: Int
    public let wifiOnly: Bool

    public static let `default` = SyncPolicy(
        baseDelaySec: 1.0,
        maxDelaySec: 60.0,
        maxRetryCount: 5,
        wifiOnly: false
    )

    public static let wifiOnly = SyncPolicy(
        baseDelaySec: 1.0,
        maxDelaySec: 60.0,
        maxRetryCount: 5,
        wifiOnly: true
    )

    public init(baseDelaySec: Double, maxDelaySec: Double, maxRetryCount: Int, wifiOnly: Bool) {
        self.baseDelaySec = baseDelaySec
        self.maxDelaySec = maxDelaySec
        self.maxRetryCount = maxRetryCount
        self.wifiOnly = wifiOnly
    }
}

// MARK: - ProgressMergePayload

/// Сериализованная полезная нагрузка, которую можно «слить по максимуму» (merge-by-max).
/// Используется для обновлений прогресса ребёнка.
struct ProgressMergePayload: Codable {
    let percent: Double?
    let streak: Int?
    let totalSessionMinutes: Int?
}

// MARK: - LiveSyncService

/// Drains the Realm `SyncQueueItem` table by uploading to Firebase.
///
/// Особенности:
///   • Exponential backoff: `base * 2^(retry-1)`, capped `maxDelaySec` (по умолчанию
///     1s → 2s → 4s → 8s → 16s → 32s → 60s).
///   • Конфликт-резолюция для progress-entity: merge-by-max (берём большее значение
///     между клиентским payload и удалённым snapshot).
///   • Wi-Fi-only режим для экономии трафика (конфигурируется через `SyncPolicy`).
///   • Background sync hook: `syncOnAppForeground()` вызывается из сценария
///     `scenePhase == .active`.
///
/// Реализован как `actor` — внутренний state сериализован runtime, без data race.
public actor LiveSyncService: SyncService {

    private var _pendingCount: Int = 0
    private var _isSyncing: Bool = false

    private let realmActor: RealmActor
    private let networkMonitor: any NetworkMonitorService
    private let policy: SyncPolicy
    private let sleeper: @Sendable (Double) async -> Void

    public init(
        realmActor: RealmActor,
        networkMonitor: any NetworkMonitorService,
        policy: SyncPolicy = .default,
        sleeper: @escaping @Sendable (Double) async -> Void = { seconds in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    ) {
        self.realmActor = realmActor
        self.networkMonitor = networkMonitor
        self.policy = policy
        self.sleeper = sleeper
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
        guard isOnlineForSync() else {
            HSLogger.sync.warning("Sync skipped — offline or Wi-Fi-only blocked on cellular")
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
        let pendingItems = allItems.filter {
            $0.syncedAt == nil && $0.retryCount < policy.maxRetryCount
        }

        HSLogger.sync.info("Draining \(pendingItems.count) items (policy maxRetry=\(self.policy.maxRetryCount))")

        for item in pendingItems {
            await drain(item: item)
        }
    }

    /// Хук для background sync: вызывать при переходе приложения в foreground.
    /// Проверяет сеть и мягко дренит очередь (без throw — ошибки логируются).
    public func syncOnAppForeground() async {
        guard isOnlineForSync() else { return }
        do {
            try await drainQueue()
        } catch {
            HSLogger.sync.error("Foreground sync failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    /// Готово ли окружение к синхронизации. Учитывает онлайн/офлайн и Wi-Fi-only политику.
    private func isOnlineForSync() -> Bool {
        guard networkMonitor.isConnected else { return false }
        if policy.wifiOnly, networkMonitor.connectionType != .wifi { return false }
        return true
    }

    /// Один проход дренажа. Уважает retryCount, экспоненциально ждёт перед повторной
    /// попыткой, при ошибке инкрементирует retryCount в Realm.
    private func drain(item: SyncQueueItemDTO) async {
        let itemId = item.id
        let entityId = item.entityId
        let entityType = item.entityType

        // Экспоненциальная задержка перед повторной отправкой — 0 на первой попытке.
        if item.retryCount > 0 {
            let delay = exponentialBackoff(retry: item.retryCount)
            HSLogger.sync.info(
                "Retry #\(item.retryCount) for \(entityId) — waiting \(String(format: "%.1f", delay))s"
            )
            await sleeper(delay)
        }

        do {
            try await uploadToFirebase(item: item)
            await realmActor.asyncWrite { realm in
                if let live = realm.object(ofType: SyncQueueItem.self, forPrimaryKey: itemId) {
                    live.syncedAt = Date()
                }
            }
            _pendingCount = max(0, _pendingCount - 1)
            HSLogger.sync.debug("Synced \(entityType):\(entityId)")
        } catch {
            let message = error.localizedDescription
            await realmActor.asyncWrite { realm in
                if let live = realm.object(ofType: SyncQueueItem.self, forPrimaryKey: itemId) {
                    live.retryCount += 1
                    live.lastErrorMessage = message
                }
            }
            HSLogger.sync.error("Sync failed for \(entityId) (\(entityType)): \(message)")
        }
    }

    /// `base * 2^(retry-1)`, capped by `maxDelaySec`.
    func exponentialBackoff(retry: Int) -> Double {
        guard retry > 0 else { return 0 }
        let raw = policy.baseDelaySec * pow(2.0, Double(retry - 1))
        return min(raw, policy.maxDelaySec)
    }

    // MARK: - Upload + conflict resolution

    private func uploadToFirebase(item: SyncQueueItemDTO) async throws {
        // Placeholder until Firebase SDK is wired. Merge-by-max:
        // если payload — прогресс, сливаем его с «удалённым» snapshot перед отправкой.
        let effectivePayload = try mergedPayload(for: item)
        try await performNetworkUpload(
            entityType: item.entityType,
            entityId: item.entityId,
            payload: effectivePayload
        )
    }

    private func mergedPayload(for item: SyncQueueItemDTO) throws -> String {
        // Применяем merge-by-max только для progress-entity.
        guard item.entityType == "progress" || item.entityType == "child_progress" else {
            return item.payload
        }
        guard let data = item.payload.data(using: .utf8) else { return item.payload }

        let client = (try? JSONDecoder().decode(ProgressMergePayload.self, from: data))
            ?? ProgressMergePayload(percent: nil, streak: nil, totalSessionMinutes: nil)
        let remote = fetchRemoteProgressSnapshot(entityId: item.entityId)

        let merged = ProgressMergePayload(
            percent: maxOptional(client.percent, remote.percent),
            streak: maxOptional(client.streak, remote.streak),
            totalSessionMinutes: maxOptional(client.totalSessionMinutes, remote.totalSessionMinutes)
        )

        let encoded = try JSONEncoder().encode(merged)
        return String(data: encoded, encoding: .utf8) ?? item.payload
    }

    /// Заглушка под будущий Firestore GET. Возвращает пустой snapshot — при отсутствии
    /// удалённой записи merge-by-max эквивалентно «отправить client state как есть».
    private func fetchRemoteProgressSnapshot(entityId: String) -> ProgressMergePayload {
        ProgressMergePayload(percent: nil, streak: nil, totalSessionMinutes: nil)
    }

    private func performNetworkUpload(entityType: String, entityId: String, payload: String) async throws {
        try await Task.sleep(nanoseconds: 100_000_000)
        HSLogger.sync.debug("Uploaded \(entityType):\(entityId) payload=\(payload.count) bytes")
    }

    // MARK: - Helpers

    private func maxOptional<T: Comparable>(_ lhs: T?, _ rhs: T?) -> T? {
        switch (lhs, rhs) {
        case let (l?, r?): return max(l, r)
        case let (l?, nil): return l
        case let (nil, r?): return r
        case (nil, nil): return nil
        }
    }
}
