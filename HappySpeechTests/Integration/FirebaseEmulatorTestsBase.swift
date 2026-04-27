@testable import HappySpeech
import RealmSwift
import XCTest

// MARK: - FirebaseEmulatorTestsBase
//
// Базовый класс для integration-тестов с Firebase Emulator.
// Эмуляторы: Auth — localhost:9099, Firestore — localhost:8080.
//
// Все интеграционные тесты работают через mock-слой (MockAuthService,
// MockSyncService, in-memory Realm), воспроизводя поведение Firebase
// без подключения к реальному облаку.
//
// Firebase Emulator (localhost:9099 / :8080) используется для REST-проверок
// через URLSession напрямую — без Firebase SDK импортов в тестах.

class FirebaseEmulatorTestsBase: XCTestCase {

    // MARK: - Emulator Endpoints

    static let authEmulatorHost = "http://127.0.0.1:9099"
    static let firestoreEmulatorHost = "http://127.0.0.1:8080"
    static let projectId = "happyspeech-dfd95"

    // MARK: - Shared Services

    var mockAuthService: MockAuthService!
    var mockSyncService: MockSyncService!
    var realmActor: RealmActor!

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        try await super.setUp()
        mockAuthService = MockAuthService()
        mockSyncService = MockSyncService()
        realmActor = RealmActor()
        var config = Realm.Configuration()
        config.inMemoryIdentifier = "integration-test-\(UUID().uuidString)"
        config.schemaVersion = RealmSchemaVersion.current
        // actor.open() is actor-isolated sync: called with await from async context
        try await realmActor.open(configuration: config)
    }

    override func tearDown() async throws {
        mockAuthService = nil
        mockSyncService = nil
        realmActor = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Проверяет доступность Auth Emulator через REST.
    func checkAuthEmulatorAvailable() async -> Bool {
        guard let url = URL(string: "\(Self.authEmulatorHost)/emulator/openapi.json") else {
            return false
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    /// Проверяет доступность Firestore Emulator через REST.
    func checkFirestoreEmulatorAvailable() async -> Bool {
        guard let url = URL(string: "\(Self.firestoreEmulatorHost)/v1/projects/\(Self.projectId)/databases") else {
            return false
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            return code < 500
        } catch {
            return false
        }
    }

    /// Создаёт тестовый ChildProfile в in-memory Realm.
    func createChildProfile(id: String = UUID().uuidString, parentId: String = "parent-test-1") async -> ChildProfileDTO {
        let dto = ChildProfileDTO(
            id: id,
            name: "Тест",
            age: 6,
            targetSounds: ["Р"],
            parentId: parentId
        )
        await realmActor.asyncWrite { realm in
            let profile = ChildProfile()
            profile.id = dto.id
            profile.name = dto.name
            profile.age = dto.age
            profile.parentId = dto.parentId
            dto.targetSounds.forEach { profile.targetSounds.append($0) }
            realm.add(profile, update: .modified)
        }
        return dto
    }

    /// Создаёт тестовую Session в in-memory Realm.
    func createSession(childId: String, id: String = UUID().uuidString) async -> String {
        await realmActor.asyncWrite { realm in
            let session = Session()
            session.id = id
            session.childId = childId
            session.targetSound = "Р"
            session.stage = "words"
            session.durationSeconds = 300
            session.totalAttempts = 10
            session.correctAttempts = 7
            realm.add(session)
        }
        return id
    }

    /// Удаляет ChildProfile из in-memory Realm.
    func deleteChildProfile(id: String) async {
        await realmActor.asyncWrite { realm in
            if let obj = realm.object(ofType: ChildProfile.self, forPrimaryKey: id) {
                realm.delete(obj)
            }
        }
    }

    /// Создаёт SyncQueueItem в MockSyncService.
    func enqueueOperation(entityType: String = "child_progress", entityId: String = "child-1") async {
        let op = SyncOperation(
            entityType: entityType,
            entityId: entityId,
            operation: "upsert",
            payload: #"{"percent":0.75,"streak":3,"totalSessionMinutes":30}"#
        )
        try? await mockSyncService.enqueue(operation: op)
    }
}
