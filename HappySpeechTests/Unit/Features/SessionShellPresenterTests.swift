import XCTest
@testable import HappySpeech

// MARK: - SessionShellPresenterTests
//
// Phase 2.6 batch 3 — покрытие SessionShellPresenter (0% → цель ≥90%).

@MainActor
final class SessionShellPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: SessionShellDisplayLogic {
        var startVM: SessionShellModels.StartSession.ViewModel?
        var completeVM: SessionShellModels.CompleteActivity.ViewModel?
        var pauseVM: SessionShellModels.PauseSession.ViewModel?

        func displayStartSession(_ vm: SessionShellModels.StartSession.ViewModel) { startVM = vm }
        func displayCompleteActivity(_ vm: SessionShellModels.CompleteActivity.ViewModel) { completeVM = vm }
        func displayPauseSession(_ vm: SessionShellModels.PauseSession.ViewModel) { pauseVM = vm }
    }

    private func makeSUT() -> (SessionShellPresenter, DisplaySpy) {
        let sut = SessionShellPresenter()
        let spy = DisplaySpy()
        sut.display = spy
        return (sut, spy)
    }

    private func makeActivity(id: String = "act-1") -> SessionActivity {
        SessionActivity(
            id: id,
            gameType: .listenAndChoose,
            lessonId: "lesson-1",
            soundTarget: "С",
            difficulty: 1,
            isCompleted: false,
            score: nil
        )
    }

    // MARK: - presentStartSession

    func test_presentStartSession_callsDisplay() async {
        let (sut, spy) = makeSUT()
        let activities = [makeActivity()]
        await sut.presentStartSession(.init(
            activities: activities,
            totalSteps: 3,
            estimatedMinutes: 10,
            sessionStartTime: Date()
        ))
        XCTAssertNotNil(spy.startVM)
        XCTAssertEqual(spy.startVM?.totalSteps, 3)
        XCTAssertFalse(spy.startVM?.progressTitle.isEmpty ?? true)
    }

    // MARK: - presentCompleteActivity

    func test_presentCompleteActivity_correctFeedback_encouragingMascot() async {
        let (sut, spy) = makeSUT()
        await sut.presentCompleteActivity(.init(
            nextActivity: nil,
            isSessionComplete: false,
            earnedReward: nil,
            fatigueDetected: false,
            fatigueHearts: 3,
            feedback: .correct
        ))
        XCTAssertEqual(spy.completeVM?.feedbackState, .correct)
        XCTAssertEqual(spy.completeVM?.mascotState, .encouraging)
        XCTAssertFalse(spy.completeVM?.shouldShowReward ?? true)
    }

    func test_presentCompleteActivity_correctWithReward_celebratingMascot() async {
        let (sut, spy) = makeSUT()
        await sut.presentCompleteActivity(.init(
            nextActivity: nil,
            isSessionComplete: false,
            earnedReward: .star,
            fatigueDetected: false,
            fatigueHearts: 3,
            feedback: .correct
        ))
        XCTAssertEqual(spy.completeVM?.mascotState, .celebrating)
        XCTAssertTrue(spy.completeVM?.shouldShowReward == true)
        XCTAssertNotNil(spy.completeVM?.reward)
        XCTAssertFalse(spy.completeVM?.reward?.iconName.isEmpty ?? true)
    }

    func test_presentCompleteActivity_incorrectFeedback_thinkingMascot() async {
        let (sut, spy) = makeSUT()
        await sut.presentCompleteActivity(.init(
            nextActivity: nil,
            isSessionComplete: false,
            earnedReward: nil,
            fatigueDetected: false,
            fatigueHearts: 2,
            feedback: .incorrect
        ))
        XCTAssertEqual(spy.completeVM?.feedbackState, .incorrect)
        XCTAssertEqual(spy.completeVM?.mascotState, .thinking)
    }

    func test_presentCompleteActivity_fatigueDetected_thinkingMascot() async {
        let (sut, spy) = makeSUT()
        await sut.presentCompleteActivity(.init(
            nextActivity: nil,
            isSessionComplete: false,
            earnedReward: nil,
            fatigueDetected: true,
            fatigueHearts: 1,
            feedback: .correct
        ))
        XCTAssertTrue(spy.completeVM?.shouldShowFatigueAlert == true)
        XCTAssertEqual(spy.completeVM?.mascotState, .thinking)
    }

    func test_presentCompleteActivity_sessionComplete_shouldNotAdvance() async {
        let (sut, spy) = makeSUT()
        await sut.presentCompleteActivity(.init(
            nextActivity: nil,
            isSessionComplete: true,
            earnedReward: nil,
            fatigueDetected: false,
            fatigueHearts: 3,
            feedback: .correct
        ))
        XCTAssertFalse(spy.completeVM?.shouldAdvance ?? true)
    }

    func test_presentCompleteActivity_notComplete_shouldAdvance() async {
        let (sut, spy) = makeSUT()
        await sut.presentCompleteActivity(.init(
            nextActivity: makeActivity(id: "act-2"),
            isSessionComplete: false,
            earnedReward: nil,
            fatigueDetected: false,
            fatigueHearts: 3,
            feedback: .correct
        ))
        XCTAssertTrue(spy.completeVM?.shouldAdvance == true)
    }

    // MARK: - presentPauseSession

    func test_presentPauseSession_formatsTime() {
        let (sut, spy) = makeSUT()
        sut.presentPauseSession(.init(currentProgress: 0.5, activeSeconds: 125))
        XCTAssertNotNil(spy.pauseVM)
        XCTAssertEqual(spy.pauseVM?.timeSpentFormatted, "02:05")
        XCTAssertEqual(spy.pauseVM?.progressPercentage ?? 0, 0.5, accuracy: 0.01)
        XCTAssertFalse(spy.pauseVM?.motivationalPhrase.isEmpty ?? true)
    }

    func test_presentPauseSession_zeroSeconds_formatsAsZero() {
        let (sut, spy) = makeSUT()
        sut.presentPauseSession(.init(currentProgress: 0.0, activeSeconds: 0))
        XCTAssertEqual(spy.pauseVM?.timeSpentFormatted, "00:00")
    }

    func test_presentPauseSession_negativeSeconds_formatsAsZero() {
        let (sut, spy) = makeSUT()
        sut.presentPauseSession(.init(currentProgress: 0.0, activeSeconds: -10))
        XCTAssertEqual(spy.pauseVM?.timeSpentFormatted, "00:00")
    }

    func test_presentPauseSession_seedVariation_differentPhrases() {
        let (sut, _) = makeSUT()
        // Собираем фразы для разных seed значений (0...9)
        var phrases = Set<String>()
        for seed in stride(from: 0.0, to: 5.0, by: 1.0) {
            let spy = DisplaySpy()
            sut.display = spy
            sut.presentPauseSession(.init(currentProgress: 0.3, activeSeconds: seed))
            if let phrase = spy.pauseVM?.motivationalPhrase {
                phrases.insert(phrase)
            }
        }
        XCTAssertFalse(phrases.isEmpty)
    }
}
