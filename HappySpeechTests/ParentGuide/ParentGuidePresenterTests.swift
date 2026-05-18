@testable import HappySpeech
import XCTest

// MARK: - Spy DisplayLogic

@MainActor
private final class SpyParentGuideDisplay: ParentGuideDisplayLogic, @unchecked Sendable {
    var loadVM: ParentGuideModels.Load.ViewModel?
    var markReadVM: ParentGuideModels.MarkRead.ViewModel?
    var toggleFavoriteVM: ParentGuideModels.ToggleFavorite.ViewModel?

    func displayLoad(viewModel: ParentGuideModels.Load.ViewModel) async {
        loadVM = viewModel
    }
    func displayMarkRead(viewModel: ParentGuideModels.MarkRead.ViewModel) async {
        markReadVM = viewModel
    }
    func displayToggleFavorite(viewModel: ParentGuideModels.ToggleFavorite.ViewModel) async {
        toggleFavoriteVM = viewModel
    }
}

// MARK: - Presenter Tests

@MainActor
final class ParentGuidePresenterTests: XCTestCase {

    private func makeSUT() -> (ParentGuidePresenter, SpyParentGuideDisplay) {
        let display = SpyParentGuideDisplay()
        let sut = ParentGuidePresenter(displayLogic: display)
        return (sut, display)
    }

    private func makeResponse(
        soundGroups: [String] = [],
        read: Set<String> = [],
        favorites: Set<String> = []
    ) -> ParentGuideModels.Load.Response {
        .init(
            lessons: ParentGuideCorpus.lessons,
            childSoundGroups: soundGroups,
            readLessonIds: read,
            favoriteLessonIds: favorites
        )
    }

    func test_presentLoad_groupsLessonsByTopic() async {
        let (sut, display) = makeSUT()
        await sut.presentLoad(response: makeResponse())
        XCTAssertEqual(display.loadVM?.topics.count, GuideTopic.allCases.count)
    }

    func test_presentLoad_marksRecommendedBySoundGroup() async {
        let (sut, display) = makeSUT()
        await sut.presentLoad(response: makeResponse(soundGroups: ["sonants"]))
        let allLessons = display.loadVM?.topics.flatMap { $0.lessons } ?? []
        let recommended = allLessons.filter { $0.isRecommended }
        XCTAssertFalse(recommended.isEmpty, "Sonants child should see recommended lessons")
    }

    func test_presentLoad_noSoundGroups_noRecommendedLessons() async {
        let (sut, display) = makeSUT()
        await sut.presentLoad(response: makeResponse(soundGroups: []))
        let allLessons = display.loadVM?.topics.flatMap { $0.lessons } ?? []
        XCTAssertTrue(allLessons.allSatisfy { !$0.isRecommended })
    }

    func test_presentLoad_marksReadLessons() async {
        let (sut, display) = makeSUT()
        let readId = ParentGuideCorpus.lessons[0].id
        await sut.presentLoad(response: makeResponse(read: [readId]))
        let allLessons = display.loadVM?.topics.flatMap { $0.lessons } ?? []
        let readLesson = allLessons.first { $0.id == readId }
        XCTAssertEqual(readLesson?.isRead, true)
    }

    func test_presentLoad_picksTipOfDay() async {
        let (sut, display) = makeSUT()
        await sut.presentLoad(response: makeResponse())
        XCTAssertNotNil(display.loadVM?.tipOfDay)
    }

    func test_presentLoad_tipOfDay_prefersRecommendedUnread() async {
        let (sut, display) = makeSUT()
        await sut.presentLoad(response: makeResponse(soundGroups: ["sonants"]))
        XCTAssertEqual(display.loadVM?.tipOfDay?.isRecommended, true)
    }

    func test_presentMarkRead_forwardsViewModel() async {
        let (sut, display) = makeSUT()
        await sut.presentMarkRead(response: .init(lessonId: "x", isRead: true))
        XCTAssertEqual(display.markReadVM?.lessonId, "x")
        XCTAssertEqual(display.markReadVM?.isRead, true)
    }

    func test_presentToggleFavorite_forwardsViewModel() async {
        let (sut, display) = makeSUT()
        await sut.presentToggleFavorite(response: .init(lessonId: "y", isFavorite: true))
        XCTAssertEqual(display.toggleFavoriteVM?.lessonId, "y")
        XCTAssertEqual(display.toggleFavoriteVM?.isFavorite, true)
    }
}
