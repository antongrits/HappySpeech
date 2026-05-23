@testable import HappySpeech
import XCTest

// MARK: - SoundOfTheDayInteractorTests

@MainActor
final class SoundOfTheDayInteractorTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: SoundOfTheDayDisplayLogic {
        var lastVM: SoundOfTheDayModels.LoadToday.ViewModel?

        func displayLoadToday(viewModel: SoundOfTheDayModels.LoadToday.ViewModel) async {
            lastVM = viewModel
        }
    }

    private var display: DisplaySpy!
    private var childRepo: SpyChildRepository!
    private var planner: SpyAdaptivePlannerService!

    override func setUp() {
        super.setUp()
        display = DisplaySpy()
        childRepo = SpyChildRepository(children: [TestDataBuilder.childProfile(id: "child-1", name: "Миша", currentStreak: 4)])
        planner = SpyAdaptivePlannerService()
    }

    override func tearDown() {
        display = nil
        childRepo = nil
        planner = nil
        super.tearDown()
    }

    private func makeSUT(childId: String = "child-1") -> SoundOfTheDayInteractor {
        let router = SoundOfTheDayRouter() // coordinator = nil → noops
        let presenter = SoundOfTheDayPresenter(displayLogic: display)
        return SoundOfTheDayInteractor(
            presenter: presenter,
            router: router,
            adaptivePlannerService: planner,
            childRepository: childRepo,
            childId: childId
        )
    }

    // MARK: - loadToday

    func test_loadToday_callsDisplay() async {
        let sut = makeSUT()
        await sut.loadToday(.init(childId: "child-1"))
        XCTAssertNotNil(display.lastVM)
    }

    func test_loadToday_greetingContainsChildName() async {
        let sut = makeSUT()
        await sut.loadToday(.init(childId: "child-1"))
        XCTAssertTrue(display.lastVM?.greeting.contains("Миша") ?? false)
    }

    func test_loadToday_heroTitleContainsPlannerSound() async {
        // Planner returns "Р" by default in SpyAdaptivePlannerService.
        let sut = makeSUT()
        await sut.loadToday(.init(childId: "child-1"))
        XCTAssertTrue(display.lastVM?.heroTitle.contains("Р") ?? false)
    }

    func test_loadToday_plannerFails_fallsBackToR() async {
        planner.shouldFail = true
        let sut = makeSUT()
        await sut.loadToday(.init(childId: "child-1"))
        XCTAssertTrue(display.lastVM?.heroTitle.contains("Р") ?? false)
    }

    func test_loadToday_childNotFound_greetingIsAnonymous() async {
        // childId that doesn't exist in repo → fetch throws → name == ""
        let sut = makeSUT(childId: "unknown-child")
        await sut.loadToday(.init(childId: "unknown-child"))
        // greeting should still be non-empty (anonymous variant)
        XCTAssertFalse(display.lastVM?.greeting.isEmpty ?? true)
    }

    func test_loadToday_streakProgressComputedFromRepo() async {
        // SpyChildRepository childProfile has currentStreak: 4 (set in setUp)
        let sut = makeSUT()
        await sut.loadToday(.init(childId: "child-1"))
        // progress = min(1.0, 4/7) ≈ 0.571
        let progress = display.lastVM?.streakProgress ?? 0
        XCTAssertGreaterThan(progress, 0)
        XCTAssertLessThanOrEqual(progress, 1.0)
    }

    func test_loadToday_activitiesIncludesAllActivityCards() async {
        let sut = makeSUT()
        await sut.loadToday(.init(childId: "child-1"))
        XCTAssertEqual(display.lastVM?.activities.count, ActivityCard.all.count)
    }

    func test_loadToday_subtitleIsNonEmpty() async {
        let sut = makeSUT()
        await sut.loadToday(.init(childId: "child-1"))
        XCTAssertFalse(display.lastVM?.subtitle.isEmpty ?? true)
    }

    // MARK: - selectActivity + startDay

    func test_selectActivity_doesNotCrashWithNilCoordinator() {
        let sut = makeSUT()
        sut.selectActivity(.init(activity: .listen))
        XCTAssertTrue(true)
    }

    func test_startDay_doesNotCrashWithNilCoordinator() {
        let sut = makeSUT()
        sut.startDay()
        XCTAssertTrue(true)
    }
}
