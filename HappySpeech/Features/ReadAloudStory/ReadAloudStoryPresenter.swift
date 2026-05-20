import Foundation
import OSLog

// MARK: - ReadAloudStoryPresentationLogic

@MainActor
protocol ReadAloudStoryPresentationLogic: AnyObject {
    func presentStart(response: ReadAloudStoryModels.Start.Response) async
    func presentNextSentence(response: ReadAloudStoryModels.NextSentence.Response) async
    func presentStartQuiz(response: ReadAloudStoryModels.StartQuiz.Response) async
    func presentAnswer(response: ReadAloudStoryModels.Answer.Response) async
}

// MARK: - ReadAloudStoryPresenter (Clean Swift: Presenter)
//
// Строит ViewModel из методически-правильных строк, всегда через
// `String(localized:)` (см. `Localizable.xcstrings`).

@MainActor
final class ReadAloudStoryPresenter: ReadAloudStoryPresentationLogic {

    weak var displayLogic: (any ReadAloudStoryDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ReadAloudStory.Presenter"
    )

    init(displayLogic: (any ReadAloudStoryDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Start

    func presentStart(response: ReadAloudStoryModels.Start.Response) async {
        let story = response.story
        let total = story.sentences.count
        let viewModel = ReadAloudStoryModels.Start.ViewModel(
            title: story.title,
            storyId: story.id,
            sentences: story.sentences,
            totalQuestions: story.questions.count,
            firstSentenceLabel: String(
                format: String(localized: "readAloud.progress.sentence"),
                1, total
            )
        )
        await displayLogic?.displayStart(viewModel: viewModel)
    }

    // MARK: - NextSentence

    func presentNextSentence(response: ReadAloudStoryModels.NextSentence.Response) async {
        let highlightedIndex: Int?
        switch response.stage {
        case .reading(let idx), .readingPaused(let idx):
            highlightedIndex = idx
        case .quiz, .summary:
            highlightedIndex = nil
        }
        let viewModel = ReadAloudStoryModels.NextSentence.ViewModel(
            stage: response.stage,
            progressLabel: response.progressLabel,
            progressFraction: response.progressFraction,
            highlightedSentenceIndex: highlightedIndex
        )
        await displayLogic?.displayNextSentence(viewModel: viewModel)
    }

    // MARK: - StartQuiz

    func presentStartQuiz(response: ReadAloudStoryModels.StartQuiz.Response) async {
        let viewModel = Self.makeQuestionVM(
            response.question,
            index: response.questionIndex,
            total: response.totalQuestions
        )
        await displayLogic?.displayStartQuiz(viewModel: viewModel)
    }

    // MARK: - Answer

    func presentAnswer(response: ReadAloudStoryModels.Answer.Response) async {
        let feedback = response.wasCorrect
            ? String(localized: "readAloud.feedback.correct")
            : String(localized: "readAloud.feedback.tryAgain")

        let nextVM: ReadAloudStoryModels.StartQuiz.ViewModel?
        if let nextQuestion = response.nextQuestion,
           let nextIndex = response.nextQuestionIndex {
            nextVM = Self.makeQuestionVM(
                nextQuestion,
                index: nextIndex,
                total: response.totalQuestions
            )
        } else {
            nextVM = nil
        }

        let summary: ReadAloudStoryModels.Answer.SummaryViewModel?
        if response.isFinished {
            let accuracy = response.totalQuestions > 0
                ? Double(response.correctCount) / Double(response.totalQuestions)
                : 0
            summary = .init(
                title: String(localized: "readAloud.summary.title"),
                scoreText: String(
                    format: String(localized: "readAloud.summary.score"),
                    response.correctCount,
                    response.totalQuestions
                ),
                accuracyFraction: accuracy,
                encouragement: Self.encouragement(for: accuracy)
            )
        } else {
            summary = nil
        }

        let viewModel = ReadAloudStoryModels.Answer.ViewModel(
            wasCorrect: response.wasCorrect,
            feedbackText: feedback,
            isFinished: response.isFinished,
            nextQuestion: nextVM,
            summary: summary
        )
        await displayLogic?.displayAnswer(viewModel: viewModel)
    }

    // MARK: - Helpers

    static func makeQuestionVM(
        _ question: ReadAloudQuestion,
        index: Int,
        total: Int
    ) -> ReadAloudStoryModels.StartQuiz.ViewModel {
        let human = index + 1
        let progressLabel = String(
            format: String(localized: "readAloud.progress.question"),
            human, total
        )
        let fraction = total > 0 ? Double(human) / Double(total) : 0
        let options = question.options.enumerated().map { idx, label in
            ReadAloudStoryModels.StartQuiz.OptionViewModel(id: idx, label: label)
        }
        return .init(
            prompt: question.text,
            options: options,
            progressLabel: progressLabel,
            progressFraction: fraction,
            accessibilityLabel: String(
                format: String(localized: "readAloud.question.a11y"),
                question.text
            )
        )
    }

    private static func encouragement(for accuracy: Double) -> String {
        if accuracy >= 0.8 {
            return String(localized: "readAloud.encourage.great")
        } else if accuracy >= 0.5 {
            return String(localized: "readAloud.encourage.good")
        } else {
            return String(localized: "readAloud.encourage.keepGoing")
        }
    }
}
