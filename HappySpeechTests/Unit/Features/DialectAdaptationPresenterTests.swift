@testable import HappySpeech
import XCTest

// MARK: - DialectAdaptationPresenterTests
//
// Block V v18 — покрытие DialectAdaptationPresenter (5 тестов).
// Тестируются все три метода presentationLogic через DisplaySpy.

@MainActor
final class DialectAdaptationPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: DialectAdaptationDisplayLogic {
        var loadVM: DialectAdaptationModels.Load.ViewModel?
        var selectVM: DialectAdaptationModels.Select.ViewModel?
        var resetVM: DialectAdaptationModels.Reset.ViewModel?

        func displayLoad(viewModel: DialectAdaptationModels.Load.ViewModel) async {
            loadVM = viewModel
        }
        func displaySelect(viewModel: DialectAdaptationModels.Select.ViewModel) async {
            selectVM = viewModel
        }
        func displayReset(viewModel: DialectAdaptationModels.Reset.ViewModel) async {
            resetVM = viewModel
        }
    }

    private func makeSUT() -> (DialectAdaptationPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = DialectAdaptationPresenter(displayLogic: spy)
        return (presenter, spy)
    }

    // MARK: - presentLoad

    func test_presentLoad_callsDisplayLoad_withAllDialects() async {
        let (sut, spy) = makeSUT()
        let moscow = RegionalDialect.all[0]
        let response = DialectAdaptationModels.Load.Response(
            currentDialect: moscow,
            availableDialects: RegionalDialect.all,
            appliedAt: nil
        )
        await sut.presentLoad(response: response)
        XCTAssertNotNil(spy.loadVM)
        XCTAssertEqual(spy.loadVM?.dialects.count, RegionalDialect.all.count)
    }

    func test_presentLoad_selectedDialect_isMarkedIsSelected() async {
        let (sut, spy) = makeSUT()
        let central = RegionalDialect.default
        let response = DialectAdaptationModels.Load.Response(
            currentDialect: central,
            availableDialects: RegionalDialect.all,
            appliedAt: nil
        )
        await sut.presentLoad(response: response)
        let selectedRow = spy.loadVM?.dialects.first { $0.isSelected }
        XCTAssertNotNil(selectedRow)
        XCTAssertEqual(selectedRow?.id, central.id)
    }

    func test_presentLoad_withAppliedAt_setsAppliedAtText() async {
        let (sut, spy) = makeSUT()
        let past = Date(timeIntervalSinceNow: -3600)
        let response = DialectAdaptationModels.Load.Response(
            currentDialect: RegionalDialect.default,
            availableDialects: RegionalDialect.all,
            appliedAt: past
        )
        await sut.presentLoad(response: response)
        XCTAssertNotNil(spy.loadVM?.appliedAtText)
    }

    // MARK: - presentSelect

    func test_presentSelect_callsDisplaySelect_withToastMessage() async {
        let (sut, spy) = makeSUT()
        let dialect = RegionalDialect.all[1]
        let response = DialectAdaptationModels.Select.Response(
            success: true,
            appliedDialect: dialect,
            appliedAt: Date()
        )
        await sut.presentSelect(response: response)
        XCTAssertNotNil(spy.selectVM)
        XCTAssertFalse(spy.selectVM?.toastMessage.isEmpty ?? true)
        XCTAssertTrue(spy.selectVM?.success ?? false)
    }

    // MARK: - presentReset

    func test_presentReset_callsDisplayReset_withToastMessage() async {
        let (sut, spy) = makeSUT()
        let response = DialectAdaptationModels.Reset.Response(
            restored: RegionalDialect.default
        )
        await sut.presentReset(response: response)
        XCTAssertNotNil(spy.resetVM)
        XCTAssertFalse(spy.resetVM?.toastMessage.isEmpty ?? true)
    }
}
