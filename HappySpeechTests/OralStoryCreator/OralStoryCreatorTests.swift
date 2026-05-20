@testable import HappySpeech
import XCTest

// MARK: - Spy

@MainActor
private final class SpyStoryDisplay: OralStoryCreatorDisplayLogic, @unchecked Sendable {

    var loadVM: OralStoryCreatorModels.LoadStimuli.ViewModel?
    var selectVM: OralStoryCreatorModels.Select.ViewModel?
    var resultVM: OralStoryCreatorModels.RecordResult.ViewModel?

    func displayLoadStimuli(viewModel: OralStoryCreatorModels.LoadStimuli.ViewModel) async {
        loadVM = viewModel
    }
    func displaySelect(viewModel: OralStoryCreatorModels.Select.ViewModel) async {
        selectVM = viewModel
    }
    func displayRecordResult(viewModel: OralStoryCreatorModels.RecordResult.ViewModel) async {
        resultVM = viewModel
    }
}

// MARK: - LexicalDiversityCalculatorTests

final class LexicalDiversityCalculatorTests: XCTestCase {

    func test_empty_string_returns_zero_ttr() {
        let calc = LexicalDiversityCalculator()
        let result = calc.analyse(transcript: "")
        XCTAssertEqual(result.total, 0)
        XCTAssertEqual(result.unique, 0)
        XCTAssertEqual(result.ttr, 0)
    }

    func test_all_unique_words_gives_ttr_one() {
        let calc = LexicalDiversityCalculator()
        let result = calc.analyse(transcript: "мама папа сын дочь")
        XCTAssertEqual(result.total, 4)
        XCTAssertEqual(result.unique, 4)
        XCTAssertEqual(result.ttr, 1.0, accuracy: 0.01)
    }

    func test_repeated_words_lower_ttr() {
        let calc = LexicalDiversityCalculator()
        let result = calc.analyse(transcript: "мама мама мама")
        XCTAssertEqual(result.total, 3)
        XCTAssertEqual(result.unique, 1)
        XCTAssertEqual(result.ttr, 1.0 / 3.0, accuracy: 0.01)
    }

    func test_punctuation_is_stripped() {
        let calc = LexicalDiversityCalculator()
        let result = calc.analyse(transcript: "Мама, папа! Сын... дочь?")
        XCTAssertEqual(result.unique, 4)
    }

    func test_case_insensitive() {
        let calc = LexicalDiversityCalculator()
        let result = calc.analyse(transcript: "Мама мама МАМА")
        XCTAssertEqual(result.unique, 1)
        XCTAssertEqual(result.total, 3)
    }

    func test_tokenise_returns_clean_word_list() {
        let calc = LexicalDiversityCalculator()
        let words = calc.tokenise("Мяч, мяч и мячик.")
        XCTAssertEqual(words.sorted(), ["и", "мяч", "мяч", "мячик"])
    }
}

// MARK: - Corpus tests

final class OralStoryCreatorCorpusTests: XCTestCase {

    func test_stimuli_loaded_or_fallback() {
        XCTAssertGreaterThanOrEqual(OralStoryCreatorCorpus.stimuli.count, 4)
    }

    func test_grouped_categories_match_order() {
        let grouped = OralStoryCreatorCorpus.grouped()
        XCTAssertEqual(grouped.first?.category,
                       OralStoryCreatorCorpus.categoriesInOrder.first)
    }
}

// MARK: - Interactor tests

@MainActor
final class OralStoryCreatorInteractorTests: XCTestCase {

    private func makeSUT() -> (OralStoryCreatorInteractor, SpyStoryDisplay) {
        let container = AppContainer.preview()
        let display = SpyStoryDisplay()
        let presenter = OralStoryCreatorPresenter(displayLogic: display)
        let interactor = OralStoryCreatorInteractor(
            presenter: presenter,
            audioService: container.audioService,
            asrService: container.asrService,
            realmActor: container.realmActor,
            childId: "test-child"
        )
        return (interactor, display)
    }

    func test_loadStimuli_presentsViewModel() async {
        let (sut, display) = makeSUT()
        await sut.loadStimuli()
        XCTAssertNotNil(display.loadVM)
        XCTAssertEqual(display.loadVM?.pickCountTarget, 3)
        XCTAssertNotNil(display.selectVM)
    }

    func test_toggleSelection_appendsThenRemoves() async {
        let (sut, display) = makeSUT()
        await sut.loadStimuli()
        await sut.toggleSelection("h_01")
        XCTAssertEqual(display.selectVM?.selectedIds, ["h_01"])
        await sut.toggleSelection("h_01")
        XCTAssertTrue(display.selectVM?.selectedIds.isEmpty ?? false)
    }

    func test_toggleSelection_capsAtThree() async {
        let (sut, display) = makeSUT()
        await sut.loadStimuli()
        for id in ["a", "b", "c", "d"] {
            await sut.toggleSelection(id)
        }
        XCTAssertEqual(display.selectVM?.selectedIds.count, 3)
        XCTAssertEqual(display.selectVM?.canStartRecording, true)
    }

    func test_resetSelection_clearsSelection() async {
        let (sut, _) = makeSUT()
        await sut.loadStimuli()
        await sut.toggleSelection("h_01")
        await sut.resetSelection()
        XCTAssertTrue(sut.selectedIds.isEmpty)
    }

    func test_saveStory_persistsAndReturnsData() async {
        let (sut, _) = makeSUT()
        await sut.loadStimuli()
        await sut.toggleSelection("h_01")
        let data = await sut.saveStory(transcript: "мама папа кошка мама", duration: 12.5)
        XCTAssertEqual(data.totalWords, 4)
        XCTAssertEqual(data.uniqueWords, 3)
        XCTAssertEqual(data.lexicalDiversity, 0.75, accuracy: 0.01)
    }
}
