import Foundation
import OSLog

// MARK: - WhoseTailPresentationLogic

@MainActor
protocol WhoseTailPresentationLogic: AnyObject {
    func presentStart(response: WhoseTailModels.Start.Response) async
    func presentAnswer(response: WhoseTailModels.Answer.Response) async
}

// MARK: - WhoseTailPresenter (Clean Swift: Presenter)
//
// F2-006 «Чей хвост / чей домик» (Wave 2).
//
// Строит игровые ViewModel: вопрос Ляли по улике, карточки-варианты
// (звери / материалы — БЕЗ признака нормы; `isCorrect`/`form` не покидают
// Interactor до hit), тёплую обратную связь по «светофору» (без «неправильно»)
// с озвучкой целевой формы прилагательного на hit и сводку. Все строки —
// String(localized:).

@MainActor
final class WhoseTailPresenter: WhoseTailPresentationLogic {

    weak var displayLogic: (any WhoseTailDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WhoseTail.Presenter"
    )

    init(displayLogic: (any WhoseTailDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Start

    func presentStart(response: WhoseTailModels.Start.Response) async {
        let total = response.rounds.count
        guard let firstRound = response.rounds.first else {
            Self.logger.error("Start with empty rounds")
            return
        }
        let viewModel = WhoseTailModels.Start.ViewModel(
            title: String(localized: "whoseTail.title"),
            totalRounds: total,
            firstRound: Self.makeRoundVM(firstRound, index: 0, total: total)
        )
        await displayLogic?.displayStart(viewModel: viewModel)
    }

    // MARK: - Answer

    func presentAnswer(response: WhoseTailModels.Answer.Response) async {
        let lyalyaLine = Self.feedbackLine(
            tier: response.feedback,
            spokenForm: response.spokenForm
        )

        let nextVM: WhoseTailModels.Start.RoundViewModel?
        if let nextRound = response.nextRound, let nextIndex = response.nextRoundIndex {
            nextVM = Self.makeRoundVM(nextRound, index: nextIndex, total: response.totalRounds)
        } else {
            nextVM = nil
        }

        let summary: WhoseTailModels.Answer.SummaryViewModel?
        if response.isFinished {
            let accuracy = response.totalRounds > 0
                ? Double(response.correctCount) / Double(response.totalRounds)
                : 0
            summary = .init(
                title: String(localized: "whoseTail.summary.title"),
                scoreText: String(
                    format: String(localized: "whoseTail.summary.score"),
                    response.correctCount,
                    response.totalRounds
                ),
                correctCount: response.correctCount,
                totalRounds: response.totalRounds,
                accuracyFraction: accuracy,
                encouragement: Self.encouragement(for: accuracy),
                showCelebration: accuracy >= 0.8
            )
        } else {
            summary = nil
        }

        let viewModel = WhoseTailModels.Answer.ViewModel(
            feedback: response.feedback,
            lyalyaLine: lyalyaLine,
            correctOptionId: response.correctOptionId,
            spokenForm: response.spokenForm,
            askToRepeat: response.askToRepeat,
            hintOptionId: response.showHint ? response.correctOptionId : nil,
            isFinished: response.isFinished,
            nextRound: nextVM,
            summary: summary
        )
        await displayLogic?.displayAnswer(viewModel: viewModel)
    }

    // MARK: - Round building

    static func makeRoundVM(
        _ round: WhoseRound,
        index: Int,
        total: Int
    ) -> WhoseTailModels.Start.RoundViewModel {
        let humanIndex = index + 1
        let progressLabel = String(
            format: String(localized: "whoseTail.progress"),
            humanIndex,
            total
        )
        let fraction = total > 0 ? Double(humanIndex) / Double(total) : 0

        return .init(
            id: round.id,
            subtask: round.subtask,
            cueImage: round.cueImage,
            promptLyalya: prompt(for: round),
            // Варианты уже перемешаны Worker'ом; нормативность НЕ переносим во VM.
            options: round.options.map(optionVM),
            progressLabel: progressLabel,
            progressFraction: fraction,
            accessibilityLabel: String(
                format: String(localized: "whoseTail.round.a11y"),
                round.question
            )
        )
    }

    /// Реплика-вопрос Ляли по улике. Конкретный текст-вопрос из пака
    /// (`round.question`) уже учитывает улику («Чей это хвост?» / «Из чего сделан
    /// стол?»), поэтому используем его как ведущую реплику.
    static func prompt(for round: WhoseRound) -> String {
        round.question.isEmpty ? subtaskPrompt(round.subtask) : round.question
    }

    /// Дефолтная реплика под-типа (если в паке question пуст).
    static func subtaskPrompt(_ subtask: WhoseSubtask) -> String {
        switch subtask {
        case .possessiveTail:   return String(localized: "whoseTail.prompt.possessiveTail")
        case .animalHome:       return String(localized: "whoseTail.prompt.animalHome")
        case .relativeMaterial: return String(localized: "whoseTail.prompt.relativeMaterial")
        }
    }

    static func optionVM(_ option: WhoseOption) -> WhoseTailModels.Start.OptionViewModel {
        .init(
            id: option.id,
            word: option.word,
            imageAsset: option.imageAsset,
            accessibilityLabel: String(
                format: String(localized: "whoseTail.option.a11y"),
                option.word
            )
        )
    }

    // MARK: - Feedback («светофор», без «неправильно»)

    static func feedbackLine(
        tier: FeedbackTier,
        spokenForm: String
    ) -> String {
        switch tier {
        case .hit:
            // На попадание озвучиваем целевую форму (закрепление по слуху).
            return String(
                format: String(localized: "whoseTail.feedback.hit"),
                spokenForm
            )
        case .almost:
            return String(localized: "whoseTail.feedback.almost")
        case .retry:
            return String(localized: "whoseTail.feedback.retry")
        }
    }

    // MARK: - Helpers

    static func encouragement(for accuracy: Double) -> String {
        if accuracy >= 0.8 {
            return String(localized: "whoseTail.encourage.great")
        } else if accuracy >= 0.5 {
            return String(localized: "whoseTail.encourage.good")
        } else {
            return String(localized: "whoseTail.encourage.keepGoing")
        }
    }
}
