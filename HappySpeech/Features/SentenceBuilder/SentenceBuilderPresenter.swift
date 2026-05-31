import Foundation
import OSLog

// MARK: - SentenceBuilderPresentationLogic

@MainActor
protocol SentenceBuilderPresentationLogic: AnyObject {
    func presentStart(response: SentenceBuilderModels.Start.Response) async
    func presentAnswer(response: SentenceBuilderModels.Answer.Response) async
}

// MARK: - SentenceBuilderPresenter (Clean Swift: Presenter)
//
// F2-004 «Конструктор предложения» (Wave 2).
//
// Строит игровые ViewModel: реплика-вопрос Ляли по сцене, карточки банка (БЕЗ
// признака дистрактора и без acceptedOrders — серверная истина не покидает
// Interactor), тёплая обратная связь по «светофору» (без «неправильно») с
// озвучкой собранной фразы на hit и сводку. Все строки — String(localized:).

@MainActor
final class SentenceBuilderPresenter: SentenceBuilderPresentationLogic {

    weak var displayLogic: (any SentenceBuilderDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SentenceBuilder.Presenter"
    )

    init(displayLogic: (any SentenceBuilderDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Start

    func presentStart(response: SentenceBuilderModels.Start.Response) async {
        let total = response.rounds.count
        guard let firstRound = response.rounds.first else {
            Self.logger.error("Start with empty rounds")
            return
        }
        let viewModel = SentenceBuilderModels.Start.ViewModel(
            title: String(localized: "sentenceBuilder.title"),
            totalRounds: total,
            firstRound: Self.makeRoundVM(firstRound, index: 0, total: total)
        )
        await displayLogic?.displayStart(viewModel: viewModel)
    }

    // MARK: - Answer

    func presentAnswer(response: SentenceBuilderModels.Answer.Response) async {
        let lyalyaLine = Self.feedbackLine(
            tier: response.feedback,
            spokenSentence: response.spokenSentence
        )

        let nextVM: SentenceBuilderModels.Start.RoundViewModel?
        if let nextRound = response.nextRound, let nextIndex = response.nextRoundIndex {
            nextVM = Self.makeRoundVM(nextRound, index: nextIndex, total: response.totalRounds)
        } else {
            nextVM = nil
        }

        let summary: SentenceBuilderModels.Answer.SummaryViewModel?
        if response.isFinished {
            let accuracy = response.totalRounds > 0
                ? Double(response.correctCount) / Double(response.totalRounds)
                : 0
            summary = .init(
                title: String(localized: "sentenceBuilder.summary.title"),
                scoreText: String(
                    format: String(localized: "sentenceBuilder.summary.score"),
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

        // На retry подсвечиваем слоты в каноническом порядке; первая карточка —
        // подсказка-«прилипает». На hit/almost подсветки слотов нет.
        let highlightOrder = response.showHint ? response.correctOrder : []

        let viewModel = SentenceBuilderModels.Answer.ViewModel(
            feedback: response.feedback,
            lyalyaLine: lyalyaLine,
            spokenSentence: response.spokenSentence,
            highlightOrder: highlightOrder,
            hintTokenId: response.showHint ? response.firstHintTokenId : nil,
            isFinished: response.isFinished,
            nextRound: nextVM,
            summary: summary
        )
        await displayLogic?.displayAnswer(viewModel: viewModel)
    }

    // MARK: - Round building

    static func makeRoundVM(
        _ round: SentenceRound,
        index: Int,
        total: Int
    ) -> SentenceBuilderModels.Start.RoundViewModel {
        let humanIndex = index + 1
        let progressLabel = String(
            format: String(localized: "sentenceBuilder.progress"),
            humanIndex,
            total
        )
        let fraction = total > 0 ? Double(humanIndex) / Double(total) : 0

        return .init(
            id: round.id,
            subtask: round.subtask,
            promptLyalya: prompt(for: round),
            sceneImage: round.sceneImage,
            slotCount: round.slotCount,
            // Карточки уже перемешаны Worker'ом; признак дистрактора НЕ переносим.
            bankCards: round.bankTokens.map(cardVM),
            progressLabel: progressLabel,
            progressFraction: fraction,
            accessibilityLabel: String(
                format: String(localized: "sentenceBuilder.round.a11y"),
                subtaskPrompt(round.subtask)
            )
        )
    }

    /// Реплика-вопрос Ляли по под-типу раунда.
    static func prompt(for round: SentenceRound) -> String {
        subtaskPrompt(round.subtask)
    }

    static func subtaskPrompt(_ subtask: SentenceSubtask) -> String {
        switch subtask {
        case .wordOrder:   return String(localized: "sentenceBuilder.prompt.wordOrder")
        case .agreement:   return String(localized: "sentenceBuilder.prompt.agreement")
        case .preposition: return String(localized: "sentenceBuilder.prompt.preposition")
        }
    }

    static func cardVM(_ token: SentenceToken) -> SentenceBuilderModels.Start.CardViewModel {
        .init(
            id: token.id,
            text: token.text,
            imageAsset: token.imageAsset,
            role: token.role,
            accessibilityLabel: cardAccessibilityLabel(token)
        )
    }

    /// VoiceOver-метка карточки: слово + роль («предлог на», «слово кот»).
    static func cardAccessibilityLabel(_ token: SentenceToken) -> String {
        switch token.role {
        case .prep, .prepSlot:
            return String(format: String(localized: "sentenceBuilder.card.a11y.prep"), token.text)
        default:
            return String(format: String(localized: "sentenceBuilder.card.a11y.word"), token.text)
        }
    }

    // MARK: - Feedback («светофор», без «неправильно»)

    static func feedbackLine(
        tier: FeedbackTier,
        spokenSentence: String
    ) -> String {
        switch tier {
        case .hit:
            // На попадание озвучиваем собранную фразу целиком (закрепление по слуху).
            return String(
                format: String(localized: "sentenceBuilder.feedback.hit"),
                spokenSentence
            )
        case .almost:
            return String(localized: "sentenceBuilder.feedback.almost")
        case .retry:
            return String(localized: "sentenceBuilder.feedback.retry")
        }
    }

    // MARK: - Helpers

    static func encouragement(for accuracy: Double) -> String {
        if accuracy >= 0.8 {
            return String(localized: "sentenceBuilder.encourage.great")
        } else if accuracy >= 0.5 {
            return String(localized: "sentenceBuilder.encourage.good")
        } else {
            return String(localized: "sentenceBuilder.encourage.keepGoing")
        }
    }
}
