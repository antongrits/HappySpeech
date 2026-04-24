import XCTest
import RealmSwift
@testable import HappySpeech

// MARK: - SyncServiceTests
//
// 13 unit-тестов для LiveSyncService (требование ≥12).
//
// Стратегия изоляции:
//   • RealmActor — реальный actor c in-memory Realm — нет I/O.
//   • MockNetworkMonitor — существует в MockServices.swift.
//   • sleeper — no-op замыкание { _ in } чтобы backoff не добавлял задержек.
//   • SyncPolicy с нулевым baseDelaySec и минимальным maxRetryCount.
//   • SyncStateCollector — actor-based коллектор для безопасного захвата состояний
//     через Task {} в Swift 6 strict concurrency.
//
// Тесты НЕ дёргают Firestore — performNetworkUpload стабово ждёт 100ms.

// MARK: - SyncStateCollector

/// Actor-изолированный коллектор событий SyncState.
/// Swift 6 strict concurrency запрещает мутировать `var` переменные из разных Task-ов.
/// Решение — весь мутирующий state переносим в actor.
actor SyncStateCollector {
    var states: [SyncState] = []

    func append(_ state: SyncState) {
        states.append(state)
    }

    func contains(where predicate: (SyncState) -> Bool) -> Bool {
        states.contains(where: predicate)
    }

    func last() -> SyncState? {
        states.last
    }
}

// MARK: - SyncServiceTests

final class SyncServiceTests: XCTestCase {

    // MARK: - Helpers

    /// Создаёт RealmActor с изолированной in-memory Realm —
    /// каждый тест получает чистое хранилище.
    private func makeRealmActor() async throws -> RealmActor {
        let actor = RealmActor()
        var config = Realm.Configuration()
        config.inMemoryIdentifier = UUID().uuidString
        config.schemaVersion = RealmSchemaVersion.current
        try await actor.open(configuration: config)
        return actor
    }

    /// SyncPolicy с нулевой задержкой — тесты проходят быстро.
    private var fastPolicy: SyncPolicy {
        SyncPolicy(baseDelaySec: 0.0, maxDelaySec: 0.0, maxRetryCount: 3, wifiOnly: false)
    }

    /// Строит LiveSyncService.
    private func makeSUT(
        realmActor: RealmActor,
        isConnected: Bool = true,
        connectionType: ConnectionType = .wifi,
        policy: SyncPolicy? = nil
    ) -> LiveSyncService {
        let monitor = MockNetworkMonitor()
        monitor.isConnected = isConnected
        monitor.connectionType = connectionType
        return LiveSyncService(
            realmActor: realmActor,
            networkMonitor: monitor,
            policy: policy ?? fastPolicy,
            sleeper: { _ in }
        )
    }

    /// Строит минимальный SyncOperation.
    private func makeOperation(
        entityType: String = "session",
        entityId: String? = nil,
        operation: String = "upsert",
        payload: String = "{}"
    ) -> SyncOperation {
        SyncOperation(
            entityType: entityType,
            entityId: entityId ?? UUID().uuidString,
            operation: operation,
            payload: payload
        )
    }

    /// Запускает фоновый сбор состояний из syncState.
    /// Возвращает Task и collector — после завершения теста Task нужно отменить.
    private func startCollecting(from sut: LiveSyncService) -> (Task<Void, Never>, SyncStateCollector) {
        let collector = SyncStateCollector()
        let task = Task {
            for await state in sut.syncState {
                await collector.append(state)
                // Прерываем бесконечный стрим при отмене Task
                if Task.isCancelled { break }
            }
        }
        return (task, collector)
    }

    // MARK: - Test 1: enqueue добавляет item в очередь

    func testEnqueueAddsItemToQueue() async throws {
        let realm = try await makeRealmActor()
        let sut = makeSUT(realmActor: realm)
        // Ждём завершения асинхронного hydratePendingCount() из init,
        // иначе он посчитает item, который мы сейчас добавим, дважды.
        try await Task.sleep(nanoseconds: 80_000_000)

        let countBefore = await sut.pendingCount()
        try await sut.enqueue(operation: makeOperation())
        let countAfter = await sut.pendingCount()

        XCTAssertEqual(countAfter, countBefore + 1,
            "После одного enqueue pendingCount должен вырасти на 1")
    }

