import XCTest
@testable import HappySpeech

// MARK: - ARFaceFilterPresenterTests
//
// Phase 2.6 batch 3 — покрытие ARFaceFilterPresenter (0% → цель ≥90%).

@MainActor
final class ARFaceFilterPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: ARFaceFilterDisplayLogic {
        var setMaskVM: ARFaceFilterModels.SetMask.ViewModel?
        var triggerVM: ARFaceFilterModels.Trigger.ViewModel?

        func displaySetMask(viewModel: ARFaceFilterModels.SetMask.ViewModel) async {
            setMaskVM = viewModel
        }
        func displayTrigger(viewModel: ARFaceFilterModels.Trigger.ViewModel) async {
            triggerVM = viewModel
        }
    }

    private func makeSUT() -> (ARFaceFilterPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let sut = ARFaceFilterPresenter(displayLogic: spy)
        return (sut, spy)
    }

    // MARK: - presentSetMask

    func test_presentSetMask_kitten_triggerWordIsKot() async {
        let (sut, spy) = makeSUT()
        await sut.presentSetMask(mask: .kitten)
        XCTAssertNotNil(spy.setMaskVM)
        XCTAssertEqual(spy.setMaskVM?.mask, .kitten)
        XCTAssertEqual(spy.setMaskVM?.triggerWord, "кот")
        XCTAssertFalse(spy.setMaskVM?.promptText.isEmpty ?? true)
    }

    func test_presentSetMask_fox_triggerWordIsLisa() async {
        let (sut, spy) = makeSUT()
        await sut.presentSetMask(mask: .fox)
        XCTAssertEqual(spy.setMaskVM?.triggerWord, "лиса")
        XCTAssertEqual(spy.setMaskVM?.mask, .fox)
    }

    func test_presentSetMask_crown_triggerWordIsKorona() async {
        let (sut, spy) = makeSUT()
        await sut.presentSetMask(mask: .crown)
        XCTAssertEqual(spy.setMaskVM?.triggerWord, "корона")
    }

    func test_presentSetMask_ushanka_triggerWordIsShapka() async {
        let (sut, spy) = makeSUT()
        await sut.presentSetMask(mask: .ushanka)
        XCTAssertEqual(spy.setMaskVM?.triggerWord, "шапка")
    }

    func test_presentSetMask_glasses_triggerWordIsOchki() async {
        let (sut, spy) = makeSUT()
        await sut.presentSetMask(mask: .glasses)
        XCTAssertEqual(spy.setMaskVM?.triggerWord, "очки")
    }

    func test_presentSetMask_allMasks_promptTextNotEmpty() async {
        let (sut, spy) = makeSUT()
        for mask in FaceMaskKind.allCases {
            await sut.presentSetMask(mask: mask)
            // Prompt собирается через String(localized:) — не пустой
            XCTAssertNotNil(spy.setMaskVM?.promptText, "Prompt для маски \(mask.rawValue) не должен быть nil")
        }
    }

    // MARK: - presentTrigger

    func test_presentTrigger_matched_isMatchedTrue_celebrationNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentTrigger(
            response: .init(isMatched: true, matchedWord: "кот"),
            mask: .kitten
        )
        XCTAssertNotNil(spy.triggerVM)
        XCTAssertTrue(spy.triggerVM?.isMatched == true)
        XCTAssertFalse(spy.triggerVM?.celebrationText.isEmpty ?? true)
    }

    func test_presentTrigger_notMatched_isMatchedFalse_celebrationEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentTrigger(
            response: .init(isMatched: false, matchedWord: ""),
            mask: .kitten
        )
        XCTAssertFalse(spy.triggerVM?.isMatched ?? true)
        XCTAssertTrue(spy.triggerVM?.celebrationText.isEmpty == true)
    }

    func test_presentTrigger_matched_celebrationNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentTrigger(
            response: .init(isMatched: true, matchedWord: "корона"),
            mask: .crown
        )
        // celebrationText строится через String(localized:format:) — не пустая при isMatched=true
        XCTAssertNotNil(spy.triggerVM?.celebrationText)
    }

    func test_presentTrigger_nilDisplayLogic_doesNotCrash() async {
        let sut = ARFaceFilterPresenter(displayLogic: nil)
        // Не должно крашиться при nil displayLogic
        await sut.presentSetMask(mask: .fox)
        await sut.presentTrigger(response: .init(isMatched: true, matchedWord: "лиса"), mask: .fox)
    }
}
