@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubParentGuideWorker: ParentGuideWorkerProtocol {
    var lessons: [GuideLesson] = ParentGuideCorpus.lessons
    var soundGroups: [String] = []
    var read: Set<String> = []
    var favorites: Set<String> = []
    private(set) var markReadCalls: [String] = []
    private(set) var toggleFavoriteCalls: [String] = []

    func loadLessons() async -> [GuideLesson] { lessons }
    func childSoundGroups(childId: String) async -> [String] { soundGroups }
    func readLessonIds() -> Set<String> { read }
    func favoriteLessonIds() -> Set<String> { favorites }
    func markRead(_ lessonId: String) {
        markReadCalls.append(lessonId)
        read.insert(lessonId)
    }
    func toggleFavorite(_ lessonId: String) -> Bool {
        toggleFavoriteCalls.append(lessonId)
        if favorites.contains(lessonId) {
            favorites.remove(lessonId)
            return false
        }
        favorites.insert(lessonId)
        return true
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyParentGuidePresenter: ParentGuidePresentationLogic, @unchecked Sendable {
    var loadCount = 0
    var markReadCount = 0
    var toggleFavoriteCount = 0
    var lastResponse: ParentGuideModels.Load.Response?
    var lastToggle: ParentGuideModels.ToggleFavorite.Response?

    func presentLoad(response: ParentGuideModels.Load.Response) async {
        loadCount += 1
        lastResponse = response
    }
    func presentMarkRead(response: ParentGuideModels.MarkRead.Response) async {
        markReadCount += 1
    }
    func presentToggleFavorite(response: ParentGuideModels.ToggleFavorite.Response) async {
        toggleFavoriteCount += 1
        lastToggle = response
    }
}

// MARK: - Interactor Tests

@MainActor
final class ParentGuideInteractorTests: XCTestCase {

    private func makeSUT() -> (ParentGuideInteractor, SpyParentGuidePresenter, StubParentGuideWorker, SpyHapticService) {
        let worker = StubParentGuideWorker()
        let haptic = SpyHapticService()
        let sut = ParentGuideInteractor(childId: "child-1", worker: worker, hapticService: haptic)
        let spy = SpyParentGuidePresenter()
        sut.presenter = spy
        return (sut, spy, worker, haptic)
    }

    func test_load_presentsCorpusLessons() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.load(request: .init(childId: "child-1"))
        XCTAssertEqual(spy.loadCount, 1)
        XCTAssertEqual(spy.lastResponse?.lessons.count, ParentGuideCorpus.lessons.count)
    }

    func test_load_passesChildSoundGroups() async {
        let (sut, spy, worker, _) = makeSUT()
        worker.soundGroups = ["sonants"]
        await sut.load(request: .init(childId: "child-1"))
        XCTAssertEqual(spy.lastResponse?.childSoundGroups, ["sonants"])
    }

    func test_markRead_callsWorkerAndPresenter() async {
        let (sut, spy, worker, _) = makeSUT()
        await sut.markRead(request: .init(lessonId: "guide-basics-routine"))
        XCTAssertEqual(worker.markReadCalls, ["guide-basics-routine"])
        XCTAssertEqual(spy.markReadCount, 1)
    }

    func test_toggleFavorite_addsAndPlaysHaptic() async {
        let (sut, spy, worker, haptic) = makeSUT()
        await sut.toggleFavorite(request: .init(lessonId: "guide-basics-routine"))
        XCTAssertEqual(worker.toggleFavoriteCalls, ["guide-basics-routine"])
        XCTAssertEqual(spy.toggleFavoriteCount, 1)
        XCTAssertEqual(spy.lastToggle?.isFavorite, true)
        XCTAssertEqual(haptic.selectionCount, 1)
    }

    func test_toggleFavorite_twice_returnsToUnfavorited() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.toggleFavorite(request: .init(lessonId: "guide-basics-routine"))
        await sut.toggleFavorite(request: .init(lessonId: "guide-basics-routine"))
        XCTAssertEqual(spy.lastToggle?.isFavorite, false)
    }
}

// MARK: - Corpus Tests

final class ParentGuideCorpusTests: XCTestCase {

    func test_corpus_hasLessonsForEveryTopic() {
        for topic in GuideTopic.allCases {
            let count = ParentGuideCorpus.lessons.filter { $0.topic == topic }.count
            XCTAssertGreaterThan(count, 0, "Topic \(topic) has no lessons")
        }
    }

    func test_corpus_lessonIdsAreUnique() {
        let ids = ParentGuideCorpus.lessons.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_soundGroup_mapsKnownSounds() {
        XCTAssertEqual(ParentGuideCorpus.soundGroup(for: "Р"), "sonants")
        XCTAssertEqual(ParentGuideCorpus.soundGroup(for: "С"), "whistling")
        XCTAssertEqual(ParentGuideCorpus.soundGroup(for: "Ш"), "hissing")
        XCTAssertNil(ParentGuideCorpus.soundGroup(for: "А"))
    }

    func test_lessonForId_returnsMatch() {
        XCTAssertNotNil(ParentGuideCorpus.lesson(forId: "guide-basics-routine"))
        XCTAssertNil(ParentGuideCorpus.lesson(forId: "nonexistent"))
    }
}