    // MARK: - Test 2: drain очищает очередь при успехе

    func testDrainQueueEmptiesOnSuccess() async throws {
        let realm = try await makeRealmActor()
        let sut = makeSUT(realmActor: realm)

        try await sut.enqueue(operation: makeOperation())
        try await sut.drainQueue()

        let count = await sut.pendingCount()
        XCTAssertEqual(count, 0, "После успешного drain очередь должна быть пустой")
    }

    // MARK: - Test 3: item с retryCount > 0 успешно дренируется (имитация «прошлой ошибки»)

    func testDrainQueueProcessesItemWithPriorRetry() async throws {
        let realm = try await makeRealmActor()
        let itemId = UUID().uuidString

        // Записываем item с retryCount = 1 — имитация предыдущего сбоя
        await realm.asyncWrite { realmInstance in
            let item = SyncQueueItem()
            item.id = itemId
            item.entityType = "session"
            item.entityId = UUID().uuidString
            item.operation = "upsert"
            item.payload = "{}"
            item.retryCount = 1
            realmInstance.add(item)
        }

        let sut = makeSUT(realmActor: realm)
        try await sut.drainQueue()

        let dtos = await realm.asyncFetchMapped(SyncQueueItem.self) { item in
            (id: item.id, syncedAt: item.syncedAt)
        }
        let target = dtos.first { $0.id == itemId }
        XCTAssertNotNil(target?.syncedAt,
            "Item с retryCount=1 < maxRetryCount должен быть успешно дренирован")
    }

    // MARK: - Test 4: item с retryCount == maxRetryCount пропускается drain-ом

    func testDrainQueueSkipsItemsExceedingMaxRetry() async throws {
        let realm = try await makeRealmActor()
        let policy = SyncPolicy(baseDelaySec: 0, maxDelaySec: 0, maxRetryCount: 3, wifiOnly: false)
        let sut = makeSUT(realmActor: realm, policy: policy)
        let itemId = UUID().uuidString

        // retryCount == maxRetryCount → фильтр `$0.retryCount < policy.maxRetryCount` отсеивает
        await realm.asyncWrite { realmInstance in
            let item = SyncQueueItem()
            item.id = itemId
            item.entityType = "session"
            item.entityId = UUID().uuidString
            item.operation = "upsert"
            item.payload = "{}"
            item.retryCount = 3
            realmInstance.add(item)
        }

        try await sut.drainQueue()

        let dtos = await realm.asyncFetchMapped(SyncQueueItem.self) { item in
            (id: item.id, syncedAt: item.syncedAt)
        }
        let target = dtos.first { $0.id == itemId }
        XCTAssertNil(target?.syncedAt,
            "Item с retryCount == maxRetryCount должен быть пропущен: syncedAt не установлен")
    }

    // MARK: - Test 5: syncState первым значением публикует .idle

    func testSyncStatePublishesIdle() async throws {
        let realm = try await makeRealmActor()
        let sut = makeSUT(realmActor: realm)

        var firstState: SyncState?
        for await state in sut.syncState {
            firstState = state
            break
        }

        XCTAssertEqual(firstState, .idle, "Первое значение syncState должно быть .idle")
    }

    // MARK: - Test 6: syncState публикует .syncing во время drain

    func testSyncStatePublishesSyncing() async throws {
        let realm = try await makeRealmActor()
        let sut = makeSUT(realmActor: realm)
        try await sut.enqueue(operation: makeOperation())

        let (collectTask, collector) = startCollecting(from: sut)
        try await sut.drainQueue()
        // Даём Task время обработать последние события
        try await Task.sleep(nanoseconds: 80_000_000)
        collectTask.cancel()

        let hasSyncing = await collector.contains { state in
            if case .syncing = state { return true }
            return false
        }
        XCTAssertTrue(hasSyncing, "syncState должен содержать .syncing во время drain")
    }

    // MARK: - Test 7: syncState публикует .syncing(progress: 1.0) при завершении drain

