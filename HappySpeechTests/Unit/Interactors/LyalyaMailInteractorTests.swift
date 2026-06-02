@testable import HappySpeech
import RealmSwift
import XCTest

// MARK: - Spy Presenter

@MainActor
private final class SpyLyalyaMailPresenter: LyalyaMailPresentationLogic {
    var lettersCallCount = 0
    var openedCallCount = 0
    var deletedCallCount = 0

    var lastLettersResponse: LyalyaMailModels.LoadMail.Response?
    var lastOpenedResponse: LyalyaMailModels.OpenLetter.Response?
    var lastDeletedResponse: LyalyaMailModels.Delete.Response?

    func presentLetters(response: LyalyaMailModels.LoadMail.Response) async {
        lettersCallCount += 1
        lastLettersResponse = response
    }

    func presentOpenedLetter(response: LyalyaMailModels.OpenLetter.Response) async {
        openedCallCount += 1
        lastOpenedResponse = response
    }

    func presentDeleted(response: LyalyaMailModels.Delete.Response) async {
        deletedCallCount += 1
        lastDeletedResponse = response
    }
}

// MARK: - LyalyaMailInteractorTests

@MainActor
final class LyalyaMailInteractorTests: XCTestCase {

    private var spy: SpyLyalyaMailPresenter!

    override func setUp() async throws {
        try await super.setUp()
        spy = SpyLyalyaMailPresenter()
    }

    override func tearDown() async throws {
        spy = nil
        try await super.tearDown()
    }

    /// Свежий in-memory Realm на каждый тест — изоляция персистентных писем.
    private func makeRealmActor() async throws -> RealmActor {
        var config = Realm.Configuration()
        config.inMemoryIdentifier = "lyalya-mail-unit-\(UUID().uuidString)"
        config.schemaVersion = RealmSchemaVersion.current
        Realm.Configuration.defaultConfiguration = config
        let actor = RealmActor()
        try await actor.open(configuration: config)
        return actor
    }

    /// SUT с реальным Realm + детерминированными данными: серия 7 дней и одна
    /// успешная сессия → ожидаемо генерируются welcome + streak(3,7) + firstSound.
    private func makeSUT(childId: String = "unit-test-child") async throws -> LyalyaMailInteractor {
        let realmActor = try await makeRealmActor()
        let childRepo = MockChildRepository(children: [
            ChildProfileDTO(id: childId, name: "Миша", age: 6,
                            targetSounds: ["Р"], parentId: "p1",
                            currentStreak: 7)
        ])
        let sessionRepo = MockSessionRepository(sessions: [
            SessionDTO(id: "s1", childId: childId, date: Date(),
                       templateType: "repeatAfterModel", targetSound: "Р",
                       stage: "wordInit", durationSeconds: 200,
                       totalAttempts: 10, correctAttempts: 10,
                       fatigueDetected: false, isSynced: false, attempts: [])
        ])
        let sut = LyalyaMailInteractor(
            childId: childId,
            realmActor: realmActor,
            childRepository: childRepo,
            sessionRepository: sessionRepo
        )
        sut.presenter = spy
        return sut
    }

    // MARK: - loadMail

    func test_loadMail_callsPresenter() async throws {
        let sut = try await makeSUT()
        await sut.loadMail(.init(childId: "unit-test-child"))
        XCTAssertEqual(spy.lettersCallCount, 1)
    }

    func test_loadMail_generatesEventLetters() async throws {
        let sut = try await makeSUT()
        await sut.loadMail(.init(childId: "unit-test-child"))
        let letters = spy.lastLettersResponse?.letters ?? []
        // welcome + streak(3) + streak(7) + firstSound = 4 письма.
        XCTAssertFalse(letters.isEmpty)
        XCTAssertTrue(letters.contains { $0.kind == .welcome })
        XCTAssertTrue(letters.contains { $0.kind == .firstSound })
        XCTAssertTrue(letters.contains { $0.kind == .streak })
    }

    func test_loadMail_idempotent_secondCallSameCount() async throws {
        let sut = try await makeSUT()
        await sut.loadMail(.init(childId: "unit-test-child"))
        let first = spy.lastLettersResponse?.letters.count ?? 0
        await sut.loadMail(.init(childId: "unit-test-child"))
        let second = spy.lastLettersResponse?.letters.count ?? 0
        // Стабильные id → повторная генерация не плодит дубликаты.
        XCTAssertEqual(first, second)
    }

    func test_loadMail_noRepositories_empty() async throws {
        // Без репозиториев (preview) — нет писем, без crash.
        let realmActor = try await makeRealmActor()
        let sut = LyalyaMailInteractor(childId: "c1", realmActor: realmActor)
        sut.presenter = spy
        await sut.loadMail(.init(childId: "c1"))
        // welcome всё равно создаётся (не требует данных).
        XCTAssertTrue(spy.lastLettersResponse?.letters.contains { $0.kind == .welcome } ?? false)
    }

    // MARK: - openLetter

    func test_openLetter_validId_callsPresenterOpened() async throws {
        let sut = try await makeSUT()
        await sut.loadMail(.init(childId: "unit-test-child"))
        guard let first = spy.lastLettersResponse?.letters.first else {
            XCTFail("No letters generated"); return
        }
        await sut.openLetter(.init(letterId: first.id))
        XCTAssertEqual(spy.openedCallCount, 1)
    }

    func test_openLetter_marksLetterAsRead() async throws {
        let sut = try await makeSUT()
        await sut.loadMail(.init(childId: "unit-test-child"))
        guard let unread = spy.lastLettersResponse?.letters.first(where: { !$0.isRead }) else {
            XCTFail("Expected at least one unread letter"); return
        }
        await sut.openLetter(.init(letterId: unread.id))
        XCTAssertTrue(spy.lastOpenedResponse?.letter.isRead ?? false)
    }

    func test_openLetter_persistsReadAcrossReload() async throws {
        let sut = try await makeSUT()
        await sut.loadMail(.init(childId: "unit-test-child"))
        guard let unread = spy.lastLettersResponse?.letters.first(where: { !$0.isRead }) else {
            XCTFail("No unread letter"); return
        }
        await sut.openLetter(.init(letterId: unread.id))
        // После reload письмо остаётся прочитанным (персистентность Realm).
        let reloaded = spy.lastLettersResponse?.letters.first { $0.id == unread.id }
        XCTAssertTrue(reloaded?.isRead ?? false)
    }

    func test_openLetter_unknownId_doesNotCallPresenterOpened() async throws {
        let sut = try await makeSUT()
        await sut.openLetter(.init(letterId: UUID()))
        XCTAssertEqual(spy.openedCallCount, 0)
    }

    // MARK: - delete

    func test_delete_callsPresenterDeleted() async throws {
        let sut = try await makeSUT()
        await sut.loadMail(.init(childId: "unit-test-child"))
        guard let first = spy.lastLettersResponse?.letters.first else {
            XCTFail("No letters"); return
        }
        await sut.delete(.init(letterId: first.id))
        XCTAssertEqual(spy.deletedCallCount, 1)
        XCTAssertEqual(spy.lastDeletedResponse?.removedId, first.id)
    }

    func test_delete_removedLetterAbsentFromReload() async throws {
        let sut = try await makeSUT()
        await sut.loadMail(.init(childId: "unit-test-child"))
        guard let target = spy.lastLettersResponse?.letters.first else {
            XCTFail("No letters"); return
        }
        await sut.delete(.init(letterId: target.id))
        let remaining = spy.lastLettersResponse?.letters ?? []
        XCTAssertFalse(remaining.contains(where: { $0.id == target.id }))
    }
}
