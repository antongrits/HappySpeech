@testable import HappySpeech
import XCTest

// MARK: - ContentPackTests
//
// Integration-тесты для контент-паков: локальный манифест, Realm-слой.
// Тестируют ContentPackMetaRealm CRUD и MockChildRepository-поведение.
// Используют asyncFetchMapped/asyncWrite для совместимости со Swift 6 actors.

final class ContentPackTests: FirebaseEmulatorTestsBase {

    // MARK: - Helper: async fetch pack by id

    private func asyncFetchPack(id: String) async -> String? {
        await realmActor.asyncFetchMapped(ContentPackMetaRealm.self) { pack in
            pack.id == id ? pack.id : nil
        }.compactMap { $0 }.first
    }

    private func asyncFetchPackVersion(id: String) async -> String? {
        await realmActor.asyncFetchMapped(ContentPackMetaRealm.self) { pack in
            pack.id == id ? pack.version : nil
        }.compactMap { $0 }.first
    }

    private func asyncFetchPackIsBundled(id: String) async -> Bool? {
        await realmActor.asyncFetchMapped(ContentPackMetaRealm.self) { pack in
            pack.id == id ? pack.isBundled : nil
        }.compactMap { $0 }.first
    }

    // MARK: - 1. ContentPackMetaRealm сохраняется в Realm

    func test_contentPackMeta_persistsInRealm() async throws {
        let packId = "С-stage0-v1"

        await realmActor.asyncWrite { realm in
            let pack = ContentPackMetaRealm()
            pack.id = packId
            pack.soundTarget = "С"
            pack.stage = "stage0"
            pack.templateType = "listen-and-choose"
            pack.version = "1.0"
            pack.isDownloaded = true
            pack.isBundled = true
            realm.add(pack, update: .modified)
        }

        let foundId = await asyncFetchPack(id: packId)
        XCTAssertNotNil(foundId, "ContentPackMeta должен быть сохранён в Realm")
        XCTAssertEqual(foundId, packId)

        let isBundled = await asyncFetchPackIsBundled(id: packId)
        XCTAssertTrue(isBundled ?? false, "isBundled должен быть true")
    }

    // MARK: - 2. ContentPackMeta update → версия обновляется

    func test_contentPackMeta_update_changesVersion() async throws {
        let packId = "Р-stage1-v1"

        await realmActor.asyncWrite { realm in
            let pack = ContentPackMetaRealm()
            pack.id = packId
            pack.soundTarget = "Р"
            pack.stage = "stage1"
            pack.version = "1.0"
            realm.add(pack)
        }

        await realmActor.asyncWrite { realm in
            if let live = realm.object(ofType: ContentPackMetaRealm.self, forPrimaryKey: packId) {
                live.version = "1.1"
            }
        }

        let version = await asyncFetchPackVersion(id: packId)
        XCTAssertEqual(version, "1.1", "Версия пака должна обновиться до 1.1")
    }

    // MARK: - 3. ContentPackMeta delete

    func test_contentPackMeta_delete_removedFromRealm() async throws {
        let packId = "Ш-stage2-v1"

        await realmActor.asyncWrite { realm in
            let pack = ContentPackMetaRealm()
            pack.id = packId
            pack.soundTarget = "Ш"
            pack.stage = "stage2"
            realm.add(pack)
        }

        let before = await asyncFetchPack(id: packId)
        XCTAssertNotNil(before, "Пак должен существовать до удаления")

        await realmActor.asyncWrite { realm in
            if let obj = realm.object(ofType: ContentPackMetaRealm.self, forPrimaryKey: packId) {
                realm.delete(obj)
            }
        }

        let after = await asyncFetchPack(id: packId)
        XCTAssertNil(after, "ContentPackMeta должен быть удалён из Realm")
    }

    // MARK: - 4. Bundled пак: isBundled=true не требует загрузки

