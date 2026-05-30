@testable import HappySpeech
import XCTest

// MARK: - SentenceBuilderKidInteractorTests
//
// SentenceBuilderKidInteractor is a thin VIP MVP variant (@Observable). Tests
// cover moving chips between available/assembled pools, the isCorrect / isFull /
// correctCount computeds (which validate word order), and reset().

@MainActor
final class SentenceBuilderKidInteractorTests: XCTestCase {

    private func makeSUT(childId: String = "child-1") -> SentenceBuilderKidInteractor {
        SentenceBuilderKidInteractor(childId: childId)
    }

    /// Builds a fully-assembled state in the correct order regardless of the
    /// random shuffle in `.initial` by repeatedly picking the chip whose `order`
    /// matches the next slot.
    private func assembleInCorrectOrder(_ sut: SentenceBuilderKidInteractor) {
        let total = sut.state.correctCount
        for slot in 0..<total {
            guard let chip = sut.state.available.first(where: { $0.order == slot }) else { continue }
            sut.pickFromAvailable(chip.id)
        }
    }

    // MARK: - Initial state

    func test_init_storesChildId() {
        let sut = makeSUT(childId: "kid-99")
        XCTAssertEqual(sut.childId, "kid-99")
    }

    func test_initialState_assembledEmpty() {
        let sut = makeSUT()
        XCTAssertTrue(sut.state.assembled.isEmpty)
    }

    func test_initialState_availableHasAllWords() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.available.count, SentenceBuilderKidModels.ViewState.correctSentence.count)
    }

    func test_initialState_correctCountEqualsSentenceLength() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.correctCount, SentenceBuilderKidModels.ViewState.correctSentence.count)
    }

    func test_initialState_notFullNotCorrect() {
        let sut = makeSUT()
        XCTAssertFalse(sut.state.isFull)
        XCTAssertFalse(sut.state.isCorrect)
    }

    // MARK: - pickFromAvailable

    func test_pick_movesChipFromAvailableToAssembled() {
        let sut = makeSUT()
        let chip = sut.state.available[0]
        sut.pickFromAvailable(chip.id)
        XCTAssertFalse(sut.state.available.contains(chip))
        XCTAssertEqual(sut.state.assembled.last, chip)
    }

    func test_pick_decrementsAvailableCount() {
        let sut = makeSUT()
        let before = sut.state.available.count
        sut.pickFromAvailable(sut.state.available[0].id)
        XCTAssertEqual(sut.state.available.count, before - 1)
    }

    func test_pick_unknownId_noChange() {
        let sut = makeSUT()
        let beforeAvailable = sut.state.available.count
        sut.pickFromAvailable(UUID())
        XCTAssertEqual(sut.state.available.count, beforeAvailable)
        XCTAssertTrue(sut.state.assembled.isEmpty)
    }

    func test_pick_correctCountStaysConstantAcrossMoves() {
        let sut = makeSUT()
        let expected = sut.state.correctCount
        sut.pickFromAvailable(sut.state.available[0].id)
        XCTAssertEqual(sut.state.correctCount, expected)
    }

    // MARK: - removeFromAssembled

    func test_remove_movesChipBackToAvailable() {
        let sut = makeSUT()
        let chip = sut.state.available[0]
        sut.pickFromAvailable(chip.id)
        sut.removeFromAssembled(chip.id)
        XCTAssertTrue(sut.state.available.contains(chip))
        XCTAssertFalse(sut.state.assembled.contains(chip))
    }

    func test_remove_unknownId_noChange() {
        let sut = makeSUT()
        sut.pickFromAvailable(sut.state.available[0].id)
        let assembledCount = sut.state.assembled.count
        sut.removeFromAssembled(UUID())
        XCTAssertEqual(sut.state.assembled.count, assembledCount)
    }

    // MARK: - isFull / isCorrect

    func test_isFull_trueWhenAllChipsAssembled() {
        let sut = makeSUT()
        while let chip = sut.state.available.first {
            sut.pickFromAvailable(chip.id)
        }
        XCTAssertTrue(sut.state.isFull)
    }

    func test_isCorrect_trueWhenAssembledInRightOrder() {
        let sut = makeSUT()
        assembleInCorrectOrder(sut)
        XCTAssertTrue(sut.state.isFull)
        XCTAssertTrue(sut.state.isCorrect)
    }

    func test_isCorrect_falseWhenAssembledInWrongOrder() {
        let sut = makeSUT()
        // Pick chips in reverse-order slots → almost certainly wrong ordering.
        let total = sut.state.correctCount
        for slot in stride(from: total - 1, through: 0, by: -1) {
            if let chip = sut.state.available.first(where: { $0.order == slot }) {
                sut.pickFromAvailable(chip.id)
            }
        }
        XCTAssertTrue(sut.state.isFull)
        XCTAssertFalse(sut.state.isCorrect, "Reversed assembly must not be marked correct")
    }

    func test_isCorrect_falseWhenPartiallyAssembled() {
        let sut = makeSUT()
        if let chip = sut.state.available.first(where: { $0.order == 0 }) {
            sut.pickFromAvailable(chip.id)
        }
        XCTAssertFalse(sut.state.isCorrect)
    }

    // MARK: - reset

    func test_reset_clearsAssembled() {
        let sut = makeSUT()
        assembleInCorrectOrder(sut)
        sut.reset()
        XCTAssertTrue(sut.state.assembled.isEmpty)
        XCTAssertEqual(sut.state.available.count, SentenceBuilderKidModels.ViewState.correctSentence.count)
    }
}
