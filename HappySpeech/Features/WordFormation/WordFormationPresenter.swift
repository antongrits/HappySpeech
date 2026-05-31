import Foundation
import OSLog

// MARK: - WordFormationPresentationLogic

@MainActor
protocol WordFormationPresentationLogic: AnyObject {
    func presentStart(response: WordFormationModels.Start.Response) async
    func presentAnswer(response: WordFormationModels.Answer.Response) async
}

// MARK: - WordFormationPresenter (Clean Swift: Presenter)
//
// F2-007 «Назови ласково / Один-много-нет» (Wave 2).
//
// Строит игровые ViewModel: вопрос Ляли по под-типу, текстовые варианты-формы
// (БЕЗ признака нормы — `isCorrect`/`isNearMiss` не покидают Interactor),
// тёплую обратную связь по «светофору» (без «неправильно») с озвучкой
// нормативной формы на hit и сводку. Все строки — String(localized:).

@MainActor
final class WordFormationPresenter: WordFormationPresentationLogic {

    weak var displayLogic: (any WordFormationDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WordFormation.Presenter"
    )

    init(displayLogic: (any WordFormationDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Start

    func presentStart(response: WordFormationModels.Start.Response) async {
        let total = response.rounds.count
        guard let firstRound = response.rounds.first else {
            Self.logger.error("Start with empty rounds")
            return
        }
        let viewModel = WordFormationModels.Start.ViewModel(
            title: String(localized: "wordFormation.title"),
            totalRounds: total,
            firstRound: Self.makeRoundVM(firstRound, index: 0, total: total)
        )
        await displayLogic?.displayStart(viewModel: viewModel)
    }

    // MARK: - Answer

    func presentAnswer(response: WordFormationModels.Answer.Response) async {
        let lyalyaLine = Self.feedbackLine(
            tier: response.feedback,
            spokenForm: response.spokenForm,
            wasNearMiss: response.chosenWasNearMiss
        )

        let nextVM: WordFormationModels.Start.RoundViewModel?
        if let nextRound = response.nextRound, let nextIndex = response.nextRoundIndex {
            nextVM = Self.makeRoundVM(nextRound, index: nextIndex, total: response.totalRounds)
        } else {
            nextVM = nil
        }

        let summary: WordFormationModels.Answer.SummaryViewModel?
        if response.isFinished {
            let accuracy = response.totalRounds > 0
                ? Double(response.correctCount) / Double(response.totalRounds)
                : 0
            summary = .init(
                title: String(localized: "wordFormation.summary.title"),
                scoreText: String(
                    format: String(localized: "wordFormation.summary.score"),
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

        let viewModel = WordFormationModels.Answer.ViewModel(
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
        _ round: FormationRound,
        index: Int,
        total: Int
    ) -> WordFormationModels.Start.RoundViewModel {
        let humanIndex = index + 1
        let progressLabel = String(
            format: String(localized: "wordFormation.progress"),
            humanIndex,
            total
        )
        let fraction = total > 0 ? Double(humanIndex) / Double(total) : 0

        return .init(
            id: round.id,
            subtask: round.subtask,
            baseImage: round.baseImage,
            baseWord: round.baseWord,
            promptLyalya: prompt(for: round),
            // Варианты уже перемешаны Worker'ом; нормативность НЕ переносим во VM.
            options: round.options.map(optionVM),
            progressLabel: progressLabel,
            progressFraction: fraction,
            accessibilityLabel: String(
                format: String(localized: "wordFormation.round.a11y"),
                round.baseWord
            )
        )
    }

    /// Реплика-вопрос Ляли по под-типу. Конкретный текст-вопрос из пака
    /// (`round.prompt`) уже учитывает основу («Один стул — а если много?»),
    /// поэтому используем его как ведущую реплику.
    static func prompt(for round: FormationRound) -> String {
        round.prompt.isEmpty ? subtaskPrompt(round.subtask) : round.prompt
    }

    /// Дефолтная реплика под-типа (если в паке prompt пуст).
    static func subtaskPrompt(_ subtask: FormationSubtask) -> String {
        switch subtask {
        case .diminutive: return String(localized: "wordFormation.prompt.diminutive")
        case .oneMany:    return String(localized: "wordFormation.prompt.oneMany")
        case .manyOf:     return String(localized: "wordFormation.prompt.manyOf")
        }
    }

    static func optionVM(_ option: FormationOption) -> WordFormationModels.Start.OptionViewModel {
        .init(
            id: option.id,
            text: option.text,
            accessibilityLabel: String(
                format: String(localized: "wordFormation.option.a11y"),
                option.text
            )
        )
    }

    // MARK: - Feedback («светофор», без «неправильно»)

    static func feedbackLine(
        tier: FeedbackTier,
        spokenForm: String,
        wasNearMiss: Bool
    ) -> String {
        switch tier {
        case .hit:
            // На попадание озвучиваем нормативную форму (закрепление по слуху).
            return String(
                format: String(localized: "wordFormation.feedback.hit"),
                spokenForm
            )
        case .almost:
            // Близкая ошибка — мягко предлагаем переслушать форму; грубая —
            // общее «почти».
            return wasNearMiss
                ? String(localized: "wordFormation.feedback.almost.near")
                : String(localized: "wordFormation.feedback.almost")
        case .retry:
            return String(localized: "wordFormation.feedback.retry")
        }
    }

    // MARK: - Helpers

    static func encouragement(for accuracy: Double) -> String {
        if accuracy >= 0.8 {
            return String(localized: "wordFormation.encourage.great")
        } else if accuracy >= 0.5 {
            return String(localized: "wordFormation.encourage.good")
        } else {
            return String(localized: "wordFormation.encourage.keepGoing")
        }
    }
}
