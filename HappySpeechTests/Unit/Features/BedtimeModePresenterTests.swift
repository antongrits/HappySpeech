@testable import HappySpeech
import XCTest

// MARK: - BedtimeModePresenterTests
//
// Verifies the Response → ViewModel mapping in the bedtime-mode presenter:
//   - Start: story title/text routed from response.story
//   - Start: library count label formatted (non-empty) from storiesCountInLibrary
//   - Start: localized chrome strings (title/intro/breathing/farewell) non-empty
//   - Start: breathing cycle passed through unchanged
//   - Advance: stage forwarded verbatim
//   - NewStory: reuses same VM builder → story fields routed

@MainActor
final class BedtimeModePresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: BedtimeModeDisplayLogic {
        var startVM: BedtimeModeModels.Start.ViewModel?
        var newStoryVM: BedtimeModeModels.Start.ViewModel?
        var advancedStage: BedtimeStage?

        func displayStart(viewModel: BedtimeModeModels.Start.ViewModel) async { startVM = viewModel }
        func displayAdvance(stage: BedtimeStage) async { advancedStage = stage }
        func displayNewStory(viewModel: BedtimeModeModels.Start.ViewModel) async { newStoryVM = viewModel }
    }

    private func makeSUT() -> (BedtimeModePresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = BedtimeModePresenter(displayLogic: spy)
        return (presenter, spy)
    }

    private func response(
        storyTitle: String = "Лунная история",
        storyText: String = "Жила-была луна...",
        count: Int = 4,
        breathing: BedtimeBreathingCycle = BedtimeBreathingCycle()
    ) -> BedtimeModeModels.Start.Response {
        .init(
            story: BedtimeStory(id: "s1", title: storyTitle, text: storyText),
            breathing: breathing,
            storiesCountInLibrary: count
        )
    }

    // MARK: - Start

    func test_start_routesStoryFields() async {
        let (sut, spy) = makeSUT()
        await sut.presentStart(response: response(storyTitle: "Звёзды", storyText: "Текст истории"))
        XCTAssertEqual(spy.startVM?.storyTitle, "Звёзды")
        XCTAssertEqual(spy.startVM?.storyText, "Текст истории")
    }

    func test_start_countLabelNonEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentStart(response: response(count: 7))
        XCTAssertFalse(spy.startVM?.storiesCountLabel.isEmpty ?? true)
    }

    func test_start_chromeStringsNonEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentStart(response: response())
        XCTAssertFalse(spy.startVM?.title.isEmpty ?? true)
        XCTAssertFalse(spy.startVM?.introMessage.isEmpty ?? true)
        XCTAssertFalse(spy.startVM?.breathingTitle.isEmpty ?? true)
        XCTAssertFalse(spy.startVM?.breathingHint.isEmpty ?? true)
        XCTAssertFalse(spy.startVM?.farewell.isEmpty ?? true)
    }

    func test_start_breathingPassedThrough() async {
        let (sut, spy) = makeSUT()
        let cycle = BedtimeBreathingCycle(inhaleSeconds: 5, holdSeconds: 3, exhaleSeconds: 7, totalCycles: 4)
        await sut.presentStart(response: response(breathing: cycle))
        XCTAssertEqual(spy.startVM?.breathing, cycle)
    }

    // MARK: - Advance

    func test_advance_forwardsStage() async {
        let (sut, spy) = makeSUT()
        await sut.presentAdvance(stage: .story)
        XCTAssertEqual(spy.advancedStage, .story)
    }

    // MARK: - NewStory

    func test_newStory_routesStoryFields() async {
        let (sut, spy) = makeSUT()
        await sut.presentNewStory(response: response(storyTitle: "Новая", storyText: "Другой текст"))
        XCTAssertEqual(spy.newStoryVM?.storyTitle, "Новая")
        XCTAssertEqual(spy.newStoryVM?.storyText, "Другой текст")
        XCTAssertFalse(spy.newStoryVM?.storiesCountLabel.isEmpty ?? true)
    }

    // MARK: - Shared builder

    func test_makeViewModel_isConsistentForStartAndNewStory() async {
        let (sut, spy) = makeSUT()
        let r = response(storyTitle: "Одна", storyText: "Один текст", count: 9)
        await sut.presentStart(response: r)
        await sut.presentNewStory(response: r)
        XCTAssertEqual(spy.startVM?.storyTitle, spy.newStoryVM?.storyTitle)
        XCTAssertEqual(spy.startVM?.storiesCountLabel, spy.newStoryVM?.storiesCountLabel)
    }
}
