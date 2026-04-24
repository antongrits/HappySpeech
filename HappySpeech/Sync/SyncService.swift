import Foundation
import Network
import OSLog
import RealmSwift

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

/// Drains the Realm `SyncQueueItem` table by uploading to Firebase. Exponential
/// backoff (`base * 2^(retry-1)`, capped), merge-by-max conflict resolution for
/// progress-entity, Wi-Fi-only switch, background-sync foreground hook. Implemented
/// as an `actor` — internal state is serialized, no data races.
public actor LiveSyncService: SyncService {

    private var _pendingCount: Int = 0
    private var _isSyncing: Bool = false

    private let realmActor: RealmActor
    private let networkMonitor: any NetworkMonitorService
    private let policy: SyncPolicy
    private let sleeper: @Sendable (Double) async -> Void

    // MARK: - Sync state stream

    /// Shared continuation for `syncState`. Stream is `.bufferingNewest(1)` — late subscribers
    /// get the last emitted value, not the full history. Both the continuation and the stream
    /// are immutable `let`s assigned in `init`; `AsyncStream` and its `Continuation` are
    /// `Sendable` and thread-safe, so plain `nonisolated` is sufficient (no `unsafe`).
    nonisolated private let stateContinuation: AsyncStream<SyncState>.Continuation
    nonisolated private let _syncState: AsyncStream<SyncState>

    public nonisolated var syncState: AsyncStream<SyncState> { _syncState }

    public init(
        realmActor: RealmActor,
        networkMonitor: any NetworkMonitorService,
        policy: SyncPolicy = .default,
        sleeper: @escaping @Sendable (Double) async -> Void = { seconds in
            try? await Task.sleep(for: .seconds(seconds))
        }
    ) {
        self.realmActor = realmActor
        self.networkMonitor = networkMonitor
        self.policy = policy
        self.sleeper = sleeper

        // `AsyncStream.makeStream` (iOS 17+) gives us the stream + continuation pair
        // without the `!` dance around the closure-based init.
        let stream = AsyncStream.makeStream(
            of: SyncState.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        self._syncState = stream.stream
        self.stateContinuation = stream.continuation
        // Seed the stream so late subscribers immediately see `.idle`.
        stream.continuation.yield(.idle)

        // Hydrate `_pendingCount` asynchronously from Realm so that UI consumers
        // get the real backlog size on cold start (not 0 by default).
        Task { [weak self] in
            await self?.hydratePendingCount()
        }
    }

    deinit {
        stateContinuation.finish()
    }

    // MARK: - Protocol surface

    public func pendingCount() async -> Int { _pendingCount }
    public func isSyncing() async -> Bool { _isSyncing }

    /// Emits a new `SyncState` to all subscribers. `nonisolated` so call-sites can publish
    /// from any context (including `deinit`) without hops. Internally it's cheap — just
    /// forwards to the `AsyncStream.Continuation`.
    nonisolated private func publish(_ state: SyncState) {
        stateContinuation.yield(state)
    }

    /// Считает текущее число «висящих» элементов (`syncedAt == nil`) в Realm и
    /// кладёт результат в `_pendingCount`. Вызывается из `init` чтобы UI не
    /// видел 0 на холодном старте, если на диске уже лежит очередь.
    private func hydratePendingCount() async {
        let flags = await realmActor.asyncFetchMapped(SyncQueueItem.self) { item in
            item.syncedAt == nil
        }
        let count = flags.lazy.filter { $0 }.count
        _pendingCount = count
        HSLogger.sync.info("Hydrated pendingCount=\(count) from Realm")
    }

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
        HSLogger.sync.info("Enqueued \(op) for \(entityType):\(entityId, privacy: .private)")
    }

    // MARK: - Drain

    public func drainQueue() async throws {
        guard isOnlineForSync() else {
            HSLogger.sync.warning("Sync skipped — offline or Wi-Fi-only blocked on cellular")
            publish(.failed(message: "offline"))
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

        let total = pendingItems.count
        guard total > 0 else {
            publish(.completed(itemsSynced: 0))
            publish(.idle)
            return
        }

        publish(.syncing(progress: 0.0))
        let pendingBefore = _pendingCount
        for (index, item) in pendingItems.enumerated() {
            await drain(item: item)
            publish(.syncing(progress: Double(index + 1) / Double(total)))
        }
        let succeeded = max(0, pendingBefore - _pendingCount)
        publish(.completed(itemsSynced: succeeded))
        publish(.idle)
    }

    /// Хук для background sync: вызывать при переходе приложения в foreground.
    /// Проверяет сеть и мягко дренит очередь. `drainQueue()` помечен `throws` ради
    /// протокольной совместимости, но на практике ловит все свои ошибки внутри
    /// `drain(item:)` и логирует их — сюда `throw` не долетает. Используем `try?`
    /// как маркер «ошибки здесь допустимы и уже залогированы ниже».
    public func syncOnAppForeground() async {
        guard isOnlineForSync() else { return }
        try? await drainQueue()
    }

    // MARK: - Full-snapshot resync

    /// Читает все Realm-артефакты прогресса для `userId` (профили детей + сессии +
    /// progress-entries) и отправляет их в облако одним batch. Применяет merge-by-max
    /// для численных полей. Intended for first login, manual «sync now» в Settings,
    /// и при восстановлении аккаунта на новом устройстве.
    ///
    /// `userId` здесь трактуется как `parentId` (взрослый аккаунт Firebase Auth),
    /// потому что в текущей схеме все `ChildProfile` принадлежат одному родителю.
    public func syncUserProgress(userId: String) async throws {
        guard isOnlineForSync() else {
            let message = String(localized: "sync.error.offline")
            publish(.failed(message: message))
            HSLogger.sync.warning("syncUserProgress skipped — offline (userId=\(userId, privacy: .private))")
            throw SyncError.offline
        }
        guard !_isSyncing else {
            HSLogger.sync.info("syncUserProgress skipped — another drain in flight")
            return
        }

        _isSyncing = true
        defer { _isSyncing = false }

        publish(.syncing(progress: 0.0))
        HSLogger.sync.info("syncUserProgress start userId=\(userId, privacy: .private)")

        let snapshot = await collectProgressSnapshot(userId: userId)
        let totalItems = snapshot.totalItems

        guard totalItems > 0 else {
            publish(.completed(itemsSynced: 0))
            publish(.idle)
            return
        }

        publish(.syncing(progress: 0.1))

        do {
            try await uploadSnapshot(snapshot, userId: userId)
            await markSessionsSynced(ids: snapshot.sessions.map(\.id))
            publish(.syncing(progress: 1.0))
            publish(.completed(itemsSynced: totalItems))
            publish(.idle)
            HSLogger.sync.info("syncUserProgress completed — \(totalItems) items synced")
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            publish(.failed(message: message))
            HSLogger.sync.error("syncUserProgress failed: \(message)")
            throw error
        }
    }

    /// Собирает snapshot прогресса из Realm. Ни один Realm Object не пересекает границу
    /// actor'а — всё мапится в Sendable DTO прямо внутри RealmActor.
    private func collectProgressSnapshot(userId: String) async -> ProgressSnapshotBundle {
        let children = await realmActor.asyncFetchMapped(ChildProfile.self) { profile in
            ChildProfileSnapshot(
                id: profile.id,
                parentId: profile.parentId,
                name: profile.name,
                age: profile.age,
                totalSessionMinutes: profile.totalSessionMinutes,
                currentStreak: profile.currentStreak,
                lastSessionAt: profile.lastSessionAt,
                // Schema note: `ChildProfile` пока не хранит `updatedAt`, поэтому
                // фиксируем момент сбора snapshot'а. Когда модель получит явное
                // поле изменения — заменить на `profile.updatedAt`.
                updatedAt: Date()
            )
        }.filter { $0.parentId == userId }

        let allSessions = await realmActor.asyncFetchMapped(Session.self) { session in
            SessionSnapshot(
                id: session.id,
                childId: session.childId,
                date: session.date,
                targetSound: session.targetSound,
                stage: session.stage,
                durationSeconds: session.durationSeconds,
                totalAttempts: session.totalAttempts,
                correctAttempts: session.correctAttempts,
                isSynced: session.isSynced
            )
        }
        let childIds = Set(children.map(\.id))
        let sessions = allSessions.filter { childIds.contains($0.childId) }

        let progress = await realmActor.asyncFetchMapped(ProgressEntry.self) { entry in
            ProgressEntrySnapshot(
                id: entry.id,
                childId: entry.childId,
                soundTarget: entry.soundTarget,
                stage: entry.stage,
                date: entry.date,
                sessionCount: entry.sessionCount,
                successRate: entry.successRate,
                isStageCompleted: entry.isStageCompleted
            )
        }.filter { childIds.contains($0.childId) }

        HSLogger.sync.info(
            "snapshot children=\(children.count) sessions=\(sessions.count) progress=\(progress.count)"
        )
        return ProgressSnapshotBundle(children: children, sessions: sessions, progress: progress)
    }

    /// Отправляет batch с retry. Conflict resolution merge-by-max применяется для
    /// `ProgressEntry.successRate`, `ChildProfile.currentStreak/totalSessionMinutes`
    /// внутри `performFirestoreBatchWrite` (сервер-side merge via Cloud Function).
    private func uploadSnapshot(_ snapshot: ProgressSnapshotBundle, userId: String) async throws {
        try await performWithRetry(maxAttempts: policy.maxRetryCount, delay: policy.baseDelaySec) {
            try await self.performFirestoreBatchWrite(
                userId: userId,
                children: snapshot.children,
                sessions: snapshot.sessions,
                progress: snapshot.progress
            )
        }
    }

    /// Помечает указанные Session.isSynced = true после успешной выгрузки.
    private func markSessionsSynced(ids: [String]) async {
        guard !ids.isEmpty else { return }
        await realmActor.asyncWrite { realm in
            for sessionId in ids {
                if let live = realm.object(ofType: Session.self, forPrimaryKey: sessionId) {
                    live.isSynced = true
                }
            }
        }
    }

    /// Exponential-backoff retry helper. Performs up to `maxAttempts` attempts, doubling
    /// the delay between each (`base`, `base*2`, `base*4`, …) but never exceeding
    /// `policy.maxDelaySec`. On final failure rethrows the last error.
    private func performWithRetry<T: Sendable>(
        maxAttempts: Int,
        delay: Double,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        var attempt = 0
        var lastError: Error = SyncError.unknown
        while attempt < maxAttempts {
            do {
                return try await operation()
            } catch {
                attempt += 1
                lastError = error
                guard attempt < maxAttempts else { break }
                let wait = backoffDelay(attempt: attempt, base: delay, cap: policy.maxDelaySec)
                HSLogger.sync.info(
                    "Retry attempt \(attempt)/\(maxAttempts) after \(String(format: "%.1f", wait))s — \(error.localizedDescription)"
                )
                await sleeper(wait)
            }
        }
        HSLogger.sync.error("Retry exhausted after \(maxAttempts) attempts: \(lastError.localizedDescription)")
        throw lastError
    }

    /// Единая формула экспоненциальной задержки для всех retry-механизмов сервиса:
    /// `base * 2^(attempt-1)`, ограниченная `cap`. `attempt` — 1-based (первая
    /// повторная попытка = 1). Для `attempt <= 0` возвращает 0.
    private func backoffDelay(attempt: Int, base: Double, cap: Double) -> Double {
        guard attempt > 0 else { return 0 }
        let raw = base * pow(2.0, Double(attempt - 1))
        return min(raw, cap)
    }

    /// Firestore batch write. Stub until `import FirebaseFirestore` is wired at module level
    /// — builds correct document shapes (`users/{uid}/children/{cid}` etc.), validates JSON
    /// serialisability, simulates network latency. Server-side merge-by-max is enforced by
    /// `functions/src/progress.js` Cloud Function + `setData(merge: true)` on the client.
    ///
    /// Пока это заглушка, но контракт с реальным Firestore-бэкендом уже моделируется:
    /// пустой `userId` трактуется как серверный reject (non-2xx) и пробрасывается как
    /// `SyncError.remoteRejected` — именно его UI будет показывать при отказах вида
    /// `PERMISSION_DENIED` / `UNAUTHENTICATED`, когда Firebase SDK будет подключён.
    private func performFirestoreBatchWrite(
        userId: String,
        children: [ChildProfileSnapshot],
        sessions: [SessionSnapshot],
        progress: [ProgressEntrySnapshot]
    ) async throws {
        guard !userId.isEmpty else {
            throw SyncError.remoteRejected("empty userId")
        }

        let childDocs = children.map { $0.firestoreDict() }
        let sessionDocs = sessions.map { $0.firestoreDict(parentId: userId) }
        let progressDocs = progress.map { $0.firestoreDict(parentId: userId) }

        for dict in childDocs + sessionDocs + progressDocs {
            guard JSONSerialization.isValidJSONObject(dict) else {
                throw SyncError.invalidPayload
            }
        }
        try await Task.sleep(for: .milliseconds(120))
        let cCount = childDocs.count
        let sCount = sessionDocs.count
        let pCount = progressDocs.count
        HSLogger.sync.debug(
            "Firestore stub uid=\(userId, privacy: .private) c=\(cCount) s=\(sCount) p=\(pCount)"
        )
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
            let delay = backoffDelay(
                attempt: item.retryCount,
                base: policy.baseDelaySec,
                cap: policy.maxDelaySec
            )
            HSLogger.sync.info(
                "Retry #\(item.retryCount) for \(entityId, privacy: .private) — waiting \(String(format: "%.1f", delay))s"
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
            HSLogger.sync.debug("Synced \(entityType):\(entityId, privacy: .private)")
        } catch {
            let message = error.localizedDescription
            await realmActor.asyncWrite { realm in
                if let live = realm.object(ofType: SyncQueueItem.self, forPrimaryKey: itemId) {
                    live.retryCount += 1
                    live.lastErrorMessage = message
                }
            }
            HSLogger.sync.error("Sync failed for \(entityId, privacy: .private) (\(entityType)): \(message)")
        }
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
        try await Task.sleep(for: .milliseconds(100))
        HSLogger.sync.debug(
            "Uploaded \(entityType):\(entityId, privacy: .private) payload=\(payload.count) bytes"
        )
    }

    // MARK: - Helpers

    private func maxOptional<T: Comparable>(_ lhs: T?, _ rhs: T?) -> T? {
        switch (lhs, rhs) {
        case let (left?, right?): return max(left, right)
        case let (left?, nil): return left
        case let (nil, right?): return right
        case (nil, nil): return nil
        }
    }
}

// MARK: - SyncError

/// Ошибки, специфичные для SyncService. `LocalizedError` — чтобы UI мог показать
/// человекочитаемое сообщение без жёсткой строки.
public enum SyncError: LocalizedError, Sendable {
    case offline
    case invalidPayload
    case remoteRejected(String)
    case unknown

    public var errorDescription: String? {
        switch self {
        case .offline:
            return String(localized: "sync.error.offline")
        case .invalidPayload:
            return String(localized: "sync.error.invalid_payload")
        case .remoteRejected(let reason):
            return String(format: String(localized: "sync.error.remote_rejected"), reason)
        case .unknown:
            return String(localized: "sync.error.unknown")
        }
    }
}

// Firestore payload snapshots live in `SyncSnapshots.swift` alongside this file.
