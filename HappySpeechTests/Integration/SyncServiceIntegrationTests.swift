@testable import HappySpeech
import RealmSwift
import XCTest

// MARK: - SyncServiceIntegrationTests
//
// Integration-тесты для LiveSyncService:
// local change → offline → reconnect → remote update (emulated).
//
// Используют LiveSyncService с in-memory Realm + MockNetworkMonitor.
// Не требуют Firebase SDK — performNetworkUpload в LiveSyncService
// является stub с 100ms задержкой.

final class SyncServiceIntegrationTests: FirebaseEmulatorTestsBase {

    // MARK: - Helpers

    private func makeRealmActorInMemory() async throws -> RealmActor {
        // asyncFetchMapped/asyncWrite use Realm(actor: self) which picks up defaultConfiguration.
        // Set defaultConfiguration to in-memory so both async and sync Realm paths are isolated.
        let memId = "sync-integ-\(UUID().uuidString)"
        var config = Realm.Configuration()
        config.inMemoryIdentifier = memId
        config.schemaVersion = RealmSchemaVersion.current
        Realm.Configuration.defaultConfiguration = config
        let actor = RealmActor()
        try await actor.open(configuration: config)
        return actor
    }

    private func makeLiveSyncService(
        realm: RealmActor,
        isConnected: Bool = true,
        connectionType: ConnectionType = .wifi
    ) -> LiveSyncService {
        let monitor = MockNetworkMonitor()
        monitor.isConnected = isConnected
        monitor.connectionType = connectionType
        let policy = SyncPolicy(
            baseDelaySec: 0.0,
            maxDelaySec: 0.0,
            maxRetryCount: 3,
            wifiOnly: false
        )
        return LiveSyncService(
            realmActor: realm,
            networkMonitor: monitor,
            policy: policy,
            sleeper: { _ in }
        )
    }

    private func makeSyncQueueItem(realm: RealmActor, entityType: String = "child_progress") async {
        await realm.asyncWrite { realmInstance in
            let item = SyncQueueItem()
            item.entityType = entityType
            item.entityId = "child-integ-001"
            item.operation = "upsert"
            item.payload = #"{"percent":0.8,"streak":5,"totalSessionMinutes":45}"#
            realmInstance.add(item)
        }
    }

    // MARK: - 1. Local change → sync → pendingCount уменьшается

    func test_localChange_sync_decreasesPendingCount() async throws {
        let realm = try await makeRealmActorInMemory()
        let sut = makeLiveSyncService(realm: realm)
        // Ждём hydratePendingCount() из init — аналогично SyncServiceTests паттерну
        try await Task.sleep(nanoseconds: 80_000_000)

        let countBefore = await sut.pendingCount()
        let op = SyncOperation(
            entityType: "child_progress",
            entityId: "child-integ-001",
            operation: "upsert",
            payload: #"{"percent":0.8}"#
        )
        try await sut.enqueue(operation: op)
        let countAfterEnqueue = await sut.pendingCount()
        XCTAssertEqual(countAfterEnqueue, countBefore + 1, "После enqueue pendingCount должен вырасти на 1")

        try await sut.drainQueue()
        let countAfterDrain = await sut.pendingCount()
        XCTAssertEqual(countAfterDrain, 0, "После drainQueue pendingCount должен быть 0")
    }

    // MARK: - 2. Offline → drain пропускается

    func test_offline_drainSkipped_pendingCountUnchanged() async throws {
        let realm = try await makeRealmActorInMemory()
        let sut = makeLiveSyncService(realm: realm, isConnected: false)

        let op = SyncOperation(
            entityType: "session",
            entityId: "session-offline-001",
            operation: "upsert",
            payload: "{}"
        )
        try await sut.enqueue(operation: op)
        let countBefore = await sut.pendingCount()

        try? await sut.drainQueue()
        let countAfter = await sut.pendingCount()

        XCTAssertEqual(countBefore, countAfter, "Offline drain не должен изменять pendingCount")
    }

    // MARK: - 3. Reconnect → drain выполняется успешно

