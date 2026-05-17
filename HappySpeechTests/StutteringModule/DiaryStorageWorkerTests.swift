@testable import HappySpeech
import RealmSwift
import XCTest

// MARK: - DiaryStorageWorkerTests
//
// Покрывает: saveSession, fetchSessions через MockDiaryStorageWorker.
// DiaryStorageWorker (live) требует RealmActor — hardware side.
// Тестируем через протокол DiaryStorageWorkerProtocol и mock из StutteringWorkerTests.
// Дополнительно: тесты логики сортировки и лимита через mock.

// MARK: - InMemoryDiaryStorageWorker (чистый mock без Realm)

private actor InMemoryDiaryStorageWorker: DiaryStorageWorkerProtocol {

    private var store: [FluencySessionData] = []

    func saveSession(_ data: FluencySessionData) async {
        store.removeAll { $0.id == data.id }
        store.append(data)
    }

    func fetchSessions(limit: Int) async -> [FluencySessionData] {
        let sorted = store.sorted { $0.date > $1.date }
        return limit > 0 ? Array(sorted.prefix(limit)) : sorted
    }
}

// MARK: - DiaryStorageWorkerTests (через протокол)

final class DiaryStorageWorkerProtocolTests: XCTestCase {

    private var sut: InMemoryDiaryStorageWorker!

    override func setUp() {
        super.setUp()
        sut = InMemoryDiaryStorageWorker()
    }

    // MARK: - saveSession

    func test_saveSession_storesSingleSession() async {
        let session = TestDataBuilder.fluencySession(id: "diary-001")
        await sut.saveSession(session)
        let result = await sut.fetchSessions(limit: 0)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, "diary-001")
    }

    func test_saveSession_upsertsByIdWhenSameId() async {
        let original = TestDataBuilder.fluencySession(id: "diary-dup", dysfluencyCount: 1)
        let updated = TestDataBuilder.fluencySession(id: "diary-dup", dysfluencyCount: 5)

        await sut.saveSession(original)
        await sut.saveSession(updated)

        let result = await sut.fetchSessions(limit: 0)
        XCTAssertEqual(result.count, 1, "Одинаковый id — апдейт, не дубль")
        XCTAssertEqual(result.first?.dysfluencyCount, 5)
    }

    func test_saveSession_storesMultipleSessions() async {
        await sut.saveSession(TestDataBuilder.fluencySession(id: "d-1"))
        await sut.saveSession(TestDataBuilder.fluencySession(id: "d-2"))
        await sut.saveSession(TestDataBuilder.fluencySession(id: "d-3"))

        let result = await sut.fetchSessions(limit: 0)
        XCTAssertEqual(result.count, 3)
    }

    // MARK: - fetchSessions: сортировка

    func test_fetchSessions_returnedSortedByDateDesc() async {
        let old = TestDataBuilder.fluencySession(id: "old", date: Date(timeIntervalSince1970: 1000))
        let recent = TestDataBuilder.fluencySession(id: "recent", date: Date(timeIntervalSince1970: 9000))

        await sut.saveSession(old)
        await sut.saveSession(recent)

        let result = await sut.fetchSessions(limit: 0)
        XCTAssertEqual(result.first?.id, "recent", "Более новая сессия должна идти первой")
        XCTAssertEqual(result.last?.id, "old")
    }

    // MARK: - fetchSessions: лимит

    func test_fetchSessions_limit1_returnsOnlyMostRecent() async {
        let old = TestDataBuilder.fluencySession(id: "old", date: Date(timeIntervalSince1970: 1))
        let recent = TestDataBuilder.fluencySession(id: "recent", date: Date(timeIntervalSince1970: 9999))

        await sut.saveSession(old)
        await sut.saveSession(recent)

        let result = await sut.fetchSessions(limit: 1)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, "recent")
    }

    func test_fetchSessions_limitZero_returnsAll() async {
        await sut.saveSession(TestDataBuilder.fluencySession(id: "a"))
        await sut.saveSession(TestDataBuilder.fluencySession(id: "b"))
        await sut.saveSession(TestDataBuilder.fluencySession(id: "c"))

        let result = await sut.fetchSessions(limit: 0)
        XCTAssertEqual(result.count, 3)
    }

    func test_fetchSessions_limitExceedsCount_returnsAll() async {
        await sut.saveSession(TestDataBuilder.fluencySession(id: "x"))

        let result = await sut.fetchSessions(limit: 100)
        XCTAssertEqual(result.count, 1,
                       "Лимит больше размера коллекции — вернуть всё")
    }

    // MARK: - Пустое хранилище

    func test_fetchSessions_returnsEmptyWhenNothingSaved() async {
        let result = await sut.fetchSessions(limit: 10)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - FluencySessionData поля

    func test_saveSession_preservesAllFields() async {
        let date = Date(timeIntervalSince1970: 5000)
        let session = FluencySessionData(
            id: "full-001",
            date: date,
            dysfluencyCount: 3,
            totalSyllables: 50,
            rate: 6.0,
            transcript: "мама мама"
        )

        await sut.saveSession(session)
        let result = await sut.fetchSessions(limit: 1)

        guard let saved = result.first else {
            XCTFail("Должна вернуться сохранённая сессия"); return
        }
        XCTAssertEqual(saved.id, "full-001")
        XCTAssertEqual(saved.dysfluencyCount, 3)
        XCTAssertEqual(saved.totalSyllables, 50)
        XCTAssertEqual(saved.rate, 6.0, accuracy: 0.001)
        XCTAssertEqual(saved.transcript, "мама мама")
        XCTAssertEqual(saved.date.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 1)
    }
}

