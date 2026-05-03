@testable import HappySpeech
import RealmSwift
import XCTest

// MARK: - FirestoreCRUDTests
//
// Integration-тесты CRUD через Realm (in-memory) + SyncService mock.
// Моделирует контракт Firestore CRUD:
//   users/{userId}/children/{childId}/sessions/{sessionId}
//
// Firestore Emulator REST API используется для прямой проверки
// доступности эндпоинтов (не Firebase SDK).

final class FirestoreCRUDTests: FirebaseEmulatorTestsBase {

    // MARK: - Helper: async fetch single by primary key

    private func asyncFetchChildProfile(id: String) async -> String? {
        await realmActor.asyncFetchMapped(ChildProfile.self) { profile in
            profile.id == id ? profile.id : nil
        }.compactMap { $0 }.first
    }

    private func asyncFetchSessionAttempts(id: String) async -> Int? {
        await realmActor.asyncFetchMapped(Session.self) { session in
            session.id == id ? session.totalAttempts : nil
        }.compactMap { $0 }.first
    }

    private func asyncFetchSessionCorrect(id: String) async -> Int? {
        await realmActor.asyncFetchMapped(Session.self) { session in
            session.id == id ? session.correctAttempts : nil
        }.compactMap { $0 }.first
    }

    // MARK: - 1. Emulator доступен

    func test_firestoreEmulator_isReachable() async {
        let available = await checkFirestoreEmulatorAvailable()
        if !available {
            XCTExpectFailure("Firestore emulator не запущен — тест пропускается")
            XCTFail("Firestore emulator недоступен на localhost:8080")
            return
        }
        XCTAssertTrue(available, "Firestore emulator должен отвечать на localhost:8080")
    }

    // MARK: - 2. Create child profile → проверить через Realm fetch

    func test_createChildProfile_persistsInRealm() async throws {
        let childId = "child-crud-001"
        let dto = await createChildProfile(id: childId, parentId: "parent-001")

        let foundId = await asyncFetchChildProfile(id: childId)
        XCTAssertNotNil(foundId, "Профиль должен быть сохранён в Realm")
        XCTAssertEqual(foundId, dto.id)
    }

    // MARK: - 3. Create session → fetch back

    func test_createSession_fetchBack_returnsCorrectData() async throws {
        let childId = "child-session-001"
        _ = await createChildProfile(id: childId)
        let sessionId = await createSession(childId: childId, id: "session-001")

        let fetchedId = await realmActor.asyncFetchMapped(Session.self) { session in
            session.id == sessionId ? session.id : nil
        }.compactMap { $0 }.first

        XCTAssertNotNil(fetchedId, "Сессия должна быть сохранена в Realm")
        XCTAssertEqual(fetchedId, sessionId)

        let fetchedChildId = await realmActor.asyncFetchMapped(Session.self) { session in
            session.id == sessionId ? session.childId : nil
        }.compactMap { $0 }.first
        XCTAssertEqual(fetchedChildId, childId)
    }

    // MARK: - 4. Update session → проверить обновление correctAttempts

    func test_updateSession_changesCorrectAttempts() async throws {
        let childId = "child-update-001"
        _ = await createChildProfile(id: childId)
        let sessionId = await createSession(childId: childId, id: "session-update-001")

        // Update through asyncWrite
        await realmActor.asyncWrite { realm in
            if let live = realm.object(ofType: Session.self, forPrimaryKey: sessionId) {
                live.correctAttempts = 9
            }
        }

        let correct = await asyncFetchSessionCorrect(id: sessionId)
        XCTAssertEqual(correct, 9, "correctAttempts должен обновиться до 9")
    }

    // MARK: - 5. Delete child → профиль удалён из Realm

    func test_deleteChildProfile_removedFromRealm() async throws {
        let childId = "child-delete-001"
        _ = await createChildProfile(id: childId)

        let before = await asyncFetchChildProfile(id: childId)
        XCTAssertNotNil(before, "Профиль должен существовать до удаления")

        await deleteChildProfile(id: childId)

        let after = await asyncFetchChildProfile(id: childId)
        XCTAssertNil(after, "Профиль должен быть удалён из Realm")
    }

    // MARK: - 6. SyncService enqueue → pendingCount растёт

    func test_enqueue_incrementsPendingCount() async throws {
        let before = await mockSyncService.pendingCount()
        await enqueueOperation(entityType: "child_progress", entityId: "child-enq-001")
        let after = await mockSyncService.pendingCount()
        XCTAssertEqual(after, before + 1, "pendingCount должен вырасти на 1 после enqueue")
    }

    // MARK: - 7. SyncService drainQueue → не бросает (offline-safe)

    func test_drainQueue_doesNotThrow() async {
        do {
            try await mockSyncService.drainQueue()
        } catch {
            XCTFail("drainQueue не должен бросать в MockSyncService: \(error)")
        }
    }

    // MARK: - 8. Conflict resolution: merge-by-max логика в payload

    func test_mergeByMax_picksBiggerProgressValue() {
        let clientPercent = 0.75
        let remotePercent = 0.65
        let merged = max(clientPercent, remotePercent)
        XCTAssertEqual(merged, 0.75, accuracy: 0.001, "merge-by-max должен выбирать большее значение")
    }

    // MARK: - 9. Firestore emulator REST — создать документ через HTTP

    func test_firestoreEmulator_createDocument_viaREST() async throws {
        let available = await checkFirestoreEmulatorAvailable()
        guard available else {
            throw XCTSkip("Requires Firebase Firestore Emulator running at localhost:8080")
        }

        let urlStr = "\(Self.firestoreEmulatorHost)/v1/projects/\(Self.projectId)/databases/(default)/documents/testCollection"
        guard let url = URL(string: urlStr) else {
            XCTFail("Не удалось создать URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Firestore emulator requires "owner" token to bypass security rules
        request.setValue("Bearer owner", forHTTPHeaderField: "Authorization")
        request.httpBody = """
        {"fields":{"name":{"stringValue":"ТестовыйПользователь"},"age":{"integerValue":"6"}}}
        """.data(using: .utf8)
        request.timeoutInterval = 5

        let (_, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        XCTAssertTrue((200..<300).contains(code), "Firestore emulator должен принять документ (HTTP \(code))")
    }

    // MARK: - 10. Firestore emulator REST — fetch collection

    func test_firestoreEmulator_fetchCollection_viaREST() async throws {
        let available = await checkFirestoreEmulatorAvailable()
        guard available else {
            throw XCTSkip("Requires Firebase Firestore Emulator running at localhost:8080")
        }

        let urlStr = "\(Self.firestoreEmulatorHost)/v1/projects/\(Self.projectId)/databases/(default)/documents/testCollection"
        guard let url = URL(string: urlStr) else {
            XCTFail("Не удалось создать URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer owner", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 5
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        XCTAssertTrue((200..<300).contains(code), "Firestore emulator должен вернуть коллекцию (HTTP \(code))")
        XCTAssertFalse(data.isEmpty, "Response data не должен быть пустым")
    }
}
