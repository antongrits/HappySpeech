import XCTest
@testable import HappySpeech

// MARK: - FamilyHomeInteractorTests
//
// Strategy: wire the real FamilyHomePresenter → FamilyHomeViewModel.
// The interactor holds `weak var presenter`, so we keep presenter alive
// by always naming it (never _ ) in each test. We use named tuple access
// via `let c = makeSUT()` so all references stay alive across await.

@MainActor
final class FamilyHomeInteractorTests: XCTestCase {

    // MARK: - SUT factory

    private func makeSUT(children: [ChildProfileDTO]? = nil) -> (
        sut: FamilyHomeInteractor,
        repo: SpyChildRepository,
        presenter: FamilyHomePresenter,
        viewModel: FamilyHomeViewModel
    ) {
        let repo = SpyChildRepository(children: children ?? [
            TestDataBuilder.childProfile(id: "c1", name: "Маша"),
            TestDataBuilder.childProfile(id: "c2", name: "Ваня")
        ])
        let sut = FamilyHomeInteractor(childRepository: repo)
        let presenter = FamilyHomePresenter()
        let viewModel = FamilyHomeViewModel()
        presenter.viewModel = viewModel
        sut.presenter = presenter
        return (sut, repo, presenter, viewModel)
    }

    // MARK: - load

    func test_load_setsIsLoadingFalse_afterCompletion() async {
        let c = makeSUT()
        await c.sut.load(FamilyHome.LoadRequest())
        XCTAssertFalse(c.viewModel.isLoading)
    }

    func test_load_populatesChildren() async {
        let c = makeSUT()
        await c.sut.load(FamilyHome.LoadRequest())
        XCTAssertEqual(c.viewModel.children.count, 2)
    }

    func test_load_onRepoError_setsErrorMessage() async {
        let c = makeSUT()
        c.repo.shouldFail = true
        await c.sut.load(FamilyHome.LoadRequest())
        XCTAssertNotNil(c.viewModel.errorMessage)
    }

    func test_load_callsChildRepoFetchAll() async {
        let c = makeSUT()
        await c.sut.load(FamilyHome.LoadRequest())
        XCTAssertEqual(c.repo.fetchAllCallCount, 1)
    }

    // MARK: - sort

    func test_sort_byName_reordersChildrenAlphabetically() async {
        let children = [
            TestDataBuilder.childProfile(id: "c1", name: "Яна"),
            TestDataBuilder.childProfile(id: "c2", name: "Аня")
        ]
        let c = makeSUT(children: children)
        await c.sut.load(FamilyHome.LoadRequest())
        await c.sut.sort(FamilyHome.SortRequest(order: .byName))
        XCTAssertEqual(c.viewModel.children.first?.name, "Аня")
    }

    func test_sort_byProgress_sortsHighestFirst() async {
        let low = TestDataBuilder.childProfile(id: "c1", name: "А", progressSummary: ["Р": 0.2])
        let high = TestDataBuilder.childProfile(id: "c2", name: "Б", progressSummary: ["Р": 0.9])
        let c = makeSUT(children: [low, high])
        await c.sut.load(FamilyHome.LoadRequest())
        await c.sut.sort(FamilyHome.SortRequest(order: .byProgress))
        XCTAssertEqual(c.viewModel.children.first?.id, "c2")
    }

    // MARK: - selectChild

    func test_selectChild_savesToUserDefaults() async {
        let c = makeSUT()
        await c.sut.load(FamilyHome.LoadRequest())
        await c.sut.selectChild(FamilyHome.SelectChildRequest(childId: "c1"))
        XCTAssertEqual(UserDefaults.standard.string(forKey: "activeChildId"), "c1")
    }

    // MARK: - addChild

    func test_addChild_belowLimit_doesNotShowError() async {
        let c = makeSUT()
        await c.sut.load(FamilyHome.LoadRequest())
        await c.sut.addChild(FamilyHome.AddChildRequest())
        XCTAssertNil(c.viewModel.errorMessage)
    }

