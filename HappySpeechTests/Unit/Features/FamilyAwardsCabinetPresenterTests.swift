@testable import HappySpeech
import XCTest

// MARK: - FamilyAwardsCabinetPresenterTests
//
// Phase 2.6 batch 2 v25 — покрытие FamilyAwardsCabinetPresenter (0% → цель ≥90%).

@MainActor
final class FamilyAwardsCabinetPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: FamilyAwardsCabinetDisplayLogic {
        var loadVM: FamilyAwardsCabinetModels.Load.ViewModel?
        var selectAwardVM: FamilyAwardsCabinetModels.SelectAward.ViewModel?

        func displayLoad(viewModel: FamilyAwardsCabinetModels.Load.ViewModel) async { loadVM = viewModel }
        func displaySelectAward(viewModel: FamilyAwardsCabinetModels.SelectAward.ViewModel) async { selectAwardVM = viewModel }
    }

    private func makeSUT() -> (FamilyAwardsCabinetPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = FamilyAwardsCabinetPresenter(displayLogic: spy)
        return (presenter, spy)
    }

    private func makeAward(
        id: String = UUID().uuidString,
        childName: String = "Маша",
        tier: AwardTier = .gold,
        titleKey: String = "familyAwardsCabinet.award.streak_7"
    ) -> FamilyAward {
        FamilyAward(
            id: id,
            childId: "c-1",
            childName: childName,
            tier: tier,
            titleKey: titleKey,
            unlockedDate: Date(),
            symbolName: "flame.fill"
        )
    }

    private func makeShelf(tier: AwardTier, awards: [FamilyAward]) -> FamilyAwardsCabinetModels.Load.ShelfBucket {
        FamilyAwardsCabinetModels.Load.ShelfBucket(tier: tier, awards: awards)
    }

    // MARK: - presentLoad: empty cabinet

    func test_presentLoad_callsDisplay() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(shelves: [], totalAwards: 0, totalChildren: 0))
        XCTAssertNotNil(spy.loadVM)
    }

    func test_presentLoad_zeroAwards_cabinetIsEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(shelves: [], totalAwards: 0, totalChildren: 0))
        XCTAssertTrue(spy.loadVM?.cabinetIsEmpty ?? false)
    }

    func test_presentLoad_heroTitleNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(shelves: [], totalAwards: 0, totalChildren: 0))
        XCTAssertFalse(spy.loadVM?.heroTitle.isEmpty ?? true)
    }

    func test_presentLoad_zeroAwards_heroSubtitleNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(shelves: [], totalAwards: 0, totalChildren: 1))
        XCTAssertFalse(spy.loadVM?.heroSubtitle.isEmpty ?? true)
    }

    func test_presentLoad_zeroAwards_emptyTitleNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(shelves: [], totalAwards: 0, totalChildren: 0))
        XCTAssertFalse(spy.loadVM?.emptyTitle.isEmpty ?? true)
    }

    func test_presentLoad_zeroAwards_emptySubtitleNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: .init(shelves: [], totalAwards: 0, totalChildren: 0))
        XCTAssertFalse(spy.loadVM?.emptySubtitle.isEmpty ?? true)
    }

    // MARK: - presentLoad: non-empty cabinet

    func test_presentLoad_nonZeroAwards_cabinetIsNotEmpty() async {
        let (sut, spy) = makeSUT()
        let award = makeAward()
        let shelf = makeShelf(tier: .gold, awards: [award])
        await sut.presentLoad(response: .init(shelves: [shelf], totalAwards: 1, totalChildren: 1))
        XCTAssertFalse(spy.loadVM?.cabinetIsEmpty ?? true)
    }

    func test_presentLoad_shelvesBuilt() async {
        let (sut, spy) = makeSUT()
        let goldShelf = makeShelf(tier: .gold, awards: [makeAward(tier: .gold)])
        let bronzeShelf = makeShelf(tier: .bronze, awards: [makeAward(tier: .bronze)])
        await sut.presentLoad(response: .init(shelves: [goldShelf, bronzeShelf], totalAwards: 2, totalChildren: 1))
        XCTAssertEqual(spy.loadVM?.shelves.count, 2)
    }

    func test_presentLoad_shelfTrophiesBuilt() async {
        let (sut, spy) = makeSUT()
        let awards = [makeAward(), makeAward()]
        let shelf = makeShelf(tier: .gold, awards: awards)
        await sut.presentLoad(response: .init(shelves: [shelf], totalAwards: 2, totalChildren: 1))
        XCTAssertEqual(spy.loadVM?.shelves.first?.trophies.count, 2)
    }

    func test_presentLoad_trophyCountLabelNotEmpty() async {
        let (sut, spy) = makeSUT()
        let shelf = makeShelf(tier: .silver, awards: [makeAward(tier: .silver)])
        await sut.presentLoad(response: .init(shelves: [shelf], totalAwards: 1, totalChildren: 1))
        XCTAssertFalse(spy.loadVM?.shelves.first?.trophyCountLabel.isEmpty ?? true)
    }

    func test_presentLoad_trophyA11yLabelNotEmpty() async {
        let (sut, spy) = makeSUT()
        let award = makeAward(childName: "Ваня")
        let shelf = makeShelf(tier: .bronze, awards: [award])
        await sut.presentLoad(response: .init(shelves: [shelf], totalAwards: 1, totalChildren: 1))
        XCTAssertFalse(spy.loadVM?.shelves.first?.trophies.first?.accessibilityLabel.isEmpty ?? true)
    }

    func test_presentLoad_trophyChildNamePassedThrough() async {
        let (sut, spy) = makeSUT()
        let award = makeAward(childName: "Маша")
        let shelf = makeShelf(tier: .platinum, awards: [award])
        await sut.presentLoad(response: .init(shelves: [shelf], totalAwards: 1, totalChildren: 1))
        XCTAssertEqual(spy.loadVM?.shelves.first?.trophies.first?.childName, "Маша")
    }

    func test_presentLoad_trophyDateLabelNotEmpty() async {
        let (sut, spy) = makeSUT()
        let award = makeAward()
        let shelf = makeShelf(tier: .gold, awards: [award])
        await sut.presentLoad(response: .init(shelves: [shelf], totalAwards: 1, totalChildren: 1))
        XCTAssertFalse(spy.loadVM?.shelves.first?.trophies.first?.dateLabel.isEmpty ?? true)
    }

    func test_presentLoad_nonZeroAwards_summaryHeroSubtitleNotEmpty() async {
        let (sut, spy) = makeSUT()
        let shelf = makeShelf(tier: .gold, awards: [makeAward()])
        await sut.presentLoad(response: .init(shelves: [shelf], totalAwards: 3, totalChildren: 2))
        XCTAssertFalse(spy.loadVM?.heroSubtitle.isEmpty ?? true)
    }

    // MARK: - presentSelectAward

    func test_presentSelectAward_callsDisplay() async {
        let (sut, spy) = makeSUT()
        await sut.presentSelectAward(response: .init(award: makeAward()))
        XCTAssertNotNil(spy.selectAwardVM)
    }

    func test_presentSelectAward_titleNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentSelectAward(response: .init(award: makeAward()))
        XCTAssertFalse(spy.selectAwardVM?.title.isEmpty ?? true)
    }

    func test_presentSelectAward_subtitleNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentSelectAward(response: .init(award: makeAward(childName: "Ваня")))
        XCTAssertFalse(spy.selectAwardVM?.subtitle.isEmpty ?? true)
    }

    func test_presentSelectAward_tierTitleNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentSelectAward(response: .init(award: makeAward(tier: .platinum)))
        XCTAssertFalse(spy.selectAwardVM?.tierTitle.isEmpty ?? true)
    }

    func test_presentSelectAward_symbolNamePassedThrough() async {
        let (sut, spy) = makeSUT()
        let award = FamilyAward(
            id: "a1", childId: "c1", childName: "Маша",
            tier: .bronze, titleKey: "some.key",
            unlockedDate: Date(), symbolName: "star.fill"
        )
        await sut.presentSelectAward(response: .init(award: award))
        XCTAssertEqual(spy.selectAwardVM?.symbolName, "star.fill")
    }

    func test_presentSelectAward_detailNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentSelectAward(response: .init(award: makeAward()))
        XCTAssertFalse(spy.selectAwardVM?.detail.isEmpty ?? true)
    }
}
