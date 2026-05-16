@testable import HappySpeech
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
