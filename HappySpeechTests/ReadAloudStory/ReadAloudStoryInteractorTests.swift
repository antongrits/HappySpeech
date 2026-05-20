@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubReadAloudWorker: ReadAloudStoryWorkerProtocol {

    var nextStory: ReadAloudStory?
    private(set) var pickCount = 0
    private(set) var speakCount = 0
    private(set) var stopCount = 0

    init(nextStory: ReadAloudStory?) {
        self.nextStory = nextStory
    }

    var libraryCount: Int { nextStory == nil ? 0 : 1 }

    func pickStory(excluding excludeStoryId: String?) -> ReadAloudStory? {
        pickCount += 1
        guard let story = nextStory else { return nil }
        if story.id == excludeStoryId {
            return nil
        }
        return story
    }

    func speakSentence(_ text: String) async {
        speakCount += 1
    }

    func stopSpeaking() {
        stopCount += 1
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyReadAloudPresenter:
    ReadAloudStoryPresentationLogic, @unchecked Sendable {
    var startCount = 0
    var nextSentenceCount = 0
    var startQuizCount = 0
    var answerCount = 0
    var lastNextSentence: ReadAloudStoryModels.NextSentence.Response?
    var lastAnswer: ReadAloudStoryModels.Answer.Response?

    func presentStart(response: ReadAloudStoryModels.Start.Response) async {
        startCount += 1
    }
    func presentNextSentence(response: ReadAloudStoryModels.NextSentence.Response) async {
        nextSentenceCount += 1
        lastNextSentence = response
    }
    func presentStartQuiz(response: ReadAloudStoryModels.StartQuiz.Response) async {
        startQuizCount += 1
    }
    func presentAnswer(response: ReadAloudStoryModels.Answer.Response) async {
        answerCount += 1
        lastAnswer = response
    }
}

// MARK: - Fixtures

private func makeQuestion(id: String, correct: Int = 0) -> ReadAloudQuestion {
    ReadAloudQuestion(
        id: id,
        text: "Что нашли герои?",
        options: ["сыр", "колбаса", "конфета", "хлеб"],
        correctIndex: correct
    )
}

private func makeStory(
    id: String = "story-test",
    sentenceCount: Int = 3,
    questionCount: Int = 3
) -> ReadAloudStory {
    let sentences = (0..<sentenceCount).map { "Предложение \($0)." }
    let questions = (0..<questionCount).map { makeQuestion(id: "q\($0)") }
    return ReadAloudStory(
        id: id,
        title: "Тестовая история",
        sentences: sentences,
        questions: questions
    )
}

// MARK: - Interactor Tests

@MainActor
final class ReadAloudStoryInteractorTests: XCTestCase {

    private func makeSUT(
        story: ReadAloudStory = makeStory()
    ) -> (ReadAloudStoryInteractor, SpyReadAloudPresenter, StubReadAloudWorker) {
        let worker = StubReadAloudWorker(nextStory: story)
        let haptic = SpyHapticService()
        let sut = ReadAloudStoryInteractor(
            childId: "child-1",
            worker: worker,
            hapticService: haptic
        )
        let spy = SpyReadAloudPresenter()
        sut.presenter = spy
        return (sut, spy, worker)
    }

    // MARK: start

    func test_start_picksStory_andPresentsStart() async {
        let (sut, spy, worker) = makeSUT()
        await sut.start(request: .init(childId: "child-1", excludeStoryId: nil))
        XCTAssertEqual(spy.startCount, 1)
        XCTAssertEqual(worker.pickCount, 1)
        XCTAssertNotNil(sut.activeStory)
        XCTAssertEqual(sut.currentSentenceIndex, 0)
        XCTAssertEqual(sut.correctCount, 0)
    }

    func test_start_emptyCorpus_doesNotPresent() async {
        let worker = StubReadAloudWorker(nextStory: nil)
        let haptic = SpyHapticService()
        let sut = ReadAloudStoryInteractor(
            childId: "c", worker: worker, hapticService: haptic
        )
        let spy = SpyReadAloudPresenter()
        sut.presenter = spy
        await sut.start(request: .init(childId: "c", excludeStoryId: nil))
        XCTAssertEqual(spy.startCount, 0)
        XCTAssertNil(sut.activeStory)
    }

    // MARK: playNextSentence

    func test_playNextSentence_speaksAndAdvances() async {
        let (sut, spy, worker) = makeSUT(story: makeStory(sentenceCount: 3))
        await sut.start(request: .init(childId: "c", excludeStoryId: nil))
        await sut.playNextSentence()
        XCTAssertEqual(worker.speakCount, 1)
        XCTAssertEqual(sut.currentSentenceIndex, 1)
        XCTAssertGreaterThanOrEqual(spy.nextSentenceCount, 1)
    }

    func test_playNextSentence_afterLast_movesToQuiz() async {
        let (sut, spy, _) = makeSUT(story: makeStory(sentenceCount: 2))
        await sut.start(request: .init(childId: "c", excludeStoryId: nil))
        // 2 предложения
        await sut.playNextSentence()
        await sut.playNextSentence()
        // Третий вызов — переход в квиз
        await sut.playNextSentence()
        XCTAssertEqual(spy.startQuizCount, 1)
    }

    // MARK: skipToQuiz

    func test_skipToQuiz_stopsSpeaking_andStartsQuiz() async {
        let (sut, spy, worker) = makeSUT()
        await sut.start(request: .init(childId: "c", excludeStoryId: nil))
        await sut.skipToQuiz()
        XCTAssertEqual(worker.stopCount, 1)
        XCTAssertEqual(spy.startQuizCount, 1)
    }

    // MARK: answer

    func test_answer_correct_increments() async {
        let (sut, spy, _) = makeSUT(story: makeStory(questionCount: 3))
        await sut.start(request: .init(childId: "c", excludeStoryId: nil))
        await sut.skipToQuiz()
        await sut.answer(request: .init(optionIndex: 0))
        XCTAssertEqual(sut.correctCount, 1)
        XCTAssertEqual(spy.lastAnswer?.wasCorrect, true)
    }

    func test_answer_wrong_doesNotIncrement() async {
        let (sut, _, _) = makeSUT(story: makeStory(questionCount: 3))
        await sut.start(request: .init(childId: "c", excludeStoryId: nil))
        await sut.skipToQuiz()
        await sut.answer(request: .init(optionIndex: 2))
        XCTAssertEqual(sut.correctCount, 0)
    }

    func test_answer_lastQuestion_marksFinished() async {
        let (sut, spy, _) = makeSUT(story: makeStory(questionCount: 2))
        await sut.start(request: .init(childId: "c", excludeStoryId: nil))
        await sut.skipToQuiz()
        await sut.answer(request: .init(optionIndex: 0))
        await sut.answer(request: .init(optionIndex: 0))
        XCTAssertEqual(spy.lastAnswer?.isFinished, true)
        XCTAssertEqual(spy.lastAnswer?.correctCount, 2)
    }

    func test_answer_withoutActiveQuestion_returnsEarly() async {
        let (sut, spy, _) = makeSUT()
        // нет start — нет activeStory
        await sut.answer(request: .init(optionIndex: 0))
        XCTAssertEqual(spy.answerCount, 0)
    }
}