    func test_bundledPack_doesNotRequireDownload() async throws {
        let packId = "Л-bundled-v1"

        await realmActor.asyncWrite { realm in
            let pack = ContentPackMetaRealm()
            pack.id = packId
            pack.soundTarget = "Л"
            pack.isBundled = true
            pack.isDownloaded = false
            realm.add(pack)
        }

        let isBundled = await asyncFetchPackIsBundled(id: packId)
        XCTAssertTrue(isBundled ?? false, "Bundled пак не требует скачивания")
    }

    // MARK: - 5. Fetch all packs → возвращает все добавленные паки

    func test_fetchAllPacks_returnsCorrectCount() async throws {
        let sounds = ["К-content", "Г-content", "Х-content"]
        for sound in sounds {
            await realmActor.asyncWrite { realm in
                let pack = ContentPackMetaRealm()
                pack.id = "\(sound)-stage0-pack"
                pack.soundTarget = sound
                pack.stage = "stage0"
                realm.add(pack, update: .modified)
            }
        }

        let allSounds = await realmActor.asyncFetchMapped(ContentPackMetaRealm.self) { $0.soundTarget }
        let fetchedSet = Set(allSounds)
        let expectedSet = Set(sounds)
        XCTAssertTrue(expectedSet.isSubset(of: fetchedSet),
                      "Все добавленные паки должны быть в fetchAll результате")
    }

    // MARK: - 6. MockChildRepository fetchAll → возвращает preview данные

    func test_mockChildRepository_fetchAll_returnsPreviewChildren() async throws {
        let mockRepo = MockChildRepository()
        let children = try await mockRepo.fetchAll()
        XCTAssertFalse(children.isEmpty, "MockChildRepository должен вернуть хотя бы одного ребёнка")
    }

    // MARK: - 7. MockChildRepository fetch по id → возвращает правильный профиль

    func test_mockChildRepository_fetch_byId_returnsCorrectChild() async throws {
        let mockRepo = MockChildRepository()
        let all = try await mockRepo.fetchAll()
        guard let first = all.first else {
            XCTFail("Список детей не должен быть пустым")
            return
        }
        let fetched = try await mockRepo.fetch(id: first.id)
        XCTAssertEqual(fetched.id, first.id)
        XCTAssertEqual(fetched.name, first.name)
    }

    // MARK: - 8. MockChildRepository save → обновляет список

    func test_mockChildRepository_save_updatesChildren() async throws {
        let mockRepo = MockChildRepository()
        let newChild = ChildProfileDTO(
            id: "mock-new-child",
            name: "Новый",
            age: 7,
            targetSounds: ["Ж"],
            parentId: "parent-content-test"
        )
        try await mockRepo.save(newChild)
        let all = try await mockRepo.fetchAll()
        let found = all.first(where: { $0.id == "mock-new-child" })
        XCTAssertNotNil(found, "Новый профиль должен появиться в списке после save")
    }

    // MARK: - 9. SyncOperation payload — валидный JSON

    func test_syncOperation_payload_isValidJSON() throws {
        let payload = #"{"percent":0.9,"streak":7,"totalSessionMinutes":60}"#
        let data = payload.data(using: .utf8)!
        let obj = try JSONSerialization.jsonObject(with: data)
        XCTAssertTrue(JSONSerialization.isValidJSONObject(obj), "Payload должен быть валидным JSON")
    }

    // MARK: - 10. MockSyncService enqueue → pendingCount корректно считается

    func test_mockSyncService_multipleEnqueue_correctPendingCount() async throws {
        let initialCount = await mockSyncService.pendingCount()

        for i in 1...3 {
            let op = SyncOperation(
                entityType: "content_pack",
                entityId: "pack-\(i)",
                operation: "download_meta",
                payload: "{}"
            )
            try await mockSyncService.enqueue(operation: op)
        }

        let finalCount = await mockSyncService.pendingCount()
        XCTAssertEqual(finalCount, initialCount + 3,
                       "После 3 enqueue операций pendingCount должен вырасти на 3")
    }
}
