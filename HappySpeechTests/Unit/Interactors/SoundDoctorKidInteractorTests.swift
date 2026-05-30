@testable import HappySpeech
import XCTest

// MARK: - SoundDoctorKidInteractorTests
//
// SoundDoctorKidInteractor is a thin VIP MVP variant (@Observable). Tests cover
// choose() correctness scoring, case advancement (clamped at end), reset() and
// the currentCase computed property edge-cases.

@MainActor
final class SoundDoctorKidInteractorTests: XCTestCase {

    private func makeSUT(childId: String = "child-1") -> SoundDoctorKidInteractor {
        SoundDoctorKidInteractor(childId: childId)
    }

    // MARK: - Initial state

    func test_init_storesChildId() {
        let sut = makeSUT(childId: "kid-7")
        XCTAssertEqual(sut.childId, "kid-7")
    }

    func test_initialState_matchesInitial() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state, .initial)
    }

    func test_initialState_curedIsZero() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.cured, 0)
    }

    func test_initialState_currentCaseIsFirst() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.currentCase?.id, 0)
        XCTAssertEqual(sut.state.currentCase?.brokenSound, "Р")
    }

    func test_initialState_eachCaseHasExactlyOneCorrectOption() {
        let sut = makeSUT()
        for kase in sut.state.cases {
            XCTAssertEqual(kase.options.filter(\.isCorrect).count, 1,
                           "Case \(kase.id) must have exactly one correct option")
        }
    }

    // MARK: - choose: correct

    func test_choose_correctOption_returnsTrue() {
        let sut = makeSUT()
        let correctId = sut.state.currentCase!.options.first(where: \.isCorrect)!.id
        XCTAssertTrue(sut.choose(correctId))
    }

    func test_choose_correctOption_incrementsCured() {
        let sut = makeSUT()
        let correctId = sut.state.currentCase!.options.first(where: \.isCorrect)!.id
        sut.choose(correctId)
        XCTAssertEqual(sut.state.cured, 1)
    }

    func test_choose_correctOption_advancesToNextCase() {
        let sut = makeSUT()
        let correctId = sut.state.currentCase!.options.first(where: \.isCorrect)!.id
        sut.choose(correctId)
        XCTAssertEqual(sut.state.currentCaseIndex, 1)
        XCTAssertEqual(sut.state.currentCase?.id, 1)
    }

    // MARK: - choose: wrong

    func test_choose_wrongOption_returnsFalse() {
        let sut = makeSUT()
        let wrongId = sut.state.currentCase!.options.first(where: { !$0.isCorrect })!.id
        XCTAssertFalse(sut.choose(wrongId))
    }

    func test_choose_wrongOption_doesNotIncrementCured() {
        let sut = makeSUT()
        let wrongId = sut.state.currentCase!.options.first(where: { !$0.isCorrect })!.id
        sut.choose(wrongId)
        XCTAssertEqual(sut.state.cured, 0)
    }

    func test_choose_wrongOption_stillAdvances() {
        let sut = makeSUT()
        let wrongId = sut.state.currentCase!.options.first(where: { !$0.isCorrect })!.id
        sut.choose(wrongId)
        XCTAssertEqual(sut.state.currentCaseIndex, 1)
    }

    // MARK: - choose: invalid

    func test_choose_unknownOptionId_returnsFalseAndNoChange() {
        let sut = makeSUT()
        XCTAssertFalse(sut.choose("does-not-exist"))
        XCTAssertEqual(sut.state.currentCaseIndex, 0)
        XCTAssertEqual(sut.state.cured, 0)
    }

    func test_choose_pastLastCase_returnsFalseAndDoesNotOverflow() {
        let sut = makeSUT()
        let caseCount = sut.state.cases.count
        // Advance through every case picking the correct option each time.
        for _ in 0..<caseCount {
            if let id = sut.state.currentCase?.options.first(where: \.isCorrect)?.id {
                sut.choose(id)
            }
        }
        XCTAssertNil(sut.state.currentCase)
        XCTAssertEqual(sut.state.currentCaseIndex, caseCount)
        // One more choose with currentCase == nil is a no-op.
        XCTAssertFalse(sut.choose("anything"))
        XCTAssertEqual(sut.state.currentCaseIndex, caseCount, "index must not exceed cases.count")
    }

    func test_choose_allCorrect_curesEveryCase() {
        let sut = makeSUT()
        let caseCount = sut.state.cases.count
        for _ in 0..<caseCount {
            if let id = sut.state.currentCase?.options.first(where: \.isCorrect)?.id {
                sut.choose(id)
            }
        }
        XCTAssertEqual(sut.state.cured, caseCount)
    }

    // MARK: - reset

    func test_reset_restoresInitialState() {
        let sut = makeSUT()
        let correctId = sut.state.currentCase!.options.first(where: \.isCorrect)!.id
        sut.choose(correctId)
        sut.reset()
        XCTAssertEqual(sut.state, .initial)
    }

    // MARK: - currentCase edge-case

    func test_currentCase_isNilWhenIndexOutOfBounds() {
        var state = SoundDoctorKidModels.ViewState.initial
        state.currentCaseIndex = state.cases.count
        XCTAssertNil(state.currentCase)
    }
}