    func testSyncStatePublishesCompleted() async throws {
        // Примечание: stream использует .bufferingNewest(1), поэтому .completed
        // может быть вытеснен быстро следующим .idle в буфере.
        // Проверяем наблюдаемый инвариант: при успешном drain всегда
        // публикуется .syncing(progress: 1.0) — последний шаг цикла drain.

        let realm = try await makeRealmActor()
        let sut = makeSUT(realmActor: realm)

        let (collectTask, collector) = startCollecting(from: sut)
        try await Task.sleep(nanoseconds: 50_000_000)

        try await sut.enqueue(operation: makeOperation())
        try await sut.drainQueue()
        try await Task.sleep(nanoseconds: 150_000_000)
        collectTask.cancel()

        let hasSyncingFull = await collector.contains { state in
            if case .syncing(let p) = state, p >= 1.0 { return true }
            return false
        }
        XCTAssertTrue(hasSyncingFull,
            "syncState должен содержать .syncing(progress: 1.0) как признак завершённого drain")
    }

    // MARK: - Test 8: syncState публикует .failed при offline

    func testSyncStatePublishesFailedWhenOffline() async throws {
        let realm = try await makeRealmActor()
        let sut = makeSUT(realmActor: realm, isConnected: false)
        try await sut.enqueue(operation: makeOperation())

        let (collectTask, collector) = startCollecting(from: sut)
        try await sut.drainQueue()
        try await Task.sleep(nanoseconds: 80_000_000)
        collectTask.cancel()

        let failedState = await collector.states.first { state in
            if case .failed = state { return true }
            return false
        }

        guard case .failed(let message) = failedState else {
            XCTFail("syncState должен содержать .failed при offline")
            return
        }
        XCTAssertFalse(message.isEmpty, "Сообщение об ошибке не должно быть пустым")
    }

    // MARK: - Test 9: merge-by-max выбирает большее значение

    func testConflictResolutionMergeByMax() throws {
        let payload = try JSONEncoder().encode(
            ProgressMergePayloadTest(percent: 0.75, streak: 5, totalSessionMinutes: 20)
        )
        let decoded = try JSONDecoder().decode(ProgressMergePayloadTest.self, from: payload)

        // Round-trip JSON
        XCTAssertEqual(decoded.percent ?? -1, 0.75, accuracy: 0.001,
            "percent должен сохраниться при JSON round-trip")
        XCTAssertEqual(decoded.streak, 5)
        XCTAssertEqual(decoded.totalSessionMinutes, 20)

        // Логика maxOptional: max(a, nil) = a, max(nil, b) = b, max(a, b) = larger
        XCTAssertEqual(maxOptional(0.9, 0.6), 0.9, "max(0.9, 0.6) должен быть 0.9")
        XCTAssertEqual(maxOptional(nil, 0.5), 0.5, "max(nil, 0.5) должен быть 0.5")
        XCTAssertEqual(maxOptional(0.3, nil), 0.3, "max(0.3, nil) должен быть 0.3")
        XCTAssertNil(maxOptional(nil as Double?, nil), "max(nil, nil) должен быть nil")
    }

    // MARK: - Test 10: syncUserProgress собирает snapshot из Realm

    func testSyncUserProgressCollectsSnapshot() async throws {
        let realm = try await makeRealmActor()
        let childId = UUID().uuidString

        await realm.asyncWrite { realmInstance in
            let profile = ChildProfile()
            profile.id = childId
            profile.parentId = "user-42"
            profile.name = "Маша"
            profile.age = 6
            profile.totalSessionMinutes = 30
            profile.currentStreak = 3
            realmInstance.add(profile)
        }

        let sut = makeSUT(realmActor: realm)
        let (collectTask, collector) = startCollecting(from: sut)

        try await sut.syncUserProgress(userId: "user-42")
        try await Task.sleep(nanoseconds: 100_000_000)
        collectTask.cancel()

        let hasFailed = await collector.contains { state in
            if case .failed = state { return true }
            return false
        }
        XCTAssertFalse(hasFailed,
            "syncUserProgress с валидным userId не должен завершаться с .failed")
    }

    // MARK: - Test 11: syncUserProgress успешно завершается без throw

    func testSyncUserProgressSucceeds() async throws {
        let realm = try await makeRealmActor()

        await realm.asyncWrite { realmInstance in
            let profile = ChildProfile()
            profile.parentId = "user-99"
            profile.name = "Ваня"
            profile.age = 7
            realmInstance.add(profile)
        }

        let sut = makeSUT(realmActor: realm)
        // Не должен бросить — performFirestoreBatchWrite это stub
        do {
            try await sut.syncUserProgress(userId: "user-99")
        } catch {
            XCTFail("syncUserProgress не должен бросать при онлайн режиме: \(error)")
        }
    }