    func test_addChild_atMaxLimit_doesNotCrash() async {
        let children = [
            TestDataBuilder.childProfile(id: "c1", name: "А"),
            TestDataBuilder.childProfile(id: "c2", name: "Б"),
            TestDataBuilder.childProfile(id: "c3", name: "В")
        ]
        let c = makeSUT(children: children)
        await c.sut.load(FamilyHome.LoadRequest())
        await c.sut.addChild(FamilyHome.AddChildRequest())
        // No crash is success
    }

    // MARK: - deleteChild

    func test_deleteChild_lastChild_doesNotCallRepoDelete() async {
        let c = makeSUT(children: [TestDataBuilder.childProfile(id: "c1")])
        await c.sut.load(FamilyHome.LoadRequest())
        await c.sut.deleteChild(FamilyHome.DeleteChildRequest(childId: "c1"))
        XCTAssertEqual(c.repo.deleteCallCount, 0)
    }

    func test_deleteChild_ofTwo_callsRepoDelete() async {
        let c = makeSUT()
        await c.sut.load(FamilyHome.LoadRequest())
        await c.sut.deleteChild(FamilyHome.DeleteChildRequest(childId: "c1"))
        XCTAssertEqual(c.repo.deleteCallCount, 1)
    }

    func test_deleteChild_reducesChildCount() async {
        let c = makeSUT()
        await c.sut.load(FamilyHome.LoadRequest())
        await c.sut.deleteChild(FamilyHome.DeleteChildRequest(childId: "c1"))
        XCTAssertEqual(c.viewModel.children.count, 1)
    }

    // MARK: - updateParentName

    func test_updateParentName_valid_savesToUserDefaults() async {
        let c = makeSUT()
        await c.sut.updateParentName(FamilyHome.UpdateParentNameRequest(name: "Ирина"))
        XCTAssertEqual(UserDefaults.standard.string(forKey: "parentDisplayName"), "Ирина")
    }

    func test_updateParentName_empty_doesNotSave() async {
        UserDefaults.standard.removeObject(forKey: "parentDisplayName")
        let c = makeSUT()
        await c.sut.updateParentName(FamilyHome.UpdateParentNameRequest(name: "   "))
        XCTAssertNil(UserDefaults.standard.string(forKey: "parentDisplayName"))
    }

    func test_updateParentName_tooLong_doesNotSave() async {
        UserDefaults.standard.removeObject(forKey: "parentDisplayName")
        let c = makeSUT()
        let long = String(repeating: "А", count: 51)
        await c.sut.updateParentName(FamilyHome.UpdateParentNameRequest(name: long))
        XCTAssertNil(UserDefaults.standard.string(forKey: "parentDisplayName"))
    }

    // MARK: - checkStreakNudge

    func test_checkStreakNudge_noAtRiskChildren_doesNotCrash() async {
        let c = makeSUT()
        await c.sut.load(FamilyHome.LoadRequest())
        await c.sut.checkStreakNudge()
    }

    func test_checkStreakNudge_atRiskChild_doesNotCrash() async {
        let atRisk = TestDataBuilder.childProfile(
            id: "c1",
            currentStreak: 5,
            lastSessionAt: Date().addingTimeInterval(-25 * 3600)
        )
        let c = makeSUT(children: [atRisk, TestDataBuilder.childProfile(id: "c2")])
        await c.sut.load(FamilyHome.LoadRequest())
        await c.sut.checkStreakNudge()
    }

    // MARK: - FamilyHome.SortOrder

    func test_sortOrder_allCases_haveLocalizedLabels() {
        for order in FamilyHome.SortOrder.allCases {
            XCTAssertFalse(order.localizedLabel.isEmpty, "empty label for \(order)")
        }
    }

    // MARK: - ViewModel

    func test_viewModel_greeting_withParentName() async {
        UserDefaults.standard.set("Ирина", forKey: "parentDisplayName")
        let c = makeSUT()
        await c.sut.load(FamilyHome.LoadRequest())
        XCTAssertFalse(c.viewModel.greeting.isEmpty)
    }

    func test_viewModel_hasMultipleChildren_trueForTwo() async {
        let c = makeSUT()
        await c.sut.load(FamilyHome.LoadRequest())
        XCTAssertTrue(c.viewModel.hasMultipleChildren)
    }
}
