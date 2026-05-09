@testable import HappySpeech
import XCTest

// MARK: - CulturalContentPresenterTests
//
// Block V v18 — покрытие CulturalContentPresenter (7 тестов).
// Тестируются все три метода presentationLogic через DisplaySpy.

@MainActor
final class CulturalContentPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: CulturalContentDisplayLogic {
        var loadVM: CulturalContentModels.Load.ViewModel?
        var openVM: CulturalContentModels.Open.ViewModel?
        var toggleBookmarkVM: CulturalContentModels.ToggleBookmark.ViewModel?

        func displayLoad(viewModel: CulturalContentModels.Load.ViewModel) async {
            loadVM = viewModel
        }
        func displayOpen(viewModel: CulturalContentModels.Open.ViewModel) async {
            openVM = viewModel
        }
        func displayToggleBookmark(viewModel: CulturalContentModels.ToggleBookmark.ViewModel) async {
            toggleBookmarkVM = viewModel
        }
    }

    private func makeSUT() -> (CulturalContentPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = CulturalContentPresenter(displayLogic: spy)
        return (presenter, spy)
    }

    // MARK: - presentLoad

    func test_presentLoad_allCategories_arePresentInRows() async {
        let (sut, spy) = makeSUT()
        let response = CulturalContentModels.Load.Response(
            activeCategory: nil,
            items: CulturalItem.catalog,
            bookmarkedItemIDs: []
        )
        await sut.presentLoad(response: response)
        XCTAssertEqual(spy.loadVM?.categories.count, CulturalCategory.allCases.count)
    }

    func test_presentLoad_activeCategory_isMarkedActive() async {
        let (sut, spy) = makeSUT()
        let response = CulturalContentModels.Load.Response(
            activeCategory: .fairyTale,
            items: CulturalItem.catalog,
            bookmarkedItemIDs: []
        )
        await sut.presentLoad(response: response)
        let activeRow = spy.loadVM?.categories.first { $0.isActive }
        XCTAssertNotNil(activeRow)
        XCTAssertEqual(activeRow?.id, CulturalCategory.fairyTale.id)
    }

    func test_presentLoad_bookmarkedItems_sortedFirst() async {
        let (sut, spy) = makeSUT()
        let bookmarkedId = CulturalItem.catalog.last!.id
        let response = CulturalContentModels.Load.Response(
            activeCategory: nil,
            items: CulturalItem.catalog,
            bookmarkedItemIDs: [bookmarkedId]
        )
        await sut.presentLoad(response: response)
        XCTAssertTrue(spy.loadVM?.items.first?.isBookmarked ?? false, "Заблокированный элемент должен быть первым")
    }

    func test_presentLoad_emptyItems_setsEmptyHint() async {
        let (sut, spy) = makeSUT()
        let response = CulturalContentModels.Load.Response(
            activeCategory: .song,
            items: [],
            bookmarkedItemIDs: []
        )
        await sut.presentLoad(response: response)
        XCTAssertNotNil(spy.loadVM?.emptyHint)
    }

    // MARK: - presentOpen

    func test_presentOpen_withAuthor_setsAuthor() async {
        let (sut, spy) = makeSUT()
        let item = CulturalItem.catalog.first { $0.authorKey != nil }!
        let response = CulturalContentModels.Open.Response(
            item: item,
            isBookmarked: false
        )
        await sut.presentOpen(response: response)
        XCTAssertNotNil(spy.openVM?.author)
        XCTAssertFalse(spy.openVM?.lines.isEmpty ?? true)
    }

    func test_presentOpen_noAuthor_authorIsNil() async {
        let (sut, spy) = makeSUT()
        let item = CulturalItem.catalog.first { $0.authorKey == nil }!
        let response = CulturalContentModels.Open.Response(
            item: item,
            isBookmarked: true
        )
        await sut.presentOpen(response: response)
        XCTAssertNil(spy.openVM?.author)
        XCTAssertTrue(spy.openVM?.isBookmarked ?? false)
    }

    // MARK: - presentToggleBookmark

    func test_presentToggleBookmark_addedBookmark_setsToastMessage() async {
        let (sut, spy) = makeSUT()
        let response = CulturalContentModels.ToggleBookmark.Response(
            itemId: "tale.repka",
            isBookmarked: true
        )
        await sut.presentToggleBookmark(response: response)
        XCTAssertNotNil(spy.toggleBookmarkVM)
        XCTAssertFalse(spy.toggleBookmarkVM?.toastMessage.isEmpty ?? true)
    }
}
