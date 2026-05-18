@testable import HappySpeech
import XCTest

// MARK: - Spy DisplayLogic

@MainActor
private final class SpyStorytellingDisplay: StorytellingDisplayLogic, @unchecked Sendable {
    var topicsVM: StorytellingModels.LoadTopics.ViewModel?
    var startVM: StorytellingModels.StartTopic.ViewModel?
    var toggleVM: StorytellingModels.ToggleStep.ViewModel?
    var finishVM: StorytellingModels.Finish.ViewModel?

    func displayTopics(viewModel: StorytellingModels.LoadTopics.ViewModel) async {
        topicsVM = viewModel
    }
    func displayTopicStart(viewModel: StorytellingModels.StartTopic.ViewModel) async {
        startVM = viewModel
    }
    func displayToggle(viewModel: StorytellingModels.ToggleStep.ViewModel) async {
        toggleVM = viewModel
    }
    func displayFinish(viewModel: StorytellingModels.Finish.ViewModel) async {
        finishVM = viewModel
    }
}

// MARK: - Presenter Tests

@MainActor
final class StorytellingPresenterTests: XCTestCase {

    private func makeSUT() -> (StorytellingPresenter, SpyStorytellingDisplay) {
        let display = SpyStorytellingDisplay()
        let sut = StorytellingPresenter(displayLogic: display)
        return (sut, display)
    }

    func test_presentTopics_buildsCards() async {
        let (sut, display) = makeSUT()
        await sut.presentTopics(response: .init(topics: StorytellingCorpus.topics))
        XCTAssertEqual(display.topicsVM?.topics.count, StorytellingCorpus.topics.count)
    }

    func test_presentTopicStart_buildsSteps() async {
        let (sut, display) = makeSUT()
        await sut.presentTopicStart(response: .init(topic: StorytellingCorpus.topics[0]))
        XCTAssertEqual(display.startVM?.steps.count, 4)
        XCTAssertFalse(display.startVM?.topicTitle.isEmpty ?? true)
    }

    func test_presentToggle_buildsProgress() async {
        let (sut, display) = makeSUT()
        await sut.presentToggle(response: .init(
            completedStepIds: ["a", "b"],
            totalSteps: 4
        ))
        XCTAssertEqual(display.toggleVM?.progressFraction, 0.5)
        XCTAssertFalse(display.toggleVM?.progressLabel.isEmpty ?? true)
    }

    func test_presentFinish_fullPlan_savedToBook() async {
        let (sut, display) = makeSUT()
        await sut.presentFinish(response: .init(
            completedCount: 4,
            totalSteps: 4,
            topicTitle: "Зоопарк"
        ))
        XCTAssertEqual(display.finishVM?.savedToBook, true)
        XCTAssertFalse(display.finishVM?.encouragement.isEmpty ?? true)
    }

    func test_presentFinish_partialPlan_notSaved() async {
        let (sut, display) = makeSUT()
        await sut.presentFinish(response: .init(
            completedCount: 1,
            totalSteps: 4,
            topicTitle: "Зоопарк"
        ))
        XCTAssertEqual(display.finishVM?.savedToBook, false)
    }
}
