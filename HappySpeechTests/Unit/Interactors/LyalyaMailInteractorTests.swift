@testable import HappySpeech
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

    override func setUp() {
        super.setUp()
        spy = SpyLyalyaMailPresenter()
    }

    override func tearDown() {
        spy = nil
        super.tearDown()
    }

    private func makeSUT(childId: String = "unit-test-child") -> LyalyaMailInteractor {
        // Each test gets a fresh store to avoid cross-test pollution.
        let store = LyalyaMailStore()
        let sut = LyalyaMailInteractor(childId: childId, store: store)
        sut.presenter = spy
        return sut
    }

    // MARK: - loadMail

    func test_loadMail_callsPresenter() async {
        let sut = makeSUT()
        await sut.loadMail(.init(childId: "unit-test-child"))
        XCTAssertEqual(spy.lettersCallCount, 1)
    }

    func test_loadMail_seedsLettersOnFirstCall() async {
        let sut = makeSUT()
        await sut.loadMail(.init(childId: "unit-test-child"))
        let letters = spy.lastLettersResponse?.letters ?? []
        XCTAssertFalse(letters.isEmpty)
    }

    func test_loadMail_seedsExactlyFiveLetters() async {
        let sut = makeSUT()
        await sut.loadMail(.init(childId: "unit-test-child"))
        XCTAssertEqual(spy.lastLettersResponse?.letters.count, 5)
    }

    func test_loadMail_secondCall_returnsSameCount() async {
        let sut = makeSUT()
        await sut.loadMail(.init(childId: "unit-test-child"))
        let first = spy.lastLettersResponse?.letters.count ?? 0
        await sut.loadMail(.init(childId: "unit-test-child"))
        let second = spy.lastLettersResponse?.letters.count ?? 0
        XCTAssertEqual(first, second)
    }

    // MARK: - openLetter

    func test_openLetter_validId_callsPresenterOpened() async {
        let sut = makeSUT()
        await sut.loadMail(.init(childId: "unit-test-child"))
        let letters = spy.lastLettersResponse?.letters ?? []
        guard let first = letters.first else { XCTFail("No letters seeded"); return }

        await sut.openLetter(.init(letterId: first.id))
        XCTAssertEqual(spy.openedCallCount, 1)
    }

    func test_openLetter_marksLetterAsRead() async {
        let sut = makeSUT()
        await sut.loadMail(.init(childId: "unit-test-child"))
        let letters = spy.lastLettersResponse?.letters ?? []
        guard let unread = letters.first(where: { !$0.isRead }) else {
            XCTFail("Expected at least one unread letter"); return
        }

        await sut.openLetter(.init(letterId: unread.id))
        XCTAssertTrue(spy.lastOpenedResponse?.letter.isRead ?? false)
    }

    func test_openLetter_reloadsMailAfterOpen() async {
        let sut = makeSUT()
        await sut.loadMail(.init(childId: "unit-test-child"))
        let letters = spy.lastLettersResponse?.letters ?? []
        guard let first = letters.first else { XCTFail("No letters"); return }

        let countBefore = spy.lettersCallCount
        await sut.openLetter(.init(letterId: first.id))
        XCTAssertGreaterThan(spy.lettersCallCount, countBefore)
    }

    func test_openLetter_unknownId_doesNotCallPresenterOpened() async {
        let sut = makeSUT()
        await sut.openLetter(.init(letterId: UUID()))
        XCTAssertEqual(spy.openedCallCount, 0)
    }

    // MARK: - delete

    func test_delete_callsPresenterDeleted() async {
        let sut = makeSUT()
        await sut.loadMail(.init(childId: "unit-test-child"))
        let letters = spy.lastLettersResponse?.letters ?? []
        guard let first = letters.first else { XCTFail("No letters"); return }

        await sut.delete(.init(letterId: first.id))
        XCTAssertEqual(spy.deletedCallCount, 1)
        XCTAssertEqual(spy.lastDeletedResponse?.removedId, first.id)
    }

    func test_delete_reducesLetterCount() async {
        let sut = makeSUT()
        await sut.loadMail(.init(childId: "unit-test-child"))
        let countBefore = spy.lastLettersResponse?.letters.count ?? 0
        guard let first = spy.lastLettersResponse?.letters.first else {
            XCTFail("No letters"); return
        }

        await sut.delete(.init(letterId: first.id))
        let countAfter = spy.lastLettersResponse?.letters.count ?? 0
        XCTAssertEqual(countAfter, countBefore - 1)
    }

    func test_delete_removedLetterAbsentFromReload() async {
        let sut = makeSUT()
        await sut.loadMail(.init(childId: "unit-test-child"))
        guard let target = spy.lastLettersResponse?.letters.first else {
            XCTFail("No letters"); return
        }

        await sut.delete(.init(letterId: target.id))
        let remaining = spy.lastLettersResponse?.letters ?? []
        XCTAssertFalse(remaining.contains(where: { $0.id == target.id }))
    }
}
