@testable import HappySpeech
import XCTest

// MARK: - AchievementWallPresenterTests

@MainActor
final class AchievementWallPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: AchievementWallDisplayLogic {
        var lastWallVM: AchievementWallModels.LoadWall.ViewModel?
        var lastDetailVM: AchievementWallModels.OpenDetail.ViewModel?
        var lastShareVM: AchievementWallModels.Share.ViewModel?

        func displayWall(viewModel: AchievementWallModels.LoadWall.ViewModel) async {
            lastWallVM = viewModel
        }

        func displayDetail(viewModel: AchievementWallModels.OpenDetail.ViewModel) async {
            lastDetailVM = viewModel
        }

        func displayShare(viewModel: AchievementWallModels.Share.ViewModel) async {
            lastShareVM = viewModel
        }
    }

    private func makeSUT() -> (AchievementWallPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = AchievementWallPresenter(displayLogic: spy)
        return (presenter, spy)
    }

    private func makeWallEntry(
        achievement: Achievement = .firstSoundMastered,
        unlocked: Bool = false,
        unlockedDate: Date? = nil
    ) -> WallEntry {
        WallEntry(achievement: achievement, unlocked: unlocked, unlockedDate: unlockedDate)
    }

    private func makeWallResponse(
        childName: String = "Маша",
        childAge: Int = 6,
        entries: [WallEntry] = [],
        totalUnlocked: Int = 0
    ) -> AchievementWallModels.LoadWall.Response {
        AchievementWallModels.LoadWall.Response(
            childId: "child-1",
            childName: childName,
            childAge: childAge,
            entries: entries,
            totalUnlocked: totalUnlocked,
            totalCount: entries.count
        )
    }

    // MARK: - presentWall

    func test_presentWall_callsDisplay() async {
        let (sut, spy) = makeSUT()
        await sut.presentWall(response: makeWallResponse())
        XCTAssertNotNil(spy.lastWallVM)
    }

    func test_presentWall_heroTitleContainsNameAndAge() async {
        let (sut, spy) = makeSUT()
        await sut.presentWall(response: makeWallResponse(childName: "Ваня", childAge: 7))
        XCTAssertTrue(spy.lastWallVM?.heroTitle.contains("Ваня") ?? false)
        XCTAssertTrue(spy.lastWallVM?.heroTitle.contains("7") ?? false)
    }

    func test_presentWall_heroSubtitleContainsUnlockedCount() async {
        let (sut, spy) = makeSUT()
        let entries = [makeWallEntry(unlocked: true), makeWallEntry(unlocked: false)]
        await sut.presentWall(response: makeWallResponse(entries: entries, totalUnlocked: 1))
        let subtitle = spy.lastWallVM?.heroSubtitle ?? ""
        XCTAssertTrue(subtitle.contains("1"))
        XCTAssertTrue(subtitle.contains("2"))
    }

    func test_presentWall_cellsCountMatchesEntries() async {
        let (sut, spy) = makeSUT()
        let entries = Achievement.allCases.prefix(5).map { makeWallEntry(achievement: $0) }
        await sut.presentWall(response: makeWallResponse(entries: Array(entries)))
        XCTAssertEqual(spy.lastWallVM?.cells.count, 5)
    }

    func test_presentWall_unlockedCellA11yContainsReceived() async {
        let (sut, spy) = makeSUT()
        let entry = makeWallEntry(achievement: .firstSoundMastered, unlocked: true)
        await sut.presentWall(response: makeWallResponse(entries: [entry]))
        let a11y = spy.lastWallVM?.cells.first?.accessibilityLabel ?? ""
        XCTAssertTrue(a11y.contains("получено"))
    }

    func test_presentWall_lockedCellA11yContainsNotReceived() async {
        let (sut, spy) = makeSUT()
        let entry = makeWallEntry(achievement: .firstSoundMastered, unlocked: false)
        await sut.presentWall(response: makeWallResponse(entries: [entry]))
        let a11y = spy.lastWallVM?.cells.first?.accessibilityLabel ?? ""
        XCTAssertTrue(a11y.contains("не получено"))
    }

    // MARK: - presentDetail

    func test_presentDetail_unlockedEntry_mascotCelebrating() async {
        let (sut, spy) = makeSUT()
        let entry = makeWallEntry(unlocked: true, unlockedDate: Date())
        await sut.presentDetail(response: .init(entry: entry))
        XCTAssertEqual(spy.lastDetailVM?.mascotState, .celebrating)
    }

    func test_presentDetail_lockedEntry_mascotThinking() async {
        let (sut, spy) = makeSUT()
        let entry = makeWallEntry(unlocked: false)
        await sut.presentDetail(response: .init(entry: entry))
        XCTAssertEqual(spy.lastDetailVM?.mascotState, .thinking)
    }

    func test_presentDetail_unlockedWithDate_hasDateLabel() async {
        let (sut, spy) = makeSUT()
        let entry = makeWallEntry(unlocked: true, unlockedDate: Date())
        await sut.presentDetail(response: .init(entry: entry))
        XCTAssertNotNil(spy.lastDetailVM?.unlockedDateLabel)
    }

    func test_presentDetail_lockedNoDate_nilDateLabel() async {
        let (sut, spy) = makeSUT()
        let entry = makeWallEntry(unlocked: false, unlockedDate: nil)
        await sut.presentDetail(response: .init(entry: entry))
        XCTAssertNil(spy.lastDetailVM?.unlockedDateLabel)
    }

    func test_presentDetail_a11yContainsUnlockedStatus() async {
        let (sut, spy) = makeSUT()
        let entry = makeWallEntry(achievement: .streak7Days, unlocked: true)
        await sut.presentDetail(response: .init(entry: entry))
        XCTAssertTrue(spy.lastDetailVM?.accessibilityLabel.contains("Получено") ?? false)
    }

    // MARK: - presentShare

    func test_presentShare_passesShareText() async {
        let (sut, spy) = makeSUT()
        await sut.presentShare(response: .init(shareText: "Стена наград!"))
        XCTAssertEqual(spy.lastShareVM?.shareText, "Стена наград!")
    }
}
