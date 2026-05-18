@testable import HappySpeech
import XCTest

// MARK: - Spy DisplayLogic

@MainActor
private final class SpyRetellingDisplay: RetellingDisplayLogic, @unchecked Sendable {
    var startVM: RetellingModels.Start.ViewModel?
    var toggleVM: RetellingModels.ToggleLink.ViewModel?
    var finishVM: RetellingModels.Finish.ViewModel?

    func displayStart(viewModel: RetellingModels.Start.ViewModel) async {
        startVM = viewModel
    }
    func displayToggle(viewModel: RetellingModels.ToggleLink.ViewModel) async {
        toggleVM = viewModel
    }
    func displayFinish(viewModel: RetellingModels.Finish.ViewModel) async {
        finishVM = viewModel
    }
}

// MARK: - Helpers

@MainActor
private func makeStory() -> RetellingStory {
    .init(id: "s1", title: "Тест", frames: [
        .init(id: "f1", sentence: "Жил кот.", link: .hero, symbolName: "cat.fill"),
        .init(id: "f2", sentence: "В саду.", link: .place, symbolName: "tree.fill"),
        .init(id: "f3", sentence: "Потерялся.", link: .problem, symbolName: "x.circle"),
        .init(id: "f4", sentence: "Нашёлся.", link: .solution, symbolName: "checkmark")
    ])
}

// MARK: - Presenter Tests

@MainActor
final class RetellingPresenterTests: XCTestCase {

    private func makeSUT() -> (RetellingPresenter, SpyRetellingDisplay) {
        let display = SpyRetellingDisplay()
        let sut = RetellingPresenter(displayLogic: display)
        return (sut, display)
    }

    func test_presentStart_buildsViewModelWithFrames() async {
        let (sut, display) = makeSUT()
        await sut.presentStart(response: .init(story: makeStory()))
        XCTAssertEqual(display.startVM?.storyTitle, "Тест")
        XCTAssertEqual(display.startVM?.frames.count, 4)
        XCTAssertFalse(display.startVM?.fullText.isEmpty ?? true)
    }

    func test_presentToggle_buildsCoverage() async {
        let (sut, display) = makeSUT()
        await sut.presentToggle(response: .init(
            coveredFrameIds: ["f1", "f2"],
            totalFrames: 4
        ))
        XCTAssertEqual(display.toggleVM?.coveredFrameIds.count, 2)
        XCTAssertEqual(display.toggleVM?.coverageFraction, 0.5)
        XCTAssertFalse(display.toggleVM?.coverageLabel.isEmpty ?? true)
    }

    func test_presentFinish_fullCoverage_noHints() async {
        let (sut, display) = makeSUT()
        await sut.presentFinish(response: .init(
            coveredCount: 4,
            totalFrames: 4,
            missedLinks: []
        ))
        XCTAssertEqual(display.finishVM?.coverageFraction, 1.0)
        XCTAssertTrue(display.finishVM?.hints.isEmpty ?? false)
        XCTAssertFalse(display.finishVM?.encouragement.isEmpty ?? true)
    }

    func test_presentFinish_missedLinks_buildsHints() async {
        let (sut, display) = makeSUT()
        await sut.presentFinish(response: .init(
            coveredCount: 2,
            totalFrames: 4,
            missedLinks: [.problem, .solution]
        ))
        XCTAssertEqual(display.finishVM?.hints.count, 2)
        XCTAssertFalse(display.finishVM?.scoreText.isEmpty ?? true)
    }
}