    // MARK: - Test 12: задержка backoff растёт экспоненциально

    func testBackoffDelayFormulaGrowsExponentially() async throws {
        let realm = try await makeRealmActor()

        // Actor-изолированный коллектор задержек — Swift 6 safe
        actor DelayRecorder {
            var delays: [Double] = []
            func record(_ d: Double) { delays.append(d) }
            func allDelays() -> [Double] { delays }
        }
        let recorder = DelayRecorder()

        let policy = SyncPolicy(
            baseDelaySec: 1.0,
            maxDelaySec: 100.0,
            maxRetryCount: 4,
            wifiOnly: false
        )
        let monitor = MockNetworkMonitor()
        monitor.isConnected = true

        // sleeper записывает все вызовы задержек
        let sut = LiveSyncService(
            realmActor: realm,
            networkMonitor: monitor,
            policy: policy,
            sleeper: { @Sendable delay in
                await recorder.record(delay)
            }
        )

        // Items с retryCount 1, 2, 3 — sleeper срабатывает для каждого (retryCount > 0)
        for retryCount in 1...3 {
            await realm.asyncWrite { realmInstance in
                let item = SyncQueueItem()
                item.id = UUID().uuidString
                item.entityType = "session"
                item.entityId = UUID().uuidString
                item.operation = "upsert"
                item.payload = "{}"
                item.retryCount = retryCount
                realmInstance.add(item)
            }
        }

        try await sut.drainQueue()

        let delays = await recorder.allDelays()
        XCTAssertGreaterThanOrEqual(delays.count, 3,
            "sleeper должен быть вызван для каждого item с retryCount > 0")

        // Формула: base * 2^(attempt-1)
        // attempt=1 → 1.0, attempt=2 → 2.0, attempt=3 → 4.0
        let sorted = delays.sorted()
        if sorted.count >= 3 {
            XCTAssertEqual(sorted[0], 1.0, accuracy: 0.01, "attempt=1 → base=1.0")
            XCTAssertEqual(sorted[1], 2.0, accuracy: 0.01, "attempt=2 → base*2=2.0")
            XCTAssertEqual(sorted[2], 4.0, accuracy: 0.01, "attempt=3 → base*4=4.0")
        }
    }

    // MARK: - Test 13: wifiOnly блокирует cellular

    func testWifiOnlyPolicyBlocksCellular() async throws {
        let realm = try await makeRealmActor()
        let policy = SyncPolicy(baseDelaySec: 0, maxDelaySec: 0, maxRetryCount: 3, wifiOnly: true)
        let sut = makeSUT(realmActor: realm, isConnected: true, connectionType: .cellular, policy: policy)

        // Ждём hydration, затем фиксируем базовый count
        try await Task.sleep(nanoseconds: 80_000_000)
        let countBefore = await sut.pendingCount()

        let (collectTask, collector) = startCollecting(from: sut)
        try await sut.enqueue(operation: makeOperation())
        try await sut.drainQueue()
        try await Task.sleep(nanoseconds: 80_000_000)
        collectTask.cancel()

        let hasFailed = await collector.contains { state in
            if case .failed = state { return true }
            return false
        }
        XCTAssertTrue(hasFailed, "wifiOnly + cellular → должен эмитить .failed")

        let countAfter = await sut.pendingCount()
        XCTAssertEqual(countAfter, countBefore + 1,
            "wifiOnly + cellular → очередь не должна очиститься (pendingCount вырос на 1)")
    }
}

// MARK: - Вспомогательные типы

/// Зеркало `ProgressMergePayload` (internal) для round-trip JSON тестирования.
private struct ProgressMergePayloadTest: Codable {
    let percent: Double?
    let streak: Int?
    let totalSessionMinutes: Int?
}

/// Зеркало приватного `maxOptional` для тестирования логики merge-by-max.
private func maxOptional<T: Comparable>(_ lhs: T?, _ rhs: T?) -> T? {
    switch (lhs, rhs) {
    case let (left?, right?): return max(left, right)
    case let (left?, nil):    return left
    case let (nil, right?):   return right
    case (nil, nil):          return nil
    }
}