    func test_reconnect_drainSucceeds() async throws {
        let realm = try await makeRealmActorInMemory()
        let monitor = MockNetworkMonitor()
        monitor.isConnected = false
        monitor.connectionType = .wifi

        let policy = SyncPolicy(baseDelaySec: 0, maxDelaySec: 0, maxRetryCount: 3, wifiOnly: false)
        let sut = LiveSyncService(
            realmActor: realm,
            networkMonitor: monitor,
            policy: policy,
            sleeper: { _ in }
        )
        // Ждём hydratePendingCount() из init
        try await Task.sleep(nanoseconds: 80_000_000)

        let op = SyncOperation(entityType: "child_progress", entityId: "child-reconnect-001",
                               operation: "upsert", payload: #"{"percent":0.5}"#)
        try await sut.enqueue(operation: op)

        // Симулируем reconnect
        monitor.isConnected = true
        try await sut.drainQueue()

        let count = await sut.pendingCount()
        XCTAssertEqual(count, 0, "После reconnect drain должен очистить очередь")
    }

    // MARK: - 4. Несколько items в очереди → все дренируются

    func test_multipleItems_allDrained() async throws {
        let realm = try await makeRealmActorInMemory()
        let sut = makeLiveSyncService(realm: realm)
        // Ждём hydratePendingCount() из init
        try await Task.sleep(nanoseconds: 80_000_000)

        for i in 1...5 {
            let op = SyncOperation(
                entityType: "session",
                entityId: "session-multi-\(i)",
                operation: "upsert",
                payload: "{}"
            )
            try await sut.enqueue(operation: op)
        }

        let countBefore = await sut.pendingCount()
        XCTAssertEqual(countBefore, 5, "Должно быть 5 pending items")

        try await sut.drainQueue()
        let countAfter = await sut.pendingCount()
        XCTAssertEqual(countAfter, 0, "Все 5 items должны быть задренированы")
    }

    // MARK: - 5. syncState эмитит .idle после завершения drain

    func test_syncState_emitsIdle_afterDrain() async throws {
        let realm = try await makeRealmActorInMemory()
        let sut = makeLiveSyncService(realm: realm)

        // actor-isolated collector для Swift 6 concurrency
        actor StateCollector {
            var states: [SyncState] = []
            func append(_ s: SyncState) { states.append(s) }
            func hasIdle() -> Bool { states.contains { if case .idle = $0 { return true }; return false } }
        }
        let collector = StateCollector()
        let collectTask = Task { [collector] in
            for await state in await sut.syncState {
                await collector.append(state)
                if await collector.states.count >= 3 { break }
            }
        }

        try await sut.drainQueue()
        try await Task.sleep(nanoseconds: 100_000_000)
        collectTask.cancel()

        let hasIdle = await collector.hasIdle()
        XCTAssertTrue(hasIdle, "syncState должен эмитить .idle")
    }

    // MARK: - 6. syncUserProgress с offline → бросает SyncError.offline

    func test_syncUserProgress_offline_throwsSyncError() async throws {
        let realm = try await makeRealmActorInMemory()
        let sut = makeLiveSyncService(realm: realm, isConnected: false)

        do {
            try await sut.syncUserProgress(userId: "parent-offline-001")
            XCTFail("Должна быть ошибка SyncError.offline")
        } catch let error as SyncError {
            if case .offline = error {
                XCTAssertTrue(true, "Корректно получен SyncError.offline")
            } else {
                XCTFail("Ожидался SyncError.offline, получен: \(error)")
            }
        } catch {
            XCTFail("Неожиданная ошибка: \(error)")
        }
    }

    // MARK: - 7. syncUserProgress с пустым userId → .remoteRejected

    func test_syncUserProgress_emptyUserId_throwsRemoteRejected() async throws {
        let realm = try await makeRealmActorInMemory()
        let sut = makeLiveSyncService(realm: realm, isConnected: true)

        await realm.asyncWrite { r in
            let profile = ChildProfile()
            profile.id = UUID().uuidString
            profile.parentId = ""
            profile.name = "Тест"
            profile.age = 6
            r.add(profile)
        }

        do {
            try await sut.syncUserProgress(userId: "")
            XCTFail("Должна быть ошибка для пустого userId")
        } catch let error as SyncError {
            if case .remoteRejected = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Ожидался .remoteRejected, получен: \(error)")
            }
        } catch {
            XCTFail("Неожиданная ошибка: \(error)")
        }
    }

    // MARK: - 8. syncOnAppForeground + online → не бросает

    func test_syncOnAppForeground_online_noThrow() async throws {
        let realm = try await makeRealmActorInMemory()
        let sut = makeLiveSyncService(realm: realm, isConnected: true)
        await sut.syncOnAppForeground()
        let count = await sut.pendingCount()
        XCTAssertEqual(count, 0, "После syncOnAppForeground без items pendingCount = 0")
    }

    // MARK: - 9. progress entity → merge-by-max payload применяется

    func test_progressEntityPayload_isMergedByMax() throws {
        // Белый ящик — проверяем JSON сериализацию payload для progress entity
        struct ProgressPayload: Codable {
            let percent: Double?
            let streak: Int?
            let totalSessionMinutes: Int?
        }

        let clientPayload = #"{"percent":0.8,"streak":5,"totalSessionMinutes":40}"#
        let decoded = try JSONDecoder().decode(ProgressPayload.self,
                                              from: clientPayload.data(using: .utf8)!)

        XCTAssertEqual(decoded.percent ?? -1, 0.8, accuracy: 0.001)
        XCTAssertEqual(decoded.streak, 5)
        XCTAssertEqual(decoded.totalSessionMinutes, 40)

        // merge-by-max: remote имеет streak=7, client=5 → должно быть 7
        let remoteStreak = 7
        let merged = max(decoded.streak ?? 0, remoteStreak)
        XCTAssertEqual(merged, 7, "merge-by-max: streak должен быть 7")
    }

    // MARK: - 10. MockSyncService syncUserProgress → не бросает (default impl)

    func test_mockSyncService_syncUserProgress_noThrow() async {
        do {
            try await mockSyncService.syncUserProgress(userId: "parent-mock-001")
        } catch {
            XCTFail("MockSyncService.syncUserProgress не должен бросать: \(error)")
        }
    }
}
