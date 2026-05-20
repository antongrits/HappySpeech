@testable import HappySpeech
import XCTest

// MARK: - Spy DisplayLogic

@MainActor
private final class SpyReadAloudDisplay: ReadAloudStoryDisplayLogic, @unchecked Sendable {
    var lastStartVM: ReadAloudStoryModels.Start.ViewModel?
    var lastNextSentenceVM: ReadAloudStoryModels.NextSentence.ViewModel?
    var lastQuizVM: ReadAloudStoryModels.StartQuiz.ViewModel?
    var lastAnswerVM: ReadAloudStoryModels.Answer.ViewModel?

    func displayStart(viewModel: ReadAloudStoryModels.Start.ViewModel) async {
        lastStartVM = viewModel
    }
    func displayNextSentence(viewModel: ReadAloudStoryModels.NextSentence.ViewModel) async {
        lastNextSentenceVM = viewModel
    }
    func displayStartQuiz(viewModel: ReadAloudStoryModels.StartQuiz.ViewModel) async {
        lastQuizVM = viewModel
    }
    func displayAnswer(viewModel: ReadAloudStoryModels.Answer.ViewModel) async {
        lastAnswerVM = viewModel
    }
}

// MARK: - Fixtures

private func sampleStory() -> ReadAloudStory {
    ReadAloudStory(
        id: "story-test",
        title: "Тест",
        sentences: ["Первое предложение.", "Второе.", "Третье."],
        questions: [
            ReadAloudQuestion(
                id: "q1",
                text: "Где живёт кот?",
                options: ["дом", "лес", "море", "поле"],
                correctIndex: 0
            ),
            ReadAloudQuestion(
                id: "q2",
                text: "Что пил мишка?",
                options: ["мёд", "молоко", "чай", "сок"],
                correctIndex: 0
            )
        ]
    )
}

// MARK: - Presenter Tests

@MainActor
final class ReadAloudStoryPresenterTests: XCTestCase {

    private func makeSUT() -> (ReadAloudStoryPresenter, SpyReadAloudDisplay) {
        let spy = SpyReadAloudDisplay()
        let presenter = ReadAloudStoryPresenter(displayLogic: spy)
        return (presenter, spy)
    }

    func test_presentStart_buildsViewModelWithTitleAndSentences() async {
        let (presenter, spy) = makeSUT()
        let story = sampleStory()
        await presenter.presentStart(response: .init(story: story))
        XCTAssertEqual(spy.lastStartVM?.title, "Тест")
        XCTAssertEqual(spy.lastStartVM?.sentences.count, 3)
        XCTAssertEqual(spy.lastStartVM?.totalQuestions, 2)
        XCTAssertEqual(spy.lastStartVM?.storyId, "story-test")
    }

    func test_presentNextSentence_readingStage_setsHighlightIndex() async {
        let (presenter, spy) = makeSUT()
        await presenter.presentNextSentence(response: .init(
            stage: .reading(currentSentenceIndex: 2),
            progressLabel: "3/5",
            progressFraction: 0.6
        ))
        XCTAssertEqual(spy.lastNextSentenceVM?.highlightedSentenceIndex, 2)
        XCTAssertEqual(spy.lastNextSentenceVM?.progressFraction ?? -1, 0.6, accuracy: 0.001)
    }

    func test_presentNextSentence_quizStage_clearsHighlight() async {
        let (presenter, spy) = makeSUT()
        await presenter.presentNextSentence(response: .init(
            stage: .quiz(questionIndex: 0),
            progressLabel: "Q",
            progressFraction: 0
        ))
        XCTAssertNil(spy.lastNextSentenceVM?.highlightedSentenceIndex)
    }

    func test_presentStartQuiz_buildsQuestionVMWith4Options() async {
        let (presenter, spy) = makeSUT()
        let story = sampleStory()
        await presenter.presentStartQuiz(response: .init(
            question: story.questions[0],
            questionIndex: 0,
            totalQuestions: 2
        ))
        XCTAssertEqual(spy.lastQuizVM?.options.count, 4)
        XCTAssertEqual(spy.lastQuizVM?.options[0].label, "дом")
        XCTAssertEqual(spy.lastQuizVM?.progressFraction ?? -1, 0.5, accuracy: 0.01)
    }

    func test_presentAnswer_correct_feedbackPositive() async {
        let (presenter, spy) = makeSUT()
        await presenter.presentAnswer(response: .init(
            wasCorrect: true,
            correctIndex: 0,
            isFinished: false,
            nextQuestion: sampleStory().questions[1],
            nextQuestionIndex: 1,
            totalQuestions: 2,
            correctCount: 1
        ))
        XCTAssertEqual(spy.lastAnswerVM?.wasCorrect, true)
        XCTAssertNotNil(spy.lastAnswerVM?.nextQuestion)
        XCTAssertNil(spy.lastAnswerVM?.summary)
    }

    func test_presentAnswer_finished_buildsSummary() async {
        let (presenter, spy) = makeSUT()
        await presenter.presentAnswer(response: .init(
            wasCorrect: true,
            correctIndex: 0,
            isFinished: true,
            nextQuestion: nil,
            nextQuestionIndex: nil,
            totalQuestions: 3,
            correctCount: 3
        ))
        XCTAssertEqual(spy.lastAnswerVM?.isFinished, true)
        XCTAssertNotNil(spy.lastAnswerVM?.summary)
        XCTAssertEqual(spy.lastAnswerVM?.summary?.accuracyFraction ?? 0, 1.0, accuracy: 0.001)
    }
}

// MARK: - Corpus Tests

final class ReadAloudStoryCorpusTests: XCTestCase {

    func test_corpus_loadsAtLeast15Stories() {
        // 20 in JSON, гарантируем минимум 15 на случай платформенных проблем.
        XCTAssertGreaterThanOrEqual(ReadAloudStoryCorpus.allStories.count, 15)
    }

    func test_eachStory_hasBetween4And8Sentences() {
        for story in ReadAloudStoryCorpus.allStories {
            XCTAssertGreaterThanOrEqual(story.sentences.count, 4, "история \(story.id)")
            XCTAssertLessThanOrEqual(story.sentences.count, 8, "история \(story.id)")
        }
    }

    func test_eachStory_hasExactly3Questions() {
        for story in ReadAloudStoryCorpus.allStories {
            XCTAssertEqual(story.questions.count, 3, "история \(story.id)")
        }
    }

    func test_eachQuestion_hasExactly4Options() {
        for story in ReadAloudStoryCorpus.allStories {
            for question in story.questions {
                XCTAssertEqual(question.options.count, 4,
                               "вопрос \(question.id) истории \(story.id)")
            }
        }
    }

    func test_correctIndex_isWithinOptions() {
        for story in ReadAloudStoryCorpus.allStories {
            for question in story.questions {
                XCTAssertTrue(
                    (0..<question.options.count).contains(question.correctIndex),
                    "вопрос \(question.id): correctIndex out of bounds"
                )
            }
        }
    }

    func test_storyIdsAreUnique() {
        let ids = ReadAloudStoryCorpus.allStories.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_randomStory_excludesGivenId() {
        guard let first = ReadAloudStoryCorpus.allStories.first else {
            XCTFail("corpus empty")
            return
        }
        // вызовем 5 раз, чтобы у random был шанс попасть в исключение
        for _ in 0..<10 {
            let picked = ReadAloudStoryCorpus.randomStory(excluding: first.id)
            XCTAssertNotEqual(picked?.id, first.id)
        }
    }
}
