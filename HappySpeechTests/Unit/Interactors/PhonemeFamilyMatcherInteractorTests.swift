@testable import HappySpeech
import XCTest

// MARK: - PhonemeFamilyMatcherInteractorTests
//
// PhonemeFamilyMatcherInteractor is a thin VIP MVP variant (@Observable).
// assign() tags a word with a chosen family; matchedCount counts words whose
// assignment equals their true family. Tests cover assignment, scoring,
// reassignment, the unknown-id guard and reset().

@MainActor
final class PhonemeFamilyMatcherInteractorTests: XCTestCase {

    private func makeSUT(childId: String = "child-1") -> PhonemeFamilyMatcherInteractor {
        PhonemeFamilyMatcherInteractor(childId: childId)
    }

    private func word(_ sut: PhonemeFamilyMatcherInteractor, id: String) -> PhonemeFamilyMatcherModels.Word {
        sut.state.words.first { $0.id == id }!
    }

    // MARK: - Initial state

    func test_init_storesChildId() {
        let sut = makeSUT(childId: "kid-phoneme")
        XCTAssertEqual(sut.childId, "kid-phoneme")
    }

    func test_initialState_matchesInitial() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state, .initial)
    }

    func test_initialState_nothingAssigned() {
        let sut = makeSUT()
        XCTAssertTrue(sut.state.words.allSatisfy { $0.assignedFamily == nil })
    }

    func test_initialState_matchedCountZero() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.matchedCount, 0)
    }

    func test_initialState_hasTwelveWords() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.words.count, 12)
    }

    func test_initialState_coversAllFourFamilies() {
        let sut = makeSUT()
        let families = Set(sut.state.words.map(\.family))
        XCTAssertEqual(families, Set(PhonemeFamilyMatcherModels.Family.allCases))
    }

    // MARK: - assign

    func test_assign_setsAssignedFamily() {
        let sut = makeSUT()
        sut.assign("w1", to: .whistling)
        XCTAssertEqual(word(sut, id: "w1").assignedFamily, .whistling)
    }

    func test_assign_correctFamily_incrementsMatchedCount() {
        let sut = makeSUT()
        let target = word(sut, id: "w1").family
        sut.assign("w1", to: target)
        XCTAssertEqual(sut.state.matchedCount, 1)
    }

    func test_assign_wrongFamily_doesNotCountAsMatch() {
        let sut = makeSUT()
        let actual = word(sut, id: "w1").family   // whistling
        let wrong = PhonemeFamilyMatcherModels.Family.allCases.first { $0 != actual }!
        sut.assign("w1", to: wrong)
        XCTAssertEqual(sut.state.matchedCount, 0)
    }

    func test_assign_reassign_overwritesPrevious() {
        let sut = makeSUT()
        sut.assign("w4", to: .whistling)   // wrong (w4 is hissing)
        sut.assign("w4", to: .hissing)     // correct
        XCTAssertEqual(word(sut, id: "w4").assignedFamily, .hissing)
        XCTAssertEqual(sut.state.matchedCount, 1)
    }

    func test_assign_unknownId_noChange() {
        let sut = makeSUT()
        sut.assign("nope", to: .velar)
        XCTAssertEqual(sut.state.matchedCount, 0)
        XCTAssertTrue(sut.state.words.allSatisfy { $0.assignedFamily == nil })
    }

    func test_assign_allCorrect_matchedCountEqualsWordCount() {
        let sut = makeSUT()
        for w in sut.state.words {
            sut.assign(w.id, to: w.family)
        }
        XCTAssertEqual(sut.state.matchedCount, sut.state.words.count)
    }

    func test_assign_doesNotAffectOtherWords() {
        let sut = makeSUT()
        sut.assign("w1", to: .whistling)
        for w in sut.state.words where w.id != "w1" {
            XCTAssertNil(w.assignedFamily, "Word \(w.id) should stay unassigned")
        }
    }

    // MARK: - reset

    func test_reset_clearsAllAssignments() {
        let sut = makeSUT()
        sut.assign("w1", to: .whistling)
        sut.assign("w7", to: .sonorant)
        sut.reset()
        XCTAssertEqual(sut.state, .initial)
        XCTAssertEqual(sut.state.matchedCount, 0)
    }
}