// MARK: - DiaryStorageWorkerLiveTests (реальный DiaryStorageWorker + in-memory Realm)
//
// Покрывает live-реализацию DiaryStorageWorker через изолированный in-memory
// RealmActor — без обращения к диску.

final class DiaryStorageWorkerLiveTests: XCTestCase {

    private var realmActor: RealmActor!
    private var sut: DiaryStorageWorker!

    override func setUp() async throws {
        try await super.setUp()
        var config = Realm.Configuration()
        config.inMemoryIdentifier = "diary-live-\(UUID().uuidString)"
        config.schemaVersion = RealmSchemaVersion.current
        Realm.Configuration.defaultConfiguration = config
        realmActor = RealmActor()
        try await realmActor.open(configuration: config)
        sut = DiaryStorageWorker(realmActor: realmActor)
    }

    override func tearDown() {
        sut = nil
        realmActor = nil
        super.tearDown()
    }

    // MARK: - saveSession / fetchSessions

    func test_saveSession_thenFetch_returnsSession() async {
        let session = FluencySessionData(
            id: "live-001",
            date: Date(timeIntervalSince1970: 2000),
            dysfluencyCount: 2,
            totalSyllables: 40,
            rate: 5.0,
            transcript: "тест"
        )
        await sut.saveSession(session)
        let result = await sut.fetchSessions(limit: 0)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, "live-001")
        XCTAssertEqual(result.first?.dysfluencyCount, 2)
    }

    func test_saveSession_sameId_upserts() async {
        let first = FluencySessionData(
            id: "live-dup", date: Date(), dysfluencyCount: 1,
            totalSyllables: 10, rate: 1, transcript: "a"
        )
        let second = FluencySessionData(
            id: "live-dup", date: Date(), dysfluencyCount: 9,
            totalSyllables: 90, rate: 9, transcript: "b"
        )
        await sut.saveSession(first)
        await sut.saveSession(second)
        let result = await sut.fetchSessions(limit: 0)
        XCTAssertEqual(result.count, 1, "Одинаковый id → апдейт")
        XCTAssertEqual(result.first?.dysfluencyCount, 9)
    }

    func test_fetchSessions_sortedByDateDescending() async {
        await sut.saveSession(FluencySessionData(
            id: "old", date: Date(timeIntervalSince1970: 100),
            dysfluencyCount: 0, totalSyllables: 1, rate: 0, transcript: ""
        ))
        await sut.saveSession(FluencySessionData(
            id: "new", date: Date(timeIntervalSince1970: 9000),
            dysfluencyCount: 0, totalSyllables: 1, rate: 0, transcript: ""
        ))
        let result = await sut.fetchSessions(limit: 0)
        XCTAssertEqual(result.first?.id, "new")
    }

    func test_fetchSessions_limitApplied() async {
        for index in 0..<5 {
            await sut.saveSession(FluencySessionData(
                id: "s-\(index)",
                date: Date(timeIntervalSince1970: TimeInterval(index * 100)),
                dysfluencyCount: 0, totalSyllables: 1, rate: 0, transcript: ""
            ))
        }
        let result = await sut.fetchSessions(limit: 2)
        XCTAssertEqual(result.count, 2)
    }

    func test_fetchSessions_emptyStorage_returnsEmpty() async {
        let result = await sut.fetchSessions(limit: 10)
        XCTAssertTrue(result.isEmpty)
    }
}
