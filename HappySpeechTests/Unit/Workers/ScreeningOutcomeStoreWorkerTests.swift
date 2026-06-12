@testable import HappySpeech
import RealmSwift
import XCTest

// MARK: - ScreeningOutcomeStoreWorkerTests
//
// Round-trip покрытие live-реализации ScreeningOutcomeStoreWorker через
// изолированный in-memory RealmActor — без обращения к диску.
// Паттерн: как в DiaryStorageWorkerLiveTests / SyncServiceTests.

final class ScreeningOutcomeStoreWorkerTests: XCTestCase {

    private var realmActor: RealmActor!
    private var sut: ScreeningOutcomeStoreWorker!

    override func setUp() async throws {
        try await super.setUp()
        var config = Realm.Configuration()
        config.inMemoryIdentifier = "screening-store-\(UUID().uuidString)"
        config.schemaVersion = RealmSchemaVersion.current
        Realm.Configuration.defaultConfiguration = config
        realmActor = RealmActor()
        try await realmActor.open(configuration: config)
        sut = ScreeningOutcomeStoreWorker(realmActor: realmActor)
    }

    override func tearDown() {
        sut = nil
        realmActor = nil
        super.tearDown()
    }

    private func draft(
        childId: String,
        severity: String = "mild",
        problematicSounds: [String] = [],
        recommendedPacks: [String] = [],
        notes: String = "",
        perSoundJSON: String = "",
        screeningVersion: Int = 2
    ) -> ScreeningOutcomeDraft {
        ScreeningOutcomeDraft(
            childId: childId,
            severity: severity,
            problematicSounds: problematicSounds,
            recommendedPacks: recommendedPacks,
            notes: notes,
            perSoundJSON: perSoundJSON,
            screeningVersion: screeningVersion
        )
    }

    // MARK: - save → fetchLatest round-trip

    func test_saveOutcome_thenFetchLatest_returnsPersistedFields() async {
        await sut.saveOutcome(draft(
            childId: "child-rt",
            severity: "moderate",
            problematicSounds: ["Р", "Ш"],
            recommendedPacks: ["sound_r_pack"],
            notes: "комментарий",
            perSoundJSON: "{\"Р\":0.3,\"Ш\":0.4}",
            screeningVersion: 2
        ))

        let latest = await sut.fetchLatest(childId: "child-rt")
        XCTAssertNotNil(latest)
        XCTAssertEqual(latest?.childId, "child-rt")
        XCTAssertEqual(latest?.overallSeverity, "moderate")
        XCTAssertEqual(latest?.problematicSounds, ["Р", "Ш"])
        XCTAssertEqual(latest?.screeningVersion, 2)
        // perSoundJSON префиксуется в notes как "scores:<json>;".
        XCTAssertEqual(latest?.notes, "scores:{\"Р\":0.3,\"Ш\":0.4};комментарий")
    }

    func test_saveOutcome_emptyPerSoundJSON_doesNotPrefixNotes() async {
        await sut.saveOutcome(draft(
            childId: "child-empty",
            notes: "только заметка"
        ))

        let latest = await sut.fetchLatest(childId: "child-empty")
        XCTAssertEqual(latest?.notes, "только заметка")
    }

    func test_fetchLatest_unknownChild_returnsNil() async {
        let latest = await sut.fetchLatest(childId: "no-such-child")
        XCTAssertNil(latest)
    }

    func test_fetchLatest_returnsMostRecentByCompletedAt() async {
        // Две записи разных детей не пересекаются; для одного ребёнка fetchLatest
        // отдаёт запись с наибольшим completedAt. Запись пишет completedAt = Date(),
        // поэтому пишем последовательно: вторая запись новее первой.
        await sut.saveOutcome(draft(
            childId: "child-multi",
            severity: "mild",
            problematicSounds: ["С"],
            notes: "первая",
            screeningVersion: 1
        ))
        // Небольшая пауза гарантирует более поздний completedAt у второй записи.
        try? await Task.sleep(nanoseconds: 20_000_000)
        await sut.saveOutcome(draft(
            childId: "child-multi",
            severity: "severe",
            problematicSounds: ["Р", "Л"],
            notes: "вторая"
        ))

        let latest = await sut.fetchLatest(childId: "child-multi")
        XCTAssertEqual(latest?.overallSeverity, "severe")
        XCTAssertEqual(latest?.notes, "вторая")
        XCTAssertEqual(latest?.problematicSounds, ["Р", "Л"])
    }

    func test_fetchLatest_filtersByChildId() async {
        await sut.saveOutcome(draft(
            childId: "child-A",
            severity: "mild",
            problematicSounds: ["С"]
        ))
        await sut.saveOutcome(draft(
            childId: "child-B",
            severity: "severe",
            problematicSounds: ["Р"]
        ))

        let latestA = await sut.fetchLatest(childId: "child-A")
        XCTAssertEqual(latestA?.overallSeverity, "mild")
        XCTAssertEqual(latestA?.problematicSounds, ["С"])
    }
}
