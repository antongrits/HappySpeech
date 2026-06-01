@testable import HappySpeech
import XCTest

// MARK: - SoundDoctorKidInteractorTests
//
// SoundDoctorKidInteractor загружает случаи из методического контента под
// рабочие звуки ребёнка и считает «вылеченные» звуки. Без репозитория грузится
// базовый набор; choose() корректно продвигает игру.

@MainActor
final class SoundDoctorKidInteractorTests: XCTestCase {

    private func makeSUT(childId: String = "child-1") -> SoundDoctorKidInteractor {
        SoundDoctorKidInteractor(childId: childId)
    }

    func test_init_storesChildId() {
        let sut = makeSUT(childId: "kid-7")
        XCTAssertEqual(sut.childId, "kid-7")
    }

    func test_load_populatesCases() async {
        let sut = makeSUT()
        await sut.load()
        XCTAssertTrue(sut.state.isLoaded)
        XCTAssertFalse(sut.state.cases.isEmpty)
        XCTAssertEqual(sut.state.currentCaseIndex, 0)
        XCTAssertEqual(sut.state.cured, 0)
    }

    func test_eachCaseHasExactlyOneCorrectOption() async {
        let sut = makeSUT()
        await sut.load()
        for kase in sut.state.cases {
            XCTAssertEqual(kase.options.filter(\.isCorrect).count, 1,
                           "Case \(kase.id) must have exactly one correct option")
        }
    }

    func test_choose_correct_incrementsCuredAndAdvances() async {
        let sut = makeSUT()
        await sut.load()
        let kase = sut.state.currentCase!
        let correct = kase.options.first { $0.isCorrect }!.id
        let ok = sut.choose(correct)
        XCTAssertTrue(ok)
        XCTAssertEqual(sut.state.cured, 1)
        XCTAssertEqual(sut.state.currentCaseIndex, 1)
    }

    func test_choose_wrong_advancesWithoutCuring() async {
        let sut = makeSUT()
        await sut.load()
        let kase = sut.state.currentCase!
        let wrong = kase.options.first { !$0.isCorrect }!.id
        let ok = sut.choose(wrong)
        XCTAssertFalse(ok)
        XCTAssertEqual(sut.state.cured, 0)
        XCTAssertEqual(sut.state.currentCaseIndex, 1)
    }

    func test_choose_unknownOption_noop() async {
        let sut = makeSUT()
        await sut.load()
        XCTAssertFalse(sut.choose("does-not-exist"))
        XCTAssertEqual(sut.state.currentCaseIndex, 0)
        XCTAssertEqual(sut.state.cured, 0)
    }

    func test_playThrough_marksComplete() async {
        let sut = makeSUT()
        await sut.load()
        let total = sut.state.cases.count
        for _ in 0..<total {
            let correct = sut.state.currentCase!.options.first { $0.isCorrect }!.id
            sut.choose(correct)
        }
        XCTAssertTrue(sut.state.isComplete)
        XCTAssertEqual(sut.state.cured, total)
        XCTAssertNil(sut.state.currentCase)
        // Лишний choose после конца — no-op.
        XCTAssertFalse(sut.choose("anything"))
        XCTAssertEqual(sut.state.currentCaseIndex, total)
    }

    func test_reset_restartsGame() async {
        let sut = makeSUT()
        await sut.load()
        sut.choose(sut.state.currentCase!.options[0].id)
        sut.reset()
        XCTAssertEqual(sut.state.currentCaseIndex, 0)
        XCTAssertEqual(sut.state.cured, 0)
    }

    func test_content_filtersByTargetSound() {
        let cases = SoundDoctorKidContent.cases(forTargetSounds: ["Ш"], limit: 4)
        XCTAssertEqual(cases.first?.sound, "Ш")
    }

    func test_currentCase_isNilWhenIndexOutOfBounds() {
        var state = SoundDoctorKidModels.ViewState.initial
        state.cases = SoundDoctorKidContent.all
        state.currentCaseIndex = state.cases.count
        XCTAssertNil(state.currentCase)
    }
}
