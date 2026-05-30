@testable import HappySpeech
import XCTest

// MARK: - ChildAchievementShareInteractorTests
//
// ChildAchievementShareInteractor is a thin VIP MVP variant (@Observable). It holds
// a fixed list of shareable achievements and an optional selection; select(_:) sets
// the selected id, the `selected` computed resolves it back to an Item, and
// makeShareText() builds the share string (or nil when nothing is selected). Tests
// cover the seed, the selection/resolution (incl. unknown id), and the share-text
// format (incl. childName interpolation and the nil guard).

@MainActor
final class ChildAchievementShareInteractorTests: XCTestCase {

    private func makeSUT() -> ChildAchievementShareInteractor {
        ChildAchievementShareInteractor()
    }

    // MARK: - Initial state / seed

    func test_initialState_seedItemsNoSelection() {
        let sut = makeSUT()
        XCTAssertFalse(sut.items.isEmpty)
        XCTAssertNil(sut.selectedId)
        XCTAssertNil(sut.selected)
        XCTAssertEqual(sut.childName, "Малыш")
    }

    func test_initialState_itemsWellFormed() {
        let sut = makeSUT()
        XCTAssertEqual(Set(sut.items.map(\.id)).count, sut.items.count)
        for item in sut.items {
            XCTAssertFalse(item.title.isEmpty)
            XCTAssertFalse(item.subtitle.isEmpty)
            XCTAssertFalse(item.emoji.isEmpty)
        }
    }

    // MARK: - select / selected

    func test_select_setsSelectedId() {
        let sut = makeSUT()
        let target = sut.items[2]
        sut.select(target.id)
        XCTAssertEqual(sut.selectedId, target.id)
    }

    func test_selected_resolvesToMatchingItem() {
        let sut = makeSUT()
        let target = sut.items[1]
        sut.select(target.id)
        XCTAssertEqual(sut.selected, target)
    }

    func test_selected_unknownId_isNil() {
        let sut = makeSUT()
        sut.select("does-not-exist")
        XCTAssertNil(sut.selected)
    }

    func test_select_replacesPreviousSelection() {
        let sut = makeSUT()
        sut.select(sut.items[0].id)
        sut.select(sut.items[3].id)
        XCTAssertEqual(sut.selected, sut.items[3])
    }

    // MARK: - makeShareText

    func test_makeShareText_nilWhenNoSelection() {
        let sut = makeSUT()
        XCTAssertNil(sut.makeShareText())
    }

    func test_makeShareText_nilWhenUnknownSelection() {
        let sut = makeSUT()
        sut.select("does-not-exist")
        XCTAssertNil(sut.makeShareText())
    }

    func test_makeShareText_includesTitleSubtitleEmoji() {
        let sut = makeSUT()
        let target = sut.items[0]
        sut.select(target.id)
        let text = sut.makeShareText()
        XCTAssertNotNil(text)
        XCTAssertTrue(text!.contains(target.title))
        XCTAssertTrue(text!.contains(target.subtitle))
        XCTAssertTrue(text!.contains(target.emoji))
    }

    func test_makeShareText_includesChildName() {
        let sut = makeSUT()
        sut.childName = "Аня"
        sut.select(sut.items[0].id)
        XCTAssertTrue(sut.makeShareText()!.contains("Аня"))
    }

    func test_makeShareText_matchesModelHelper() {
        let sut = makeSUT()
        sut.childName = "Миша"
        let target = sut.items[4]
        sut.select(target.id)
        let expected = ChildAchievementShareModels.shareText(item: target, childName: "Миша")
        XCTAssertEqual(sut.makeShareText(), expected)
    }
}
