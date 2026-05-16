@testable import HappySpeech
import XCTest

// MARK: - CulturalContentInteractorTests
//
// Block 2.8.3 v25 — unit-покрытие CulturalContentInteractor (R.5 v18).
// Паттерн: Interactor → spy на CulturalContentPresentationLogic.
// Контент статичный (CulturalItem.catalog); persistence — изолированный UserDefaults.

@MainActor
private final class SpyCulturalContentPresenter: CulturalContentPresentationLogic, @unchecked Sendable {
    var presentLoadCalled = false
    var presentOpenCalled = false
    var presentToggleBookmarkCalled = false

    var lastLoad: CulturalContentModels.Load.Response?
    var lastOpen: CulturalContentModels.Open.Response?
    var lastToggle: CulturalContentModels.ToggleBookmark.Response?

    func presentLoad(response: CulturalContentModels.Load.Response) async {
        presentLoadCalled = true
        lastLoad = response
    }
    func presentOpen(response: CulturalContentModels.Open.Response) async {
        presentOpenCalled = true
        lastOpen = response
    }
    func presentToggleBookmark(response: CulturalContentModels.ToggleBookmark.Response) async {
        presentToggleBookmarkCalled = true
        lastToggle = response
    }
}

@MainActor
final class CulturalContentInteractorTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "test.cultural.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func makeSUT(
        childId: String = "child-cc"
    ) -> (CulturalContentInteractor, SpyCulturalContentPresenter) {
        let sut = CulturalContentInteractor(
            childId: childId,
            hapticService: MockHapticService(),
            userDefaults: defaults
        )
        let spy = SpyCulturalContentPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - 1. load — без категории → весь каталог

    func test_load_noCategory_returnsFullCatalog() async {
        let (sut, spy) = makeSUT()
        await sut.load(request: .init(childId: "child-cc", category: nil))

        XCTAssertTrue(spy.presentLoadCalled)
        XCTAssertEqual(spy.lastLoad?.items.count, CulturalItem.catalog.count)
        XCTAssertNil(spy.lastLoad?.activeCategory)
    }

    // MARK: - 2. load — с категорией fairyTale → только сказки

    func test_load_fairyTaleCategory_filtersItems() async {
        let (sut, spy) = makeSUT()
        await sut.load(request: .init(childId: "child-cc", category: .fairyTale))

        XCTAssertEqual(spy.lastLoad?.activeCategory, .fairyTale)
        XCTAssertTrue(spy.lastLoad?.items.allSatisfy { $0.category == .fairyTale } ?? false)
        XCTAssertFalse(spy.lastLoad?.items.isEmpty ?? true)
    }

    // MARK: - 3. load — каждая категория содержит элементы

    func test_load_eachCategoryHasItems() async {
        for category in CulturalCategory.allCases {
            let (sut, spy) = makeSUT()
            await sut.load(request: .init(childId: "child-cc", category: category))
            XCTAssertFalse(spy.lastLoad?.items.isEmpty ?? true,
                           "Категория \(category) должна содержать элементы")
        }
    }

    // MARK: - 4. load — activeCategory сохраняется между вызовами

    func test_load_usesStoredActiveCategoryWhenNil() async {
        let (sut, spy) = makeSUT()
        await sut.load(request: .init(childId: "child-cc", category: .song))
        // Второй load без категории — должен использовать сохранённую (.song).
        await sut.load(request: .init(childId: "child-cc", category: nil))

        XCTAssertEqual(spy.lastLoad?.activeCategory, .song)
    }

    // MARK: - 5. open — существующий item → presentOpen

    func test_open_validItem_presentsItem() async {
        let (sut, spy) = makeSUT()
        let itemId = CulturalItem.catalog[0].id
        await sut.open(request: .init(itemId: itemId))

        XCTAssertTrue(spy.presentOpenCalled)
        XCTAssertEqual(spy.lastOpen?.item.id, itemId)
        XCTAssertFalse(spy.lastOpen?.isBookmarked ?? true)
    }

    // MARK: - 6. open — несуществующий item → no-op

    func test_open_unknownItem_doesNotPresent() async {
        let (sut, spy) = makeSUT()
        await sut.open(request: .init(itemId: "ghost-item"))

        XCTAssertFalse(spy.presentOpenCalled)
    }

    // MARK: - 7. toggleBookmark — добавляет закладку

    func test_toggleBookmark_addsBookmark() async {
        let (sut, spy) = makeSUT()
        let itemId = CulturalItem.catalog[0].id
        await sut.toggleBookmark(request: .init(childId: "child-cc", itemId: itemId))

        XCTAssertTrue(spy.presentToggleBookmarkCalled)
        XCTAssertEqual(spy.lastToggle?.itemId, itemId)
        XCTAssertEqual(spy.lastToggle?.isBookmarked, true)
    }

    // MARK: - 8. toggleBookmark — повторно убирает закладку

    func test_toggleBookmark_secondCallRemovesBookmark() async {
        let (sut, spy) = makeSUT()
        let itemId = CulturalItem.catalog[0].id
        await sut.toggleBookmark(request: .init(childId: "child-cc", itemId: itemId))
        await sut.toggleBookmark(request: .init(childId: "child-cc", itemId: itemId))

        XCTAssertEqual(spy.lastToggle?.isBookmarked, false)
    }

    // MARK: - 9. toggleBookmark — персистентность: open показывает закладку

    func test_toggleBookmark_persistsAcrossOpen() async {
        let (sut, spy) = makeSUT()
        let itemId = CulturalItem.catalog[1].id
        await sut.toggleBookmark(request: .init(childId: "child-cc", itemId: itemId))
        await sut.open(request: .init(itemId: itemId))

        XCTAssertEqual(spy.lastOpen?.isBookmarked, true)
    }

    // MARK: - 10. toggleBookmark — закладка отражается в load

    func test_toggleBookmark_appearsInLoadResponse() async {
        let (sut, spy) = makeSUT()
        let itemId = CulturalItem.catalog[2].id
        await sut.toggleBookmark(request: .init(childId: "child-cc", itemId: itemId))
        await sut.load(request: .init(childId: "child-cc", category: nil))

        XCTAssertTrue(spy.lastLoad?.bookmarkedItemIDs.contains(itemId) ?? false)
    }

    // MARK: - 11. CulturalItem.find — по id

    func test_culturalItem_find() {
        XCTAssertNotNil(CulturalItem.find(id: "tale.repka"))
        XCTAssertNil(CulturalItem.find(id: "nonexistent"))
    }

    // MARK: - 12. CulturalItem.items — фильтрация по категории

    func test_culturalItem_itemsForCategory() {
        let twisters = CulturalItem.items(for: .tongueTwister)
        XCTAssertFalse(twisters.isEmpty)
        XCTAssertTrue(twisters.allSatisfy { $0.category == .tongueTwister })
    }

    // MARK: - 13. CulturalCategory — symbolName/titleKey не пусты

    func test_culturalCategory_metadataNonEmpty() {
        for category in CulturalCategory.allCases {
            XCTAssertFalse(category.symbolName.isEmpty)
            XCTAssertFalse(category.titleKey.isEmpty)
            XCTAssertEqual(category.id, category.rawValue)
        }
    }

    // MARK: - 14. DataStore — childId / activeCategory

    func test_dataStore_initialState() {
        let (sut, _) = makeSUT(childId: "cc-custom")
        XCTAssertEqual(sut.childId, "cc-custom")
        XCTAssertNil(sut.activeCategory)
    }

    // MARK: - 15. load — разные дети имеют независимые закладки

    func test_load_bookmarksPerChild() async {
        let (sut, spy) = makeSUT(childId: "child-A")
        let itemId = CulturalItem.catalog[0].id
        await sut.toggleBookmark(request: .init(childId: "child-A", itemId: itemId))
        // load для другого ребёнка — закладок нет.
        await sut.load(request: .init(childId: "child-B", category: nil))

        XCTAssertFalse(spy.lastLoad?.bookmarkedItemIDs.contains(itemId) ?? true)
    }
}
