@testable import HappySpeech
import RealmSwift
import XCTest

// MARK: - FamilyRecordingStoreWorkerTests
//
// Round-trip покрытие live-реализации FamilyRecordingStoreWorker через
// изолированный in-memory RealmActor — без обращения к диску.
// Паттерн: как в DiaryStorageWorkerLiveTests.

final class FamilyRecordingStoreWorkerTests: XCTestCase {

    private var realmActor: RealmActor!
    private var sut: FamilyRecordingStoreWorker!

    override func setUp() async throws {
        try await super.setUp()
        var config = Realm.Configuration()
        config.inMemoryIdentifier = "family-store-\(UUID().uuidString)"
        config.schemaVersion = RealmSchemaVersion.current
        Realm.Configuration.defaultConfiguration = config
        realmActor = RealmActor()
        try await realmActor.open(configuration: config)
        sut = FamilyRecordingStoreWorker(realmActor: realmActor)
    }

    override func tearDown() {
        sut = nil
        realmActor = nil
        super.tearDown()
    }

    private func makeDTO(
        id: String = UUID().uuidString,
        word: String = "мяч",
        parentId: String = "parent-test"
    ) -> RecordingDTO {
        RecordingDTO(
            id: id,
            word: word,
            audioFilePath: "family_recordings/\(id).m4a",
            recordedAt: Date(),
            durationSeconds: 2.5,
            parentProfileId: parentId
        )
    }

    // MARK: - save → fetchAll round-trip

    func test_save_thenFetchAll_returnsStoredDTO() async {
        let dto = makeDTO(id: "fv-rt-1", word: "мяч")
        await sut.save(dto, replacingId: nil)

        let all = await sut.fetchAll(parentId: "parent-test")
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, "fv-rt-1")
        XCTAssertEqual(all.first?.word, "мяч")
        XCTAssertEqual(all.first?.audioFilePath, "family_recordings/fv-rt-1.m4a")
        XCTAssertEqual(all.first?.durationSeconds ?? 0, 2.5, accuracy: 0.001)
    }

    func test_save_replacingId_removesOld() async {
        let old = makeDTO(id: "old-rec", word: "мяч")
        await sut.save(old, replacingId: nil)

        let new = makeDTO(id: "new-rec", word: "мяч")
        await sut.save(new, replacingId: "old-rec")

        let all = await sut.fetchAll(parentId: "parent-test")
        XCTAssertEqual(all.count, 1, "replacingId должен удалить старую запись")
        XCTAssertEqual(all.first?.id, "new-rec")
    }

    func test_delete_removesRecord() async {
        let dto = makeDTO(id: "del-fv", word: "собака")
        await sut.save(dto, replacingId: nil)

        await sut.delete(id: "del-fv")
        let all = await sut.fetchAll(parentId: "parent-test")
        XCTAssertTrue(all.isEmpty)
    }

    func test_delete_unknownId_isNoOp() async {
        let dto = makeDTO(id: "keep", word: "мяч")
        await sut.save(dto, replacingId: nil)

        await sut.delete(id: "nonexistent")
        let all = await sut.fetchAll(parentId: "parent-test")
        XCTAssertEqual(all.count, 1, "Удаление несуществующего id не трогает другие записи")
    }

    func test_fetchAll_filtersByParentId() async {
        await sut.save(makeDTO(id: "a1", parentId: "parent-A"), replacingId: nil)
        await sut.save(makeDTO(id: "b1", parentId: "parent-B"), replacingId: nil)

        let onlyA = await sut.fetchAll(parentId: "parent-A")
        XCTAssertEqual(onlyA.count, 1)
        XCTAssertEqual(onlyA.first?.id, "a1")
    }

    func test_fetchAll_emptyStore_returnsEmpty() async {
        let all = await sut.fetchAll(parentId: "nobody")
        XCTAssertTrue(all.isEmpty)
    }
}
