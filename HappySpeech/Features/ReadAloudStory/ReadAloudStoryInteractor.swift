import Foundation
import OSLog

// MARK: - ReadAloudStoryBusinessLogic

@MainActor
protocol ReadAloudStoryBusinessLogic: AnyObject {
    func start(request: ReadAloudStoryModels.Start.Request) async
    /// Озвучить следующее предложение либо перейти в квиз.
    func playNextSentence() async
    /// Прервать чтение и перейти в квиз досрочно.
    func skipToQuiz() async
    func answer(request: ReadAloudStoryModels.Answer.Request) async
}

// MARK: - ReadAloudStoryDataStore

@MainActor
protocol ReadAloudStoryDataStore: AnyObject {
    var childId: String { get set }
    var activeStory: ReadAloudStory? { get set }
    var currentSentenceIndex: Int { get set }
    var currentQuestionIndex: Int { get set }
    var correctCount: Int { get set }
}

// MARK: - ReadAloudStoryInteractor
//
// Сценарий:
//   1. start → выбираем историю, говорим Presenter'у её показать,
//      инициализируем DataStore.
//   2. playNextSentence → озвучиваем sentences[currentSentenceIndex],
//      инкрементируем индекс. Когда индекс ≥ count — переходим в квиз.
//   3. skipToQuiz → стоп TTS, переходим в квиз сразу.
//   4. answer → проверяем правильность, инкрементируем счётчик, идём дальше
//      или к summary.

@MainActor
final class ReadAloudStoryInteractor:
    ReadAloudStoryBusinessLogic, ReadAloudStoryDataStore {

    // MARK: - DataStore

    var childId: String
    var activeStory: ReadAloudStory?
    var currentSentenceIndex: Int = 0
    var currentQuestionIndex: Int = 0
    var correctCount: Int = 0

    // MARK: - VIP

    var presenter: (any ReadAloudStoryPresentationLogic)?

    // MARK: - Deps

    private let worker: any ReadAloudStoryWorkerProtocol
    private let hapticService: any HapticService

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ReadAloudStory.Interactor"
    )

    // MARK: - Init

    init(
        childId: String,
        worker: any ReadAloudStoryWorkerProtocol,
        hapticService: any HapticService
    ) {
        self.childId = childId
        self.worker = worker
        self.hapticService = hapticService
    }

    // MARK: - Start

    func start(request: ReadAloudStoryModels.Start.Request) async {
        childId = request.childId
        guard let story = worker.pickStory(excluding: request.excludeStoryId) else {
            Self.logger.error("Корпус историй пуст — start прерван")
            return
        }
        activeStory = story
        currentSentenceIndex = 0
        currentQuestionIndex = 0
        correctCount = 0
        await presenter?.presentStart(response: .init(story: story))
    }

    // MARK: - PlayNextSentence

    func playNextSentence() async {
        guard let story = activeStory else { return }
        if currentSentenceIndex >= story.sentences.count {
            await beginQuiz()
            return
        }
        let sentence = story.sentences[currentSentenceIndex]
        let indexToHighlight = currentSentenceIndex
        // Сначала показываем подсветку, потом озвучиваем — Presenter получает
        // stage с правильным индексом.
        let stage = ReadAloudStage.reading(currentSentenceIndex: indexToHighlight)
        let total = story.sentences.count
        let progress = Double(indexToHighlight + 1) / Double(total)
        await presenter?.presentNextSentence(response: .init(
            stage: stage,
            progressLabel: progressLabel(current: indexToHighlight + 1, total: total),
            progressFraction: progress
        ))
        currentSentenceIndex += 1
        await worker.speakSentence(sentence)
    }

    // MARK: - SkipToQuiz

    func skipToQuiz() async {
        worker.stopSpeaking()
        await beginQuiz()
    }

    private func beginQuiz() async {
        guard let story = activeStory, !story.questions.isEmpty else { return }
        currentSentenceIndex = story.sentences.count
        currentQuestionIndex = 0
        let firstQuestion = story.questions[0]
        await presenter?.presentStartQuiz(response: .init(
            question: firstQuestion,
            questionIndex: 0,
            totalQuestions: story.questions.count
        ))
    }

    // MARK: - Answer

    func answer(request: ReadAloudStoryModels.Answer.Request) async {
        guard let story = activeStory,
              currentQuestionIndex < story.questions.count else {
            Self.logger.warning("answer вызван без активного вопроса")
            return
        }
        let question = story.questions[currentQuestionIndex]
        let wasCorrect = request.optionIndex == question.correctIndex
        if wasCorrect {
            correctCount += 1
            hapticService.notification(.success)
        } else {
            hapticService.notification(.warning)
        }
        currentQuestionIndex += 1
        let isFinished = currentQuestionIndex >= story.questions.count
        let nextQuestion = isFinished ? nil : story.questions[currentQuestionIndex]
        let response = ReadAloudStoryModels.Answer.Response(
            wasCorrect: wasCorrect,
            correctIndex: question.correctIndex,
            isFinished: isFinished,
            nextQuestion: nextQuestion,
            nextQuestionIndex: isFinished ? nil : currentQuestionIndex,
            totalQuestions: story.questions.count,
            correctCount: correctCount
        )
        await presenter?.presentAnswer(response: response)
    }

    // MARK: - Helpers

    private func progressLabel(current: Int, total: Int) -> String {
        "\(current)/\(total)"
    }
}
