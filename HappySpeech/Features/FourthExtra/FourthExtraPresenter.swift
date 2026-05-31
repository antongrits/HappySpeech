import Foundation
import OSLog

// MARK: - FourthExtraPresentationLogic

@MainActor
protocol FourthExtraPresentationLogic: AnyObject {
    func presentStart(response: FourthExtraModels.Start.Response) async
    func presentAnswer(response: FourthExtraModels.Answer.Response) async
}

// MARK: - FourthExtraPresenter (Clean Swift: Presenter)
//
// F2-005 «Четвёртый лишний» (Wave 2).
//
// Строит игровые ViewModel: вопрос Ляли, сетку из 4 карточек (БЕЗ признака
// «лишний» — `isExtra` не покидает Interactor), тёплую обратную связь по
// «светофору» (без «неправильно»), озвученное обобщение «своих» и сводку.
// Все строки — String(localized:).

@MainActor
final class FourthExtraPresenter: FourthExtraPresentationLogic {

    weak var displayLogic: (any FourthExtraDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "FourthExtra.Presenter"
    )

    init(displayLogic: (any FourthExtraDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Start

    func presentStart(response: FourthExtraModels.Start.Response) async {
        let total = response.rounds.count
        guard let firstRound = response.rounds.first else {
            Self.logger.error("Start with empty rounds")
            return
        }
        let viewModel = FourthExtraModels.Start.ViewModel(
            title: String(localized: "fourthExtra.title"),
            totalRounds: total,
            firstRound: Self.makeRoundVM(firstRound, index: 0, total: total)
        )
        await displayLogic?.displayStart(viewModel: viewModel)
    }

    // MARK: - Answer

    func presentAnswer(response: FourthExtraModels.Answer.Response) async {
        let lyalyaLine = Self.feedbackLine(
            tier: response.feedback,
            groupingLabel: response.groupingLabel,
            extraReason: response.extraReason
        )

        let nextVM: FourthExtraModels.Start.RoundViewModel?
        if let nextRound = response.nextRound, let nextIndex = response.nextRoundIndex {
            nextVM = Self.makeRoundVM(nextRound, index: nextIndex, total: response.totalRounds)
        } else {
            nextVM = nil
        }

        let summary: FourthExtraModels.Answer.SummaryViewModel?
        if response.isFinished {
            let accuracy = response.totalRounds > 0
                ? Double(response.correctCount) / Double(response.totalRounds)
                : 0
            summary = .init(
                title: String(localized: "fourthExtra.summary.title"),
                scoreText: String(
                    format: String(localized: "fourthExtra.summary.score"),
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

        let viewModel = FourthExtraModels.Answer.ViewModel(
            feedback: response.feedback,
            lyalyaLine: lyalyaLine,
            extraCardId: response.extraCardId,
            groupingLabel: response.groupingLabel,
            hintCardIds: response.hintCardIds,
            askWhy: response.askWhy,
            isFinished: response.isFinished,
            nextRound: nextVM,
            summary: summary
        )
        await displayLogic?.displayAnswer(viewModel: viewModel)
    }

    // MARK: - Round building

    static func makeRoundVM(
        _ round: FourthExtraRound,
        index: Int,
        total: Int
    ) -> FourthExtraModels.Start.RoundViewModel {
        let humanIndex = index + 1
        let progressLabel = String(
            format: String(localized: "fourthExtra.progress"),
            humanIndex,
            total
        )
        let fraction = total > 0 ? Double(humanIndex) / Double(total) : 0

        return .init(
            id: round.id,
            variant: round.variant,
            promptLyalya: prompt(for: round),
            // Карточки уже перемешаны Worker'ом; `isExtra` НЕ переносим во VM.
            cards: round.cards.map(cardVM),
            progressLabel: progressLabel,
            progressFraction: fraction,
            accessibilityLabel: accessibilityLabel(for: round)
        )
    }

    /// Реплика-вопрос Ляли: семантическая или фонетическая.
    static func prompt(for round: FourthExtraRound) -> String {
        switch round.variant {
        case .semantic:
            return String(localized: "fourthExtra.prompt.semantic")
        case .phonetic:
            let sound = round.targetSound ?? ""
            return String(format: String(localized: "fourthExtra.prompt.phonetic"), sound)
        }
    }

    static func cardVM(_ card: ExtraCard) -> FourthExtraModels.Start.CardViewModel {
        .init(
            id: card.id,
            imageAsset: card.imageAsset,
            word: card.word,
            accessibilityLabel: String(
                format: String(localized: "fourthExtra.card.a11y"),
                card.word
            )
        )
    }

    static func accessibilityLabel(for round: FourthExtraRound) -> String {
        let words = round.cards.map(\.word).joined(separator: ", ")
        return String(format: String(localized: "fourthExtra.round.a11y"), words)
    }

    // MARK: - Feedback («светофор», без «неправильно»)

    static func feedbackLine(
        tier: FeedbackTier,
        groupingLabel: String?,
        extraReason: String?
    ) -> String {
        switch tier {
        case .hit:
            // На попадание называем обобщение «своих» (методическое ядро).
            if let grouping = groupingLabel, let reason = extraReason {
                return String(
                    format: String(localized: "fourthExtra.feedback.hit.full"),
                    grouping, reason
                )
            } else if let grouping = groupingLabel {
                return String(
                    format: String(localized: "fourthExtra.feedback.hit"),
                    grouping
                )
            }
            return String(localized: "fourthExtra.feedback.hit.generic")
        case .almost:
            return String(localized: "fourthExtra.feedback.almost")
        case .retry:
            return String(localized: "fourthExtra.feedback.retry")
        }
    }

    // MARK: - Helpers

    static func encouragement(for accuracy: Double) -> String {
        if accuracy >= 0.8 {
            return String(localized: "fourthExtra.encourage.great")
        } else if accuracy >= 0.5 {
            return String(localized: "fourthExtra.encourage.good")
        } else {
            return String(localized: "fourthExtra.encourage.keepGoing")
        }
    }
}
