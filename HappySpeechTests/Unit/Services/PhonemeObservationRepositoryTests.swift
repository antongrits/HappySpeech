@testable import HappySpeech
import RealmSwift
import XCTest

// MARK: - PhonemeObservationRepositoryTests
// ==================================================================================
// Realm-тесты LivePhonemeObservationRepository (v17 «Фонемный паспорт»).
// Каждый тест — изолированная in-memory Realm (как в SyncServiceTests):
//   • save → fetch (round-trip всех полей, включая competitor? = nil)
//   • fetch(childId:) фильтрует чужих детей и сортирует по дате
//   • fetch(childId:phoneme:) фильтрует по фонеме
//   • LivePhonemeProfileService поверх Realm-репозитория: record → profile
// ==================================================================================

final class PhonemeObservationRepositoryTests: XCTestCase {

    /// Изолированная in-memory Realm v17. Устанавливает defaultConfiguration в тот
    /// же identifier, чтобы async `Realm(actor:)`-хелперы видели те же данные.
    private func makeRealmActor() async throws -> RealmActor {
        let memId = "phoneme-obs-\(UUID().uuidString)"
        var config = Realm.Configuration()
        config.inMemoryIdentifier = memId
        config.schemaVersion = RealmSchemaVersion.current
        Realm.Configuration.defaultConfiguration = config
        let actor = RealmActor()
        try await actor.open(configuration: config)
        return actor
    }

    private func obs(
        id: String = UUID().uuidString,
        childId: String = "child-1",
        phoneme: String = "r",
        position: String = "initial",
        gop: Double = 0.4,
        defect: String = "ok",
        competitor: String? = nil,
        daysAgo: Int = 0
    ) -> PhonemeObservationDTO {
        let date = Date().addingTimeInterval(TimeInterval(-daysAgo * 86_400))
        return PhonemeObservationDTO(
            id: id, childId: childId, phoneme: phoneme, wordId: "word_x",
            position: position, gop: gop, posterior: 0.5,
            defect: defect, competitor: competitor, date: date
        )
    }

    // MARK: save → fetch round-trip

    func test_save_thenFetch_roundTripsAllFields() async throws {
        let actor = try await makeRealmActor()
        let repo = LivePhonemeObservationRepository(realmActor: actor)
        let input = obs(
            id: "obs-1", childId: "c1", phoneme: "ʂ", position: "medial",
            gop: 0.63, defect: "substitution", competitor: "s"
        )
        try await repo.save(input)

        let fetched = try await repo.fetch(childId: "c1")
        XCTAssertEqual(fetched.count, 1)
        let out = try XCTUnwrap(fetched.first)
        XCTAssertEqual(out.id, "obs-1")
        XCTAssertEqual(out.phoneme, "ʂ")
        XCTAssertEqual(out.position, "medial")
        XCTAssertEqual(out.gop, 0.63, accuracy: 1e-9)
        XCTAssertEqual(out.defect, "substitution")
        XCTAssertEqual(out.competitor, "s")
    }

    func test_save_nilCompetitor_roundTripsAsNil() async throws {
        let actor = try await makeRealmActor()
        let repo = LivePhonemeObservationRepository(realmActor: actor)
        try await repo.save(obs(id: "obs-nil", childId: "c1", competitor: nil))
        let fetched = try await repo.fetch(childId: "c1")
        XCTAssertNil(fetched.first?.competitor)
    }

    func test_save_sameId_isIdempotentUpsert() async throws {
        let actor = try await makeRealmActor()
        let repo = LivePhonemeObservationRepository(realmActor: actor)
        try await repo.save(obs(id: "dup", childId: "c1", gop: 0.2))
        try await repo.save(obs(id: "dup", childId: "c1", gop: 0.8))
        let fetched = try await repo.fetch(childId: "c1")
        XCTAssertEqual(fetched.count, 1)
        let gop = try XCTUnwrap(fetched.first?.gop)
        XCTAssertEqual(gop, 0.8, accuracy: 1e-9)
    }

    // MARK: fetch фильтрация и сортировка

    func test_fetch_filtersByChildId() async throws {
        let actor = try await makeRealmActor()
        let repo = LivePhonemeObservationRepository(realmActor: actor)
        try await repo.save(obs(id: "a", childId: "c1"))
        try await repo.save(obs(id: "b", childId: "c2"))
        try await repo.save(obs(id: "c", childId: "c1"))

        let c1 = try await repo.fetch(childId: "c1")
        XCTAssertEqual(c1.count, 2)
        XCTAssertTrue(c1.allSatisfy { $0.childId == "c1" })
    }

    func test_fetch_sortsByDateAscending() async throws {
        let actor = try await makeRealmActor()
        let repo = LivePhonemeObservationRepository(realmActor: actor)
        try await repo.save(obs(id: "newest", childId: "c1", daysAgo: 0))
        try await repo.save(obs(id: "oldest", childId: "c1", daysAgo: 10))
        try await repo.save(obs(id: "mid", childId: "c1", daysAgo: 5))

        let fetched = try await repo.fetch(childId: "c1")
        XCTAssertEqual(fetched.map(\.id), ["oldest", "mid", "newest"])
    }

    func test_fetchByPhoneme_filtersCorrectly() async throws {
        let actor = try await makeRealmActor()
        let repo = LivePhonemeObservationRepository(realmActor: actor)
        try await repo.save(obs(id: "r1", childId: "c1", phoneme: "r"))
        try await repo.save(obs(id: "s1", childId: "c1", phoneme: "s"))
        try await repo.save(obs(id: "r2", childId: "c1", phoneme: "r"))

        let onlyR = try await repo.fetch(childId: "c1", phoneme: "r")
        XCTAssertEqual(onlyR.count, 2)
        XCTAssertTrue(onlyR.allSatisfy { $0.phoneme == "r" })
    }

    func test_fetch_emptyForUnknownChild_returnsEmpty() async throws {
        let actor = try await makeRealmActor()
        let repo = LivePhonemeObservationRepository(realmActor: actor)
        try await repo.save(obs(childId: "c1"))
        let fetched = try await repo.fetch(childId: "ghost")
        XCTAssertTrue(fetched.isEmpty)
    }

    // MARK: Live-сервис поверх Realm-репозитория

    func test_liveService_recordThenProfile_overRealm() async throws {
        let actor = try await makeRealmActor()
        let repo = LivePhonemeObservationRepository(realmActor: actor)
        let sut = LivePhonemeProfileService(repository: repo)

        try await sut.record(
            childId: "c1", phoneme: "r", wordId: "word_ruka",
            position: .initial, gop: 0.3, posterior: 0.5,
            defect: "substitution", competitor: "l"
        )
        try await sut.record(
            childId: "c1", phoneme: "s", wordId: "word_sok",
            position: .initial, gop: 0.9, posterior: 0.8,
            defect: "ok", competitor: nil
        )

        let profile = try await sut.profile(childId: "c1")
        XCTAssertEqual(profile.totalObservations, 2)
        XCTAssertEqual(profile.cells.count, 2)
        // r слабее s → r первая в топ-проблемах.
        XCTAssertEqual(profile.topProblems.first?.phoneme, "r")
    }
}
