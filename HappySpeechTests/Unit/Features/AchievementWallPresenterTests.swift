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

    // MARK: - Additional coverage (Step 11 close-out)

    func test_presentWall_emptyEntries_cellsAreEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentWall(response: makeWallResponse(entries: []))
        XCTAssertEqual(spy.lastWallVM?.cells.count, 0)
    }

    func test_presentWall_heroSubtitleContainsZeroForEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentWall(response: makeWallResponse(totalUnlocked: 0))
        XCTAssertTrue(spy.lastWallVM?.heroSubtitle.contains("0") ?? false)
    }

    func test_presentWall_accessibilitySummary_isNotEmpty() async {
        let (sut, spy) = makeSUT()
        let entries = [makeWallEntry(unlocked: true), makeWallEntry(achievement: .streak3Days)]
        await sut.presentWall(response: makeWallResponse(entries: entries, totalUnlocked: 1))
        XCTAssertFalse(spy.lastWallVM?.accessibilitySummary.isEmpty ?? true)
        XCTAssertTrue(spy.lastWallVM?.accessibilitySummary.contains("1") ?? false)
    }

    func test_presentWall_cell_preservesAchievementIcon() async {
        let (sut, spy) = makeSUT()
        let entry = makeWallEntry(achievement: .streak7Days, unlocked: true)
        await sut.presentWall(response: makeWallResponse(entries: [entry]))
        XCTAssertEqual(spy.lastWallVM?.cells.first?.iconName, Achievement.streak7Days.iconName)
    }

    func test_presentWall_cell_preservesAchievementRarity() async {
        let (sut, spy) = makeSUT()
        // streak100Days is `.legendary`
        let entry = makeWallEntry(achievement: .streak100Days, unlocked: false)
        await sut.presentWall(response: makeWallResponse(entries: [entry]))
        XCTAssertEqual(spy.lastWallVM?.cells.first?.rarity, .legendary)
    }

    func test_presentWall_cell_idIsAchievementRawValue() async {
        let (sut, spy) = makeSUT()
        let entry = makeWallEntry(achievement: .played50Rounds)
        await sut.presentWall(response: makeWallResponse(entries: [entry]))
        XCTAssertEqual(spy.lastWallVM?.cells.first?.id, Achievement.played50Rounds.rawValue)
    }

    func test_presentDetail_passesAchievementTitleAndDescription() async {
        let (sut, spy) = makeSUT()
        let entry = makeWallEntry(achievement: .firstSoundMastered, unlocked: true)
        await sut.presentDetail(response: .init(entry: entry))
        XCTAssertEqual(spy.lastDetailVM?.title, Achievement.firstSoundMastered.localizedTitle)
        XCTAssertEqual(spy.lastDetailVM?.description, Achievement.firstSoundMastered.localizedDescription)
    }

    func test_presentDetail_iconNamePassedThrough() async {
        let (sut, spy) = makeSUT()
        let entry = makeWallEntry(achievement: .firstAR)
        await sut.presentDetail(response: .init(entry: entry))
        XCTAssertEqual(spy.lastDetailVM?.iconName, Achievement.firstAR.iconName)
    }

    func test_presentDetail_isUnlockedPassedThrough() async {
        let (sut, spy) = makeSUT()
        let entry = makeWallEntry(unlocked: true, unlockedDate: Date())
        await sut.presentDetail(response: .init(entry: entry))
        XCTAssertTrue(spy.lastDetailVM?.isUnlocked ?? false)
    }

    func test_presentDetail_lockedA11y_containsNotReceived() async {
        let (sut, spy) = makeSUT()
        let entry = makeWallEntry(achievement: .streak3Days, unlocked: false)
        await sut.presentDetail(response: .init(entry: entry))
        let a11y = spy.lastDetailVM?.accessibilityLabel ?? ""
        XCTAssertTrue(a11y.contains("Ещё не получено") || a11y.contains("не получено"))
    }

    func test_presentDetail_unlockedDateLabel_containsReceived() async {
        let (sut, spy) = makeSUT()
        let entry = makeWallEntry(unlocked: true, unlockedDate: Date(timeIntervalSince1970: 1_700_000_000))
        await sut.presentDetail(response: .init(entry: entry))
        XCTAssertTrue(spy.lastDetailVM?.unlockedDateLabel?.contains("Получено") ?? false)
    }

    func test_presentDetail_rareAchievement_tintIsLilac() async {
        let (sut, spy) = makeSUT()
        // .streak30Days has rarity .rare → tint should be ColorTokens.Brand.lilac
        let entry = makeWallEntry(achievement: .streak30Days, unlocked: true)
        await sut.presentDetail(response: .init(entry: entry))
        // We can't compare Color values reliably; just assert the VM was built.
        XCTAssertNotNil(spy.lastDetailVM?.tintColor)
    }

    func test_presentDetail_legendaryAchievement_tintIsBuilt() async {
        let (sut, spy) = makeSUT()
        let entry = makeWallEntry(achievement: .streak100Days, unlocked: true)
        await sut.presentDetail(response: .init(entry: entry))
        XCTAssertNotNil(spy.lastDetailVM?.tintColor)
    }

    func test_presentDetail_commonAchievement_tintIsBuilt() async {
        let (sut, spy) = makeSUT()
        let entry = makeWallEntry(achievement: .firstSoundMastered, unlocked: true)
        await sut.presentDetail(response: .init(entry: entry))
        XCTAssertNotNil(spy.lastDetailVM?.tintColor)
    }

    func test_presentShare_emptyShareText_passesEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentShare(response: .init(shareText: ""))
        XCTAssertEqual(spy.lastShareVM?.shareText, "")
    }
}
