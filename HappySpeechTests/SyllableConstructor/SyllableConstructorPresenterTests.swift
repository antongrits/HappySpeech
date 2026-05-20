@testable import HappySpeech
import XCTest

// MARK: - Spy Display

@MainActor
private final class SpySyllableDisplay: SyllableConstructorDisplayLogic, @unchecked Sendable {
    var startVM: SyllableConstructorModels.Start.ViewModel?
    var submitVM: SyllableConstructorModels.SubmitGuess.ViewModel?

    func displayStart(viewModel: SyllableConstructorModels.Start.ViewModel) async {
        startVM = viewModel
    }
    func displaySubmit(viewModel: SyllableConstructorModels.SubmitGuess.ViewModel) async {
        submitVM = viewModel
    }
}

// MARK: - Presenter Tests

@MainActor
final class SyllableConstructorPresenterTests: XCTestCase {

    private func makeResponse(tiles: [SyllableTile] = [
        SyllableTile(id: "t1", text: "ма"),
        SyllableTile(id: "t2", text: "ма")
    ]) -> SyllableConstructorModels.Start.Response {
        let word = SyllableWord(
            id: "w1",
            word: "мама",
            syllables: ["ма", "ма"],
            tier: .oneSyllableOpen,
            symbolName: "person.fill"
        )
        return .init(
            tier: .oneSyllableOpen,
            word: word,
            shuffledTiles: tiles,
            availableTiers: [.oneSyllableOpen, .twoSyllablesOpen],
            totalWordsInTier: 5,
            wordIndex: 1
        )
    }

    func test_presentStart_buildsViewModel() async {
        let spy = SpySyllableDisplay()
        let presenter = SyllableConstructorPresenter(displayLogic: spy)
        await presenter.presentStart(response: makeResponse())
        XCTAssertNotNil(spy.startVM)
        XCTAssertEqual(spy.startVM?.wordLabel, "мама")
        XCTAssertEqual(spy.startVM?.placeholdersCount, 2)
        XCTAssertEqual(spy.startVM?.tiles.count, 2)
        XCTAssertEqual(spy.startVM?.symbolName, "person.fill")
    }

    func test_presentStart_includesAllAvailableTiers() async {
        let spy = SpySyllableDisplay()
        let presenter = SyllableConstructorPresenter(displayLogic: spy)
        await presenter.presentStart(response: makeResponse())
        XCTAssertEqual(spy.startVM?.availableTiers.count, 2)
        XCTAssertEqual(spy.startVM?.availableTiers.first?.isSelected, true)
        XCTAssertEqual(spy.startVM?.availableTiers.last?.isSelected, false)
    }

    func test_presentSubmit_correct_buildsCorrectViewModel() async {
        let spy = SpySyllableDisplay()
        let presenter = SyllableConstructorPresenter(displayLogic: spy)
        await presenter.presentSubmit(response: .init(
            isCorrect: true,
            assembled: "мама",
            expected: "мама"
        ))
        XCTAssertEqual(spy.submitVM?.isCorrect, true)
        XCTAssertEqual(spy.submitVM?.assembled, "мама")
    }

    func test_presentSubmit_wrong_buildsWrongViewModel() async {
        let spy = SpySyllableDisplay()
        let presenter = SyllableConstructorPresenter(displayLogic: spy)
        await presenter.presentSubmit(response: .init(
            isCorrect: false,
            assembled: "амам",
            expected: "мама"
        ))
        XCTAssertEqual(spy.submitVM?.isCorrect, false)
        XCTAssertEqual(spy.submitVM?.assembled, "амам")
    }

    func test_localized_returnsKeyIfMissing() {
        let result = SyllableConstructorPresenter.localized("absolutely.missing.key.does.not.exist")
        // Когда ключ не найден, Bundle.main.localizedString возвращает сам ключ.
        XCTAssertEqual(result, "absolutely.missing.key.does.not.exist")
    }
}
