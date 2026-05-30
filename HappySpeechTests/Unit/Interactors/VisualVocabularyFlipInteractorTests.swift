@testable import HappySpeech
import XCTest

// MARK: - VisualVocabularyFlipInteractorTests
//
// VisualVocabularyFlipInteractor is a thin VIP MVP variant (@Observable). The
// `deck` computed filters the full card deck by the active SoundFilter; toggle()
// flips individual cards; setFilter() switches filter and clears flips. Tests
// cover filtering per sound, flip toggling, and the filter-clears-flips contract.

@MainActor
final class VisualVocabularyFlipInteractorTests: XCTestCase {

    private func makeSUT(childId: String = "child-1") -> VisualVocabularyFlipInteractor {
        VisualVocabularyFlipInteractor(childId: childId)
    }

    // MARK: - Initial state

    func test_init_storesChildId() {
        let sut = makeSUT(childId: "kid-flip")
        XCTAssertEqual(sut.childId, "kid-flip")
    }

    func test_initialFilter_isAll() {
        let sut = makeSUT()
        XCTAssertEqual(sut.filter, .all)
    }

    func test_initialFlipped_isEmpty() {
        let sut = makeSUT()
        XCTAssertTrue(sut.flippedIds.isEmpty)
    }

    func test_initialDeck_isFullDeck() {
        let sut = makeSUT()
        XCTAssertEqual(sut.deck.count, VisualVocabularyFlipModels.deck.count)
    }

    func test_deck_cardIdsAreUnique() {
        let ids = VisualVocabularyFlipModels.deck.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    // MARK: - filtering

    func test_setFilter_s_showsOnlySSound() {
        let sut = makeSUT()
        sut.setFilter(.s)
        XCTAssertTrue(sut.deck.allSatisfy { $0.targetSound == "С" })
        XCTAssertEqual(sut.deck.count, 5)
    }

    func test_setFilter_sh_showsOnlyShSound() {
        let sut = makeSUT()
        sut.setFilter(.sh)
        XCTAssertTrue(sut.deck.allSatisfy { $0.targetSound == "Ш" })
        XCTAssertEqual(sut.deck.count, 4)
    }

    func test_setFilter_r_showsOnlyRSound() {
        let sut = makeSUT()
        sut.setFilter(.r)
        XCTAssertTrue(sut.deck.allSatisfy { $0.targetSound == "Р" })
        XCTAssertEqual(sut.deck.count, 5)
    }

    func test_setFilter_zh_showsOnlyZhSound() {
        let sut = makeSUT()
        sut.setFilter(.zh)
        XCTAssertTrue(sut.deck.allSatisfy { $0.targetSound == "Ж" })
        XCTAssertEqual(sut.deck.count, 3)
    }

    func test_setFilter_k_showsOnlyKSound() {
        let sut = makeSUT()
        sut.setFilter(.k)
        XCTAssertTrue(sut.deck.allSatisfy { $0.targetSound == "К" })
        XCTAssertEqual(sut.deck.count, 3)
    }

    func test_setFilter_all_restoresFullDeck() {
        let sut = makeSUT()
        sut.setFilter(.s)
        sut.setFilter(.all)
        XCTAssertEqual(sut.deck.count, VisualVocabularyFlipModels.deck.count)
    }

    func test_filteredCounts_sumToFullDeck() {
        let sut = makeSUT()
        var total = 0
        for filter in [VisualVocabularyFlipModels.SoundFilter.s, .sh, .r, .zh, .k] {
            sut.setFilter(filter)
            total += sut.deck.count
        }
        XCTAssertEqual(total, VisualVocabularyFlipModels.deck.count)
    }

    // MARK: - toggle flip

    func test_toggle_flipsCard() {
        let sut = makeSUT()
        let id = sut.deck[0].id
        sut.toggle(id)
        XCTAssertTrue(sut.flippedIds.contains(id))
    }

    func test_toggle_twice_unflipsCard() {
        let sut = makeSUT()
        let id = sut.deck[0].id
        sut.toggle(id)
        sut.toggle(id)
        XCTAssertFalse(sut.flippedIds.contains(id))
    }

    func test_toggle_multipleCards_tracksEach() {
        let sut = makeSUT()
        let a = sut.deck[0].id
        let b = sut.deck[1].id
        sut.toggle(a)
        sut.toggle(b)
        XCTAssertEqual(sut.flippedIds, [a, b])
    }

    // MARK: - setFilter clears flips

    func test_setFilter_clearsFlippedIds() {
        let sut = makeSUT()
        sut.toggle(sut.deck[0].id)
        XCTAssertFalse(sut.flippedIds.isEmpty)
        sut.setFilter(.r)
        XCTAssertTrue(sut.flippedIds.isEmpty)
    }

    func test_setFilter_updatesFilterProperty() {
        let sut = makeSUT()
        sut.setFilter(.zh)
        XCTAssertEqual(sut.filter, .zh)
    }
}
