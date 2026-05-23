@testable import HappySpeech
import XCTest

// MARK: - LiteracyStartPresenterTests

@MainActor
final class LiteracyStartPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: LiteracyStartDisplayLogic {
        var lastLetterVM: LiteracyStartModels.LoadLetter.ViewModel?
        var lastUnsupportedSound: String?

        func displayLoadLetter(viewModel: LiteracyStartModels.LoadLetter.ViewModel) async {
            lastLetterVM = viewModel
        }

        func displayUnsupportedSound(targetSound: String) async {
            lastUnsupportedSound = targetSound
        }
    }

    private func makeSUT() -> (LiteracyStartPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = LiteracyStartPresenter(displayLogic: spy)
        return (presenter, spy)
    }

    private func makeLoadLetterResponse(
        targetSound: String = "Р",
        letter: String = "Р",
        words: [WordSample] = [WordSample(text: "Рак", assetName: "word_rak")]
    ) -> LiteracyStartModels.LoadLetter.Response {
        LiteracyStartModels.LoadLetter.Response(
            targetSound: targetSound,
            letter: letter,
            words: words
        )
    }

    // MARK: - presentLoadLetter

    func test_presentLoadLetter_callsDisplay() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoadLetter(response: makeLoadLetterResponse())
        XCTAssertNotNil(spy.lastLetterVM)
    }

    func test_presentLoadLetter_letterPassedThrough() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoadLetter(response: makeLoadLetterResponse(letter: "Ш"))
        XCTAssertEqual(spy.lastLetterVM?.letter, "Ш")
    }

    func test_presentLoadLetter_titleTextIsNonEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoadLetter(response: makeLoadLetterResponse())
        XCTAssertFalse(spy.lastLetterVM?.titleText.isEmpty ?? true)
    }

    func test_presentLoadLetter_accessibilityLabelContainsWordText() async {
        let (sut, spy) = makeSUT()
        let words = [
            WordSample(text: "Рак", assetName: "word_rak"),
            WordSample(text: "Роза", assetName: "word_roza")
        ]
        await sut.presentLoadLetter(response: makeLoadLetterResponse(words: words))
        let a11y = spy.lastLetterVM?.accessibilityLabel ?? ""
        XCTAssertTrue(a11y.contains("Рак"))
        XCTAssertTrue(a11y.contains("Роза"))
    }

    func test_presentLoadLetter_buttonsHaveTitles() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoadLetter(response: makeLoadLetterResponse())
        XCTAssertFalse(spy.lastLetterVM?.traceButtonTitle.isEmpty ?? true)
        XCTAssertFalse(spy.lastLetterVM?.listenButtonTitle.isEmpty ?? true)
    }

    func test_presentLoadLetter_wordsPassedThrough() async {
        let (sut, spy) = makeSUT()
        let words = [WordSample(text: "Сок", assetName: "word_sok")]
        await sut.presentLoadLetter(response: makeLoadLetterResponse(words: words))
        XCTAssertEqual(spy.lastLetterVM?.words.count, 1)
        XCTAssertEqual(spy.lastLetterVM?.words.first?.text, "Сок")
    }

    // MARK: - presentUnsupportedSound

    func test_presentUnsupportedSound_callsDisplay() async {
        let (sut, spy) = makeSUT()
        await sut.presentUnsupportedSound(targetSound: "X")
        XCTAssertEqual(spy.lastUnsupportedSound, "X")
    }

    func test_presentUnsupportedSound_doesNotCallLetterDisplay() async {
        let (sut, spy) = makeSUT()
        await sut.presentUnsupportedSound(targetSound: "unknown")
        XCTAssertNil(spy.lastLetterVM)
    }
}
