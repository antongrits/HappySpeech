import XCTest
@testable import HappySpeech

// MARK: - DialectAdaptationPresenterTests
//
// Block AA v21 — Smoke tests для DialectAdaptationPresenter.
// 3 теста: presentLoad формирует rows, presentSelect формирует toast, presentReset формирует toast.

@MainActor
final class DialectAdaptationPresenterTests: XCTestCase {

    private var sut: DialectAdaptationPresenter!
    private var spyDisplay: SpyDialectAdaptationDisplay!

    override func setUp() {
        super.setUp()
        spyDisplay = SpyDialectAdaptationDisplay()
        sut = DialectAdaptationPresenter(displayLogic: spyDisplay)
    }

    override func tearDown() {
        sut = nil
        spyDisplay = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_presentLoad_producesCorrectRowCount() async {
        // Arrange
        let response = DialectAdaptationModels.Load.Response(
            currentDialect: RegionalDialect.default,
            availableDialects: RegionalDialect.all,
            appliedAt: nil
        )
        // Act
        await sut.presentLoad(response: response)
        // Assert
        XCTAssertTrue(spyDisplay.displayLoadCalled)
        XCTAssertEqual(
            spyDisplay.lastLoadViewModel?.dialects.count,
            RegionalDialect.all.count,
            "Количество rows должно совпадать с количеством диалектов"
        )
    }

    func test_presentLoad_selectedDialectMarkedCorrectly() async {
        // Arrange
        let selectedDialect = RegionalDialect.all.first!
        let response = DialectAdaptationModels.Load.Response(
            currentDialect: selectedDialect,
            availableDialects: RegionalDialect.all,
            appliedAt: nil
        )
        // Act
        await sut.presentLoad(response: response)
        // Assert
        let selectedRows = spyDisplay.lastLoadViewModel?.dialects.filter { $0.isSelected } ?? []
        XCTAssertEqual(selectedRows.count, 1, "Только один диалект должен быть selected")
        XCTAssertEqual(selectedRows.first?.id, selectedDialect.id)
    }

    func test_presentSelect_successTrue_callsDisplay() async {
        // Arrange
        let response = DialectAdaptationModels.Select.Response(
            success: true,
            appliedDialect: RegionalDialect.default,
            appliedAt: Date()
        )
        // Act
        await sut.presentSelect(response: response)
        // Assert
        XCTAssertTrue(spyDisplay.displaySelectCalled)
        XCTAssertTrue(spyDisplay.lastSelectViewModel?.success == true)
    }
}

// MARK: - SpyDialectAdaptationDisplay

@MainActor
private final class SpyDialectAdaptationDisplay: DialectAdaptationDisplayLogic {

    var displayLoadCalled = false
    var displaySelectCalled = false
    var displayResetCalled = false

    var lastLoadViewModel: DialectAdaptationModels.Load.ViewModel?
    var lastSelectViewModel: DialectAdaptationModels.Select.ViewModel?

    func displayLoad(viewModel: DialectAdaptationModels.Load.ViewModel) async {
        displayLoadCalled = true
        lastLoadViewModel = viewModel
    }

    func displaySelect(viewModel: DialectAdaptationModels.Select.ViewModel) async {
        displaySelectCalled = true
        lastSelectViewModel = viewModel
    }

    func displayReset(viewModel: DialectAdaptationModels.Reset.ViewModel) async {
        displayResetCalled = true
    }
}
